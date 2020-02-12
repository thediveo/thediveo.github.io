# Re:Go-ing Nowhere

## Misc Go Packages

| Project | Description |
| :------ | :---------- |
| [asciitree](https://github.com/TheDiveO/go-asciitree) | Pretty-print tree-like data structures in ASCII and Unicode. This package also supports properties of nodes, separate from the tree hierarchy, as well as tagging `struct` fields with their roles. [![GoDoc](https://godoc.org/github.com/TheDiveO/go-asciitree?status.svg)](http://godoc.org/github.com/TheDiveO/go-asciitree) |
| [testbasher](https://github.com/TheDiveO/testbasher) | Painfully simple bash script management and execution package for simple unit test script harnesses. [![GoDoc](https://godoc.org/github.com/TheDiveO/testbasher?status.svg)](http://godoc.org/github.com/TheDiveO/testbasher) |
| [klo](https://github.com/TheDiveO/klo) | `kubectl`-like output of Go values (such as structs, maps, et cetera) in several output formats, including sorted tabular. You might want to use this package in your CLI tools to easily offer `kubectl`-like output formatting to your Kubernetes-spoiled users. [![GoDoc](https://godoc.org/github.com/TheDiveO/klo?status.svg)](http://godoc.org/github.com/TheDiveO/klo) |

## Linux kernel Namespaces

| Project | Description |
| :------ | :---------- |
| [lxkns](https://github.com/TheDiveO/lxkns) | A comprehensive Linux kernel namespace discovery engine which discovers namespaces in places where many tools don't want to look into. [![GoDoc](https://godoc.org/github.com/TheDiveO/lxkns?status.svg)](http://godoc.org/github.com/TheDiveO/lxkns) |
| [gons](https://github.com/TheDiveO/gons) | A small Go package that selectively switches your Go application into other already existing Linux namespaces. This must happen before the Go runtime spins up, blocking certain namespace changes, such as changing into a different mount namespace. [![GoDoc](https://godoc.org/github.com/TheDiveO/gons?status.svg)](http://godoc.org/github.com/TheDiveO/gons) |
