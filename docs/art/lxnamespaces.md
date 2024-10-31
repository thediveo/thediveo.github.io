---
title: "Linux Namespaces In Depth"
description: "where spaces have no names and containers are lies."
---

# Linux Namespaces In Depth

This post sheds more light on the details underpinning the Linux kernel's
namespaces. If you want to explore these namespaces, may I shamelessly recommend
my [lxkns namespace discovery engine](https://github.com/thediveo/lxkns)
featuring a web-based UI? 

As a quick recap and DRY (OO ... _or others_), so in Michael Kerrisk's
instructive words on
[`namespaces(7)`](https://man7.org/linux/man-pages/man7/namespaces.7.html):

> [!QUOTE] A namespace wraps a global system resource in an abstraction that
> makes it appear to the processes within the namespace that they have their own
> isolated instance of the global resource.  Changes to the global resource are
> visible to other processes that are members of the namespace, but are
> invisible to other processes. One use of namespaces is to implement
> containers.

## Life Cycle: Birth

Now that we know what namespaces are supposed to do ... how does the Linux
kernel actually _manage_ them? What are their _life cycles_?

To start with, the friendly man page
[namespaces(7)](https://man7.org/linux/man-pages/man7/namespaces.7.html) tells
us that (only) the following two syscalls (can) _create_ new namespaces:

- [`clone(2)`](https://man7.org/linux/man-pages/man2/clone.2.html)
- [`unshare(2)`](https://man7.org/linux/man-pages/man2/unshare.2.html)

But how or when do get namespaces destroyed and cleaned up? As it is, there's no
syscall for this.

Reading further into `namespaces(7)`, a first indication of how the Linux kernel
might manage the life cycle of namespaces is in this paragraph:

> [!QUOTE] Bind mounting (see
> [`mount(2)`](https://man7.org/linux/man-pages/man2/mount.2.html)) one of the
> files in this directory to somewhere else in the filesystem keeps the
> corresponding namespace of the process specified by pid alive even if all
> processes currently in the namespace terminate.

If namespaces can be bind-mounted, they must somehow be "files" (not in the
strict sense, but rather in the Unix abstractions of "everything's file").

## Namespaces@Home

Let's find out more: the aforementioned namespace man page also informs us that
processes (and tasks/threads) are always attached to namespaces and this can be
seen in the process filesystem. For instance

```bash
stat -L /proc/self/ns/net
```

gives:

```
  File: /proc/self/ns/net
  Size: 0               Blocks: 0          IO Block: 4096   regular empty file
Device: 0,4     Inode: 4026531840  Links: 1
Access: (0444/-r--r--r--)  Uid: (    0/    root)   Gid: (    0/    root)
Access: 2023-04-29 13:28:19.906590015 +0200
Modify: 2023-04-29 13:28:19.906590015 +0200
Change: 2023-04-29 13:28:19.906590015 +0200
 Birth: -
```

Please note the device ID major+minor number of `0,4`: according to the [Linux
allocated devices (4.x+
version)](https://www.kernel.org/doc/html/latest/admin-guide/devices.html)
kernel documentation, a major of `0` is used for "_[U]nnamed devices (e.g.
non-device mounts_". What the documentation doesn't mention: the minors are
dynamically allocated for unnamed device majors[^unnamed-minors]. That begs the
next question: how can we find out more about a seemingly _unnamed_ filesystem?

Thankfully, [`stat(1)`](https://man7.org/linux/man-pages/man1/stat.1.html) has
the `-f` trick up its sleeves, so let's see what

```bash
stat -Lf /proc/self/ns/net
```

has to tell us about the _file system_ status[^fsstat] (as opposed to the _file_
status):

```
  File: "/proc/self/ns/net"
    ID: 0        Namelen: 255     Type: nsfs
Block size: 4096       Fundamental block size: 4096
Blocks: Total: 0          Free: 0          Available: 0
Inodes: Total: 0          Free: 0
```

This now reveals that the namespaces somehow "live" on an unnamed device that
uses a "nsfs"[^nsfs] filesystem.

## `nsfs`

You don't need to try your luck in mounting it, as the "nsfs" filesystem is
tightly interwoven with the "proc" process filesystem and cannot be mounted
explicitly. The mount syscall will simply tell you that it doesn't know anything
about that nsfs thingie. And in fact, `/proc/filesystems` doesn't list any nsfs.

However, looking at the Linux kernel sources, we can locate the implementation
of the nsfs namespace filesystem in:
- [`fs/nsfs.c`](https://elixir.bootlin.com/linux/v6.3/source/fs/nsfs.c) and
- [`include/linux/proc_ns.h`](https://elixir.bootlin.com/linux/v6.3/source/include/linux/proc_ns.h).

While the device ID of any namespace in current kernels always refer to the same
single instance of the nsfs kernel namespace filesystem, the [world once has
been warned](https://lore.kernel.org/lkml/87poky5ca9.fsf@xmission.com/) of
potentially using multiple namespace filesystem instances in the future:

> [!QUOTE] I reserve the right for st_dev to be significant when comparing
namespaces.

In a twist of irony the same dire kernel warner then left out the dev ID
information in all places where the Linux kernel [renders a textual
representation of a namespace
reference](https://elixir.bootlin.com/linux/v6.3/source/fs/nsfs.c#L32). That is,
the kernel just exposes `net:[4026531905]` instead of something like maybe
`net:[4,4026531905]`. This affects all references in `/proc`, including
`/proc/mountinfo`. The result: simply a (reserved) mess.

Anyway, what's up with the inodes on nsfs?

## Namespace Inodes

Now that we know that namespaces are managed using
[inodes(7)](https://man7.org/linux/man-pages/man7/inode.7.html), this begs these
questions:
1. (_minor_) how are inode the numbers allocated?
2. what are the lifecycles of ntfs inodes and thus of namespaces?

The answer to our first and rather minor question is as follows: ntfs uses the
proc filesystem's inode number allocation mechanism from
[`fs/proc/generic.c`](https://elixir.bootlin.com/linux/v6.3/source/fs/proc/generic.c#L202).
And that, in turn, uses a generic ID allocation mechanism provided by the
kernel. Fun fact: for some reason or other, the proc filesystem allocates inode
numbers from `0xf0000000U` onwards (also known as
[`PROC_DYNAMIC_FIRST`](https://elixir.bootlin.com/linux/v6.3/source/fs/proc/generic.c#L196)).

For our second question about the lifecycle we have to take into consideration
that inodes only live as long as "someone" is interested in them. Like in any
good murder mystery, there are many potential suspects involved:

<div class="spaced">

- the obvious: a **process or task (thread) attached to a particular namespace**
  and thus referencing its inode (_internally, this actually doesn't employ real
  inode references, but instead so-called
  "[`nsproxy`](https://elixir.bootlin.com/linux/v6.3/source/kernel/nsproxy.c)"
  objects and separate
  namespace reference counting_),
- also a common suspect are namespace inodes **bind-mounted** in another place
  (such as used by Docker for network namespaces independently of container
  lifecycles and Ubuntu's [snap](https://en.wikipedia.org/wiki/Snap_(software))
  for mount namespaces),
- an **open file descriptor** referencing the namespace inode,
- the absolute odd-ball: an **open tap/tun device filedescriptor** that
  automatically references the network namespace the tap/tun device initially(!)
  was created in[^taptun].
- a **socket** that always automatically references the network namespace inode
  the caller was attached to when creating that socket,
- except for the initial namespaces, a **pid or user namespace** always
  automatically **referencing its parent namespace**,
- a **non-user namespace** always automatically **referencing its "owning" user
  namespace**.

</div>

## Live and Let Die

When an inode from the nsfs gets
"[evicted](https://elixir.bootlin.com/linux/v6.3/source/fs/nsfs.c#L52)" because
no-one is interested in it anymore, then the corresponding namespace will be –
in Linux kernel parlance – _put_ (please see [Kernel Lingo](#kernel-lingo)
below). That is, the namespace's reference count will be decremented and, upon
reaching barrel-bottom, the namespace finally gets destroyed.

The different types of namespaces each [define their own type-specific
implementations](https://elixir.bootlin.com/linux/v6.3/source/include/linux/proc_ns.h#L16)
for (internal) namespace operations, not least for the final "put". Here,
network namespaces somehow stand out because they cannot synchronously be
destroyed. Instead,
[`__put_net`](https://elixir.bootlin.com/linux/v6.3/source/net/core/net_namespace.c#L656)
arranges this to be carried out using a so-called "workqueue". These
[Workqueues](https://linux-kernel-labs.github.io/refs/heads/master/labs/deferred_work.html#workqueues)
are used in many places inside the kernel in order to schedule potentially
blocking actions to run in process context. Cleaning up network namespaces is
then handled by kernel worker threads, which serve also other workqueues, see
also the Linux kernel documentation on [Concurrency Managed Workqueue[s]
(cmwq)](https://www.kernel.org/doc/html/v6.2/core-api/workqueue.html) for more
workqueue background information.

And this finally answers my question of old about ["When does Linux
"garbage-collect"
namespaces?"](https://unix.stackexchange.com/questions/560912/when-does-linux-garbage-collect-namespaces)
on Linux&Unix StackExchange.

---

#### Kernel Lingo

The Linux kernel code uses the term "put"[^put] whenever decrementing the
reference count of a kernel object. The opposite is to "get" an object where the
reference count is increased.

A helpful mnemonic might be to "put back" a kernel object.

For inodes, there are `iget` and `iput` operations accordingly.

#### Notes

[^unnamed-minors]: ilkkachu's question ["How are minor device numbers assigned
    for unnamed/non-device mounts (major number
    0)?"](https://unix.stackexchange.com/questions/597020/how-are-minor-device-numbers-assigned-for-unnamed-non-device-mounts-major-numbe)
    on Unix&Linux StackExchange.

[^fsstat]: see also the
    [`fsstat64(2)`](https://man7.org/linux/man-pages/man2/statfs64.2.html)
    syscall.

[^nsfs]: Gert van der Berg's question ["What is the NSFS
    filesystem?"](https://unix.stackexchange.com/questions/465669/what-is-the-nsfs-filesystem)
    on Unix&Linux StackExchange.

[^taptun]: TheDiveO's question ["How to get the Linux network namespace for a
    tap/tun device referenced in
    /proc/[PID]/fdinfo/[FD]?"](https://unix.stackexchange.com/questions/504861/how-to-get-the-linux-network-namespace-for-a-tap-tun-device-referenced-in-proc)
    on Unix&Linux StackExchange.

[^put]: Eric Renouf's question ["Linux Kernel - What does it mean to "put" an
    inode?"](https://stackoverflow.com/questions/34069380/linux-kernel-what-does-it-mean-to-put-an-inode)
    on StackOverflow.

[^setns]: kernel implementation of the [setns
    syscall](https://elixir.bootlin.com/linux/v6.3/source/kernel/nsproxy.c#L546)
