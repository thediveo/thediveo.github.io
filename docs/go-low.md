# Linux Namespaces & Containers

Modules for working with Linux kernel namespaces and helping in discovering
them, as well as dealing with container engines and "drive-by" paths.

## `lxkns`

[lxkns](https://github.com/TheDiveO/lxkns) implements a comprehensive Linux
kernel namespace discovery engine which discovers namespaces in places where
many tools don't want to look into. Furthermore, it also detects mount points
and brings them into a more useful form of a tree based on mount the _paths_.
And it relates the discovered namespaces to containers and projects (Docker,
containerd).

lxkns also allows running Go routines and functions in the context of different
namespaces for those namespace types which can be switched while running
multithreaded (in particular, net, ipc, and uts).

And as a special feature, it supports drive-by-reading from other mount
namespaces without much hassle, as nobody expects ... the
[`Mountineer`](https://pkg.go.dev/github.com/thediveo/lxkns/ops/mountineer)s!

[![GoDoc](https://pkg.go.dev/badge/github.com/TheDiveO/lxkns.svg)](https://pkg.go.dev/github.com/thediveo/lxkns)

## `whalewatcher`

[whalewatcher](https://github.com/TheDiveO/whalewatcher) automatically tracks
Docker and containerd workloads in the background, thus avoiding the need to
query lists of alive containers (containers with processes).

[![GoDoc](https://pkg.go.dev/badge/github.com/TheDiveO/whalewatcher.svg)](https://pkg.go.dev/github.com/thediveo/whalewatcher)

## `procfsroot`

[procfsroot](https://github.com/TheDiveO/procfsroot) makes `/proc/$PID/root`
(drive-by) "wormholes" more accessible.

[![GoDoc](https://pkg.go.dev/badge/github.com/TheDiveO/procfsroot.svg)](https://pkg.go.dev/github.com/thediveo/procfsroot)

## `gons`

[gons](https://github.com/TheDiveO/gons) is a small Go module that selectively
switches your Go application into other already existing Linux namespaces. This
must happen before the Go runtime spins up, blocking certain namespace changes,
such as changing into a different mount namespace.

> [!NOTE] Originally required in the mount namespace discovery of `lxkns`, the
> `gons` module has become obsolete with the advent of the
> [`Mountineer`](https://pkg.go.dev/github.com/thediveo/lxkns/ops/mountineer)s
> (an integral part of `lxkns`), which in most situation offer much better
> performance and much simpler handling when reading from other mount
> namespaces.

[![GoDoc](https://pkg.go.dev/badge/github.com/TheDiveO/gons.svg)](https://pkg.go.dev/github.com/thediveo/gons)
