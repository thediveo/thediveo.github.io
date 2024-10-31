---
title: "sys/class/net"
description: "it's not adaptive in the way you might have read or think it is."
---

# `sys/class/net`

Lazily entering the network namespace of a container and then relying on
`/sys/class/net` either directly or indirectly through certain CLI tool *will*
get you into hot water – sooner than later.

```bash
sudo nsenter -t $(docker inspect -f '{{.State.Pid}}' lxkns-lxkns-1) -n \
  ls /sys/class/net
# ...shows your host's network interfaces, not the container's
```

While some CLI tools solely relying on the RTNETLINK API show network interfaces
from the network namespace of the caller, oher CLI tools leveraging
`/sys/class/net` show something else (such as the host's network interfaces).
Worse, some tools that need to rely on both RTNETLINK and `/sys/class/net` will
in the best case error out, in the worst case silently read or set inconsistent
data.

## man-gled

Let's start with the man page for
[`sysfs(5)`](https://man7.org/linux/man-pages/man5/sysfs.5.html):

> [!QUOTE] `/sys/class/net` Each of the entries in this directory is a symbolic
> link representing one of the real or virtual networking devices that are
> **visible in the network namespace of the process that is accessing the
> directory**.  Each of these symbolic links refers to entries in the
> /sys/devices directory. [emphasis ours]

To prove the opposite, simply spin up a Docker container and then use the above
CLI commands to list the network interfaces inside `/sys/class/net`: instead of
showing just `eth0` and `lo` in most cases you'll see a different host set of
network interfaces. The presence of the (legacy) `docker0` bridge is a clear
telltale sign.

So...

> [!WARNING] Unfortunately, the part about `sysfs` adapting to the network
> namespace of the process that is reading stuff in the `class/net` branch **is
> incorrect**.

I contacted [Michael Kerrisk](https://man7.org/mtk/index.html) about it, but he
unfortunately lacks the time to update it accordingly. So here we go, another
article then, and hopefully he can catch up some time in the future.

Some helpful soul pointed out to me on StuckOverflaw the place in the Linux
kernel, where a newly mounted `sysfs` instance ["grabs" the mount caller's
current network
namespace](https://github.com/torvalds/linux/blob/28c20cc73b9cc4288c86c2a3fc62af4087de4b19/fs/sysfs/mount.c#L35)
and then "tags" it onto this particular sysfs mount for kingdom come. Whoever
later reads through that `sysfs` subtree will always see that particular froozen
network namespace. Of course, that network namespace is now kept alive by this
`sysfs` subtree referencing it until it gets unmounted.

## Mount Shenanigans

Of course, you can enter not only the network namespace, but also a suitable
mount namespace simultaneously:

```bash
sudo nsenter -t $(docker inspect -f '{{.State.Pid}}' lxkns-lxkns-1) -m -n \
  ls /sys/class/net
# eth0  lo
```

Except that this doesn't work well when the container you're entering sideways
doesn't have the required CLI tools in its mount namespace:

```bash
echo -e 'FROM alpine AS build\n\
FROM scratch\n\
COPY --from=build /lib/ /lib/\n\
COPY --from=build /bin/sleep /bin/\n\
CMD ["/bin/sleep", "1000000"]' \
  | docker build -t just-sleep -f- . \
  | docker run --rm --name just-sleep just-sleep
```

```bash
sudo nsenter -t $(docker inspect -f '{{.State.Pid}}' just-sleep) -m -n \
  ls /sys/class/net
# nsenter: failed to execute ls: No such file or directory
```

What about simply bringing our own `sysfs` instance with us?

```bash
sudo nsenter -t $(docker inspect -f '{{.State.Pid}}' just-sleep) -n \
  unshare -m /bin/bash -c \
  'mount -t sysfs sysfs /sys && ls /sys/class/net'
# eth0 lo
```

`unshare -m ...` actually does _more_ than just cloning and entering a new mount
namespace: first, cloning the mount namespace creates a new mount namespace with
(_almost_) the same mount points as the one from which we're cloning (for
instance, "private" mount points won't get cloned).

Next, `unshare` then remounts `/` recursive, with back propagation of any mount
point changes disabled ("private) (see also [util-linux/unshare.c
set_propagation](https://github.com/util-linux/util-linux/blob/86b6684e7a215a0608bd130371bd7b3faae67aca/sys-utils/unshare.c#L160)).
This is crucial, as otherwise the following `sysfs` overmount would propagate
back into the host (initial) mount namespace, rendering the host totally
unoperable – you might be surprised how many parts and programs in a Linux
system rely on a correct `sysfs`, down to the Go runtime.

Now in a safe state, we can mount a new `sysfs` instance onto `/sys` that will
show the network namespace we had entered before, as opposed to the host's
network namespace.

Upon exiting, the mount namespace will automatically be cleaned up, destroying
its mount points and thus removing any trace of the (thus temporarily) mounted
`sysfs` instance. Since we kept these mount points private (well, `unshare -m`
did this for us), we are leaving sort of no traces.

> [!ATTENTION] Welcome to the dark side of the namespace force.
