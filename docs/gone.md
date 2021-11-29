# Go-ing Nowhere
<img src="_images/gone.png" style="width: 6.66em; float: right;" title="Go-ing Nowhere">

Using Golang where it _really_ might not be the best of ideas.™

## CLI Support

Packages helping with rendering CLI tool output as trees or tables, and handling
obscure CLI flag types: enumerations.

### asciitree

[asciitree](https://github.com/TheDiveO/go-asciitree) pretty-prints tree-like
data structures in ASCII and Unicode. This package also supports properties of
nodes, separate from the tree hierarchy, as well as tagging `struct` fields with
their roles.

[![Go Reference](https://pkg.go.dev/badge/github.com/thediveo/go-asciitree.svg)](https://pkg.go.dev/github.com/thediveo/go-asciitree)

### enumflag

[enumflag](https://pkg.go.dev/TheDiveO/enumflag) supplies enumeration flags
(including enum slices) for Go's flag drop-in package spf13/pflag.

[![GoDoc](https://pkg.go.dev/badge/github.com/TheDiveO/enumflag.svg)](https://pkg.go.dev/github.com/thediveo/enumflag)


### klo

[klo](https://github.com/TheDiveO/klo) implements `kubectl`-like output of Go
values (such as structs, maps, et cetera) in several output formats, including
sorted tabular.

You might want to use this package in your CLI tools to easily offer
`kubectl`-like output formatting to your Kubernetes-spoiled users.

[![GoDoc](https://pkg.go.dev/badge/github.com/TheDiveO/klo.svg)](https://pkg.go.dev/github.com/thediveo/klo)

## Linux Namespaces & Containers

Modules for working with Linux kernel namespaces and helping in discovering
them, as well as dealing with container engines and "drive-by" paths.

### lxkns

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

### whalewatcher

[whalewatcher](https://github.com/TheDiveO/whalewatcher) automatically tracks
Docker and containerd workloads in the background, thus avoiding the need to
query lists of alive containers (containers with processes).

[![GoDoc](https://pkg.go.dev/badge/github.com/TheDiveO/whalewatcher.svg)](https://pkg.go.dev/github.com/thediveo/whalewatcher)

### procfsroot

[procfsroot](https://github.com/TheDiveO/procfsroot) makes `/proc/$PID/root`
(drive-by) "wormholes" more accessible.

[![GoDoc](https://pkg.go.dev/badge/github.com/TheDiveO/procfsroot.svg)](https://pkg.go.dev/github.com/thediveo/procfsroot)

### gons

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

## Testing & Profiling

Modules helping with testing and measuring code coverage even in arcane
situations, such as when re-executing programs which need to switch Linux-kernel
namespaces.

### gons/reexec/testing

[gons/reexec/testing](https://github.com/TheDiveO/gons/tree/master/reexec/testing) gives you coverage profiling of re-executing Go applications, such as those using the [gons/reexec](https://github.com/TheDiveO/gons/tree/master/reexec/testing) package.

[![GoDoc](https://pkg.go.dev/badge/github.com/TheDiveO/gons?status.svg)](https://pkg.go.dev/github.com/thediveo/gons/reexec/testing)


### testbasher

[testbasher](https://github.com/TheDiveO/testbasher) gives you painfully simple
bash script management and execution package for simple unit test script
harnesses. Perfect for crack tests which dynamically set up and tear down
Linux-kernel namespaces for individual tests.

[![GoDoc](https://pkg.go.dev/badge/TheDiveO/testbasher?status.svg)](https://pkg.go.dev/github.com/thediveo/testbasher)

### errxpect

Originally a separate addition, errxpect has become an integral part of the
[Gomega BDD testing framework](https://github.com/onsi/gomega). It simplifies
testing multi-return value functions for success or errors, avoiding noisy test
code using lots of underscore assignments. Simply place `Error()` between your
`Expect(...)` and your particular error assertion, that's it. No more juggling
around many `_`s.

```go
foo := func() (int, bool, error) { 
    return 0, false, errors.New("D'oh!")
}
Expect(foo()).Error().To(HaveOccured())
```
