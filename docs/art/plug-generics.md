---
title: "Plugins and Generics"
description: "Go Generics to the rescue when managing the exposed functions and interfaces of plugins."
---

# Plugins and Generics

Wikipedia nicely [describes a
plugin](https://en.wikipedia.org/wiki/Plug-in_(computing)) as a "_software
component that adds a specific feature to an existing computer program_".

Regardless of dynamically loaded ("run-time") plugins or statically linked
("compile-time") plugins: a plugin architecture helps modularizing, maintaining,
and extending application functionality.

My Linux-kernel namespaces and container discovery engine
[lxkns](https://github.com/thediveo/lxkns) uses plugins to "decorate" the
discovered containers with additional information specific, for instance, to a
particular container engine ([Podman](https://podman.io) pods), orchestration
([Kubernetes](https://kubernetes.io/) Docker Shim, [Siemens Industrial
Edge](https://github.com/industrial-edge)), and so on.

lxkns plugins allow applications reusing the lxkns discovery engine to add
further "decorations" to containers that don't belong into the base discovery
engine. Since I couldn't find something small and minimal I wrote my own
[minimalist Go plugin manager
`go-plugger`](https://github.com/thediveo/go-plugger).

## `Any` Hell

One thing that nagged me all the time: because the plugin manager needed to be
(\*cough\*) _generic_, all the registration and lookup of exposed plugin APIs
was more or less ending up in "`any` hell", reflection, and tons of type
conversions and type assertions.

Now, as Go 1.19 being the second Go release featuring Generics I was wondering:
can we please register and look up the exposed plugin APIs in a type-safe manner
that `gopls` and the compiler can check while developing and building an
application?

## Generics to the Rescue

Luckily, Go Generics are helpful for dealing with exposed plugin APIs: what else
are multiple plugins exposing the same API are than a typed and glorified list?

To start with, we first need a custom type defining a plugin API (or part of it)
as a function or interface:

```go
type MyAPI func() string
```

`go-plugger` manages the exposed plugin APIs based on the custom type(s) and
collects the registered API instances of the same custom type in a so-called
"(plugin) group". Whenever needed for registration or lookup, the group for a
particular custom type can be referenced (fetched) as follows:

```go
_ = plugger.Group[MyAPI]()
```

All registered API instances (also termed "symbols") are accessed via the aptly
named `Symbols()` accessor, ready for iterating over them and invoking the API
instances without any type assertions shenanigans:

```go
for _, myapi /* MyAPI */ := range plugger.Group[MyAPI]().Symbols() {
    _ = myapi()
}
```

Registration is now also type safe, additionally avoiding any need for type
conversions:

```go
plugger.Group[MyAPI]().Register(func() string{ ... })
```

Normally, `go-plugger` will derive a plugin name from the directory name of the
plugin package, but this can be easily explicitly specified or overridden using
a registration option:

```go
plugger.Group[MyAPI]().Register(
    func() string{ ... }, 
    plugger.WithPlugin("foobar"))
```

The order of the exposed plugin symbols within the same group can be modified
using `WithPlacement("hint")`, in order to ensure that a particular API instance
is executed only after or before another API instance of a different plugin.

## References

- [Plugins in Go](https://eli.thegreenplace.net/2021/plugins-in-go/), by Eli Bendersky
- [Hashicorp's Go Plugin System over RPC](https://github.com/hashicorp/go-plugin)
