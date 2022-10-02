# CLI Support

Packages helping with rendering CLI tool output as trees or tables, and handling
obscure CLI flag types: enumerations.

## `asciitree`

[asciitree](https://github.com/TheDiveO/go-asciitree) pretty-prints tree-like
data structures in ASCII and Unicode. This package also supports properties of
nodes, separate from the tree hierarchy, as well as tagging `struct` fields with
their roles.

[![Go Reference](https://pkg.go.dev/badge/github.com/thediveo/go-asciitree.svg)](https://pkg.go.dev/github.com/thediveo/go-asciitree)

## `enumflag`

[enumflag](https://github.com/TheDiveO/enumflag) adds enumeration flags
(including enum _slices_) to the [@spf13/pflag](https://github.com/spf13/pflag)
Go flag drop-in package.

There's now a source-compatible `enumflag/v2` that makes use of Go generics so
that the Go compiler can type-check at compile time that you are passing in a
suitable enum flag type and a matching enum value-to-string map.

[![GoDoc](https://pkg.go.dev/badge/github.com/TheDiveO/enumflag.svg)](https://pkg.go.dev/github.com/thediveo/enumflag)

## `klo`

[klo](https://github.com/TheDiveO/klo) implements `kubectl`-like output of Go
values (such as structs, maps, et cetera) in several output formats, including
sorted tabular.

You might want to use this package in your CLI tools to easily offer
`kubectl`-like output formatting to your Kubernetes-spoiled users.

[![GoDoc](https://pkg.go.dev/badge/github.com/TheDiveO/klo.svg)](https://pkg.go.dev/github.com/thediveo/klo)
