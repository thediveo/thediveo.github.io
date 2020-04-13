# Re:Go-ing Nowhere <img src="assets/img/gone.jpeg" style="width: 2em; float: right;" title="Go-ing Nowhere">

Using Golang where it really might not be the best of ideas.

## CLI Support

Packages helping with rendering CLI tool output as trees or tables, and handling
obscure CLI flag types: enumerations.

| Project | Description |
| :------ | :---------- |
| [asciitree](https://github.com/TheDiveO/go-asciitree) | Pretty-print tree-like data structures in ASCII and Unicode. This package also supports properties of nodes, separate from the tree hierarchy, as well as tagging `struct` fields with their roles.<br><br>[![GoDoc](https://godoc.org/github.com/TheDiveO/go-asciitree?status.svg)](http://godoc.org/github.com/TheDiveO/go-asciitree) |
| [enumflag](https://github.com/TheDiveO/enumflag) | Enumeration flags (including enum slices) for Go's flag drop-in package spf13/pflag.<br><br>[![GoDoc](https://godoc.org/github.com/TheDiveO/enumflag?status.svg)](http://godoc.org/github.com/TheDiveO/enumflag) |
| [klo](https://github.com/TheDiveO/klo) | `kubectl`-like output of Go values (such as structs, maps, et cetera) in several output formats, including sorted tabular. You might want to use this package in your CLI tools to easily offer `kubectl`-like output formatting to your Kubernetes-spoiled users.<br><br>[![GoDoc](https://godoc.org/github.com/TheDiveO/klo?status.svg)](http://godoc.org/github.com/TheDiveO/klo) |

## Linux kernel Namespaces

Packages for working with Linux kernel namespaces and helping in discovering
them.

| Project | Description |
| :------ | :---------- |
| [gons](https://github.com/TheDiveO/gons) | A small Go package that selectively switches your Go application into other already existing Linux namespaces. This must happen before the Go runtime spins up, blocking certain namespace changes, such as changing into a different mount namespace.<br><br>[![GoDoc](https://godoc.org/github.com/TheDiveO/gons?status.svg)](http://godoc.org/github.com/TheDiveO/gons) |
| [lxkns](https://github.com/TheDiveO/lxkns) | A comprehensive Linux kernel namespace discovery engine which discovers namespaces in places where many tools don't want to look into.<br><br>[![GoDoc](https://godoc.org/github.com/TheDiveO/lxkns?status.svg)](http://godoc.org/github.com/TheDiveO/lxkns) |

## Testing & Profiling

Packages helping with testing and measuring code coverage in arcane situations,
such as when re-executing programs which need to switch Linux-kernel namespaces.

| Project | Description |
| :------ | :---------- |
| [gons/reexec/testing](https://github.com/TheDiveO/gons/tree/master/reexec/testing) | Coverage profiling of re-executing Go applications, such as those using the [gons/reexec](https://github.com/TheDiveO/gons/tree/master/reexec/testing) package.<br><br>[![GoDoc](https://godoc.org/github.com/TheDiveO/gons?status.svg)](http://godoc.org/github.com/TheDiveO/gons/reexec/testing) |
| [testbasher](https://github.com/TheDiveO/testbasher) | Painfully simple bash script management and execution package for simple unit test script harnesses. Perfect for crack tests which dynamically set up and tear down Linux-kernel namespaces for individual tests.<br><br>[![GoDoc](https://godoc.org/github.com/TheDiveO/testbasher?status.svg)](http://godoc.org/github.com/TheDiveO/testbasher) |
