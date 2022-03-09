# Incontinentainers
<img src="art/_images/incontinentainer.jpg" style="width: 10em; float: right;" title="Incontinentainer">

Containers are not Virtual Machines. And, in the words of Dan Walsh:
"[Containers do not
contain](https://opensource.com/business/14/7/docker-security-selinux)".

While Dan has his gripes with what I like to banter as "incontinentainers",
there are also positive aspects to this aspect of container technology. Yes,
we've all heard about "lightweight virtualization". For instance, little do
people consider diagnosing virtualized workloads ... until they need to consider
the hard way. Believe me, we were glad we already had considered before we were
called onto an industrial pilot customer's site.

Diagnosing containers and container hosts is much easier as diagnosing VMs ...
as not least this post is testament to.

## Namespaces

Linux kernel namespaces are often seen as VM-like sandboxing. Au contraire, I
like to think of them rather as "partitioning" certain OS resources, such as
processes, network stacks, and views into the virtual file system. And no, I
didn't forgot the plural-s with "file system".

This brings us to the highly interesting topic of the VFS and mount namespaces.

## VFS – There Can Only Be One

The [Linux Kernel
documentation](https://www.kernel.org/doc/html/latest/filesystems/vfs.html)
describes the virtual file system (VFS for short) as "_the software layer in the
kernel that provides the filesystem interface to user programs._" Please note
that the VFS always takes stage in singular, never as many VFSes.

Now, the concept of [mount
namespaces(7)](https://man7.org/linux/man-pages/man7/mount_namespaces.7.html)
might easily make us think of multiple VFSes.

**Except, there's still only a single VFS, and mount namespaces -- together with
chroot'ing -- only provide "partitioned views" into this single VFS.**

To clarify: [chroot](https://man7.org/linux/man-pages/man2/chroot.2.html) is a
mechanism to change the root directory of a process in that this process now
only sees a "subtree" of the file system. Mount namespaces then partition mounts
in that a process in a certain mount namespace can only see those mounts
belonging to the mount namespace it's attached to.

When it comes to chroot'ing, you need to be careful to not provide (hard) links
into places in the VFS outside the chroot root. But then, you would not, do you?

## Procfs Wormholes

Probably mostly overlooked, the
[procfs](https://man7.org/linux/man-pages/man5/proc.5.html) has a hidden
champion: `/proc/$PID/root`. To cite the man page for proc(5):

> "Note however that this file is not merely a symbolic link. It provides the
> same view of the filesystem (including namespaces and the set of per-process
> mounts) as the process itself."

So, if we have can see to a(nother) container's process in our procfs instance
and also have sufficient capabilities, then we're actually able to **directly
access files in that other process' mount namespace without the need for our own
process to be attached to this other mount namespace.**

This is even the more interesting as only single-threaded processes are able to
switch mount namespaces. Using only ordinary file system calls and armed with
enough capabilities, we can now easily and highly performant access other mount
namespaces. And if there's a process-less mount namespace, we simply spin up a
single-threaded process for the sole purpose to attach to the target mount
namespace for easy access.

Oh, the capabilities required? `CAP_SYS_PTRACE` and -- when in a container -- a
view onto the host's PID namespace. 

## Mountineers

The aforementioned man page ultimatively led to two Go convenience packages:

- [procfsroot](https://github.com/TheDiveO/procfsroot) translates symbolic links
  (especially absolute symlinks) from another container's network namespace into
  the paths useable from a process outside that network namespace.

- [lxkns/ops/mountineer](https://github.com/TheDiveO/lxkns/tree/master/ops/mountineer)
  implements the high-level convenience type `Mountineer`: given some mount
  namespace reference, it gives easy access by ensuring there's a suitable
  process available and then transparently translates paths.

Accessing files in another "incontinentainer" is as easy as:

```go
mnteer, err := mountineer.New(
    model.NamespaceRef{"/proc/1/ns/mnt", "/run/snapd/ns/chromium.mnt"}, nil)
defer mntneer.Close()
etchostname, err := mnteer.ReadFile("/etc/hostname")
```

More details can be found in [Mountineers: Technical
Background](https://thediveo.github.io/lxkns/#/mountineers?id=technical-background).

## Acknowledgement

I deeply apologize to Laurel Duermaël, the creator of the adorable "Moby Dock"
Docker mascot.
