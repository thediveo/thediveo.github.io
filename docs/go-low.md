# Linux Namespaces & Containers

Go Modules for working with Linux kernel namespaces and helping in discovering
them, as well as dealing with container engines and "drive-by" paths.

## `lxkns`

[lxkns](https://github.com/TheDiveO/lxkns) implements a comprehensive Linux
kernel namespace discovery engine which discovers namespaces in places where
many tools don't want to look into. Furthermore, it also detects mount points
and brings them into a more useful form of a tree based on mount the _paths_.
And it relates the discovered namespaces to containers and projects (Docker,
containerd).

lxkns also allows executing Go routines and functions in the context of
different namespaces – for those namespace types which can be switched while
running multithreaded (in particular, net, ipc, and uts).

And as a special feature, it supports "drive-by-reading" from other mount
namespaces without much hassle, as nobody expects ... the
[`Mountineer`](https://pkg.go.dev/github.com/thediveo/lxkns/ops/mountineer)s!
This works around the restriction of not being able to switch an OS-level thread
of a multi-threaded Go application into a different mount namespace. And it
avoids having to re-execute the application in order to switch into a different
mount namespace before the Go runtime spins up.

[![GoDoc](https://pkg.go.dev/badge/github.com/TheDiveO/lxkns.svg)](https://pkg.go.dev/github.com/thediveo/lxkns)

For some lower-level functionality, `lxkns` relies on separate Go modules that
might be of interest also outside the context of `lxkns`:

- `whalewatcher`,
- `procfsroot`.

## `whalewatcher`

[whalewatcher](https://github.com/TheDiveO/whalewatcher) automatically tracks
Docker and containerd active workloads in the background. It avoids the need to
repeatedly query (poll) the lists of alive containers (containers with
processes) in order to get the correct active workload picture. Instead, it
monitors container lifecycle events and also handles the intricate details of
correctly synchronizing to the current workload state even when containers get
started and stopped while gathering all the required information.

Applications using the `whalewatcher` module just ask fetch the current and
always up-to-date list of alive containers whenever they need without having to
worry about (re)synchronization with the container engines, high poll load, et
cetera. That's taken care of by the `whalewatcher` module.

[![GoDoc](https://pkg.go.dev/badge/github.com/TheDiveO/whalewatcher.svg)](https://pkg.go.dev/github.com/thediveo/whalewatcher)

## `procfsroot`

[procfsroot](https://github.com/TheDiveO/procfsroot) makes `/proc/$PID/root`
(drive-by) "wormholes" more accessible. Given sufficient capabilities,
`/proc/$PID/root` allows processes to directly see the file system as seen by a
process in a different mount namespace. These paths avoid the need for spawning
"proxy file services" into other mount namespaces to access files, directories,
pipes, et cetera in those other mount namespaces.

This module focuses on correctly translating symbolic links (symlinks) from the
perspective of the other mount namespace into a path that works inside the mount
namespace of the calling process. It handles both relative and absolute symbolic
links. Please note that Go's own `EvalSymlink()` cannot be used because it fails
with absolute symlinks due to the additional `/proc/$PID/root` filesystem path
prefix always required.

`procfsroot` can be used as a standalone helper module. Often, you might want to
consider using the higher-level abstraction of the `Mountineer` type in the
`lxkns` module, as it hides gory details

[![GoDoc](https://pkg.go.dev/badge/github.com/TheDiveO/procfsroot.svg)](https://pkg.go.dev/github.com/thediveo/procfsroot)

## `gons`

(_Retired_)

[gons](https://github.com/TheDiveO/gons) is a small Go module that selectively
switches your Go application into other already existing Linux namespaces. This
must happen before the Go runtime spins up, blocking certain namespace changes,
such as changing into a different mount namespace.

Originally required in the mount namespace discovery of `lxkns`, the `gons`
module has become obsolete with the advent of the
[`Mountineer`](https://pkg.go.dev/github.com/thediveo/lxkns/ops/mountineer)s (an
integral part of `lxkns`), which in most situation offer much better performance
and much simpler handling when reading from other mount namespaces.

[![GoDoc](https://pkg.go.dev/badge/github.com/TheDiveO/gons.svg)](https://pkg.go.dev/github.com/thediveo/gons)
