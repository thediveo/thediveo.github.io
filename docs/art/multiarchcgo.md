---
title: "Multi-Arch Images with cgo"
shorttitle: "Multi-Arch Images w/ cgo"
description: "cross-compiling in Alpine build stages that require cgo."
---

# Multi-Arch Images with cgo

Go comes with its incredible cross-compiling capabilities right out of the box.
This is especially useful when building multi-architecture container images, as
this allows the build stage producing a Go binary to run natively on the build
platform instead of needing emulation (namely, [QEMU](https://www.qemu.org/)).

Unfortunately, things get nasty when building a cross-platform Go binary
requires [cgo](https://pkg.go.dev/cmd/cgo), as cgo then requires a
cross-compiling C compiler and toolchain.

Sadly, Alpine doesn't come with a gcc cross-compiler package. 😭

## Cross-Compiling with "xx"

Fortunately, there are clang and
[@tonistiigi/xx](https://github.com/tonistiigi/xx)'s [xx – Dockerfile
cross-compilation
helpers](https://github.com/tonistiigi/xx/blob/master/README.md). The "xx"
helpers (oh, well) supports Alpine and Debian. Especially the [Go /
Cgo](https://github.com/tonistiigi/xx/blob/master/README.md#go--cgo) section is
of interest here: it comes with a neat `xx-go` wrapper that replaces the normal
`go` invocation.

A real-world example from my [lxkns](https://github.com/thediveo/lxkns) project:

```dockerfile
ARG ALPINE_VERSION=3.18
ARG ALPINE_PATCH=0
ARG GO_VERSION=1.20.5
ARG NODE_VERSION=16

# 0th stage: https://github.com/tonistiigi/xx/blob/master/README.md
FROM --platform=${BUILDPLATFORM} tonistiigi/xx AS cc-helpers

# 1st stage: native, cross-compiling
FROM --platform=${BUILDPLATFORM} golang:${GO_VERSION}-alpine${ALPINE_VERSION} AS builder

ARG BUILDPLATFORM
ARG TARGETPLATFORM

RUN apk add clang lld libcap-utils
COPY --from=cc-helpers / /

# !!!
RUN xx-apk add --no-cache gcc musl-dev

ENV CGO_ENABLED=1
RUN xx-go build std

# ...copy in the module sources as needed...

RUN --mount=target=. \
    --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg \
    xx-go build -v -tags osusergo,netgo \
        -ldflags "-extldflags '-static' -s -w" \
        -o /lxkns ./cmd/lxkns && \
    xx-verify --static /lxkns
```

Please note how this first installs `clang` and `lld` packages, and then copies
in the "xx" helpers for cross-compiling. These must be the ones for the _build_
platform.

Next, the `gcc` and `musl-dev` packages must be those for the _target_ platform
instead. Thus, we use `xx-apk` instead of a plain and unwrapped `apk`.

Finally, we set `CGO_ENABLED=1` to ensure that cgo is always used, regardless of
the target platform being identical to the build platform or not. Thanks to the
"xx" documentation for pointing this out!

Building the Go binary then is wrapped in `xx-go` instead of `go`, but otherwise
is the same as before. This wrapper will automatically correctly set `GOOS`,
`GOARCH`, `GOARM`, et cetera, so we don't need to handle this ourselves.

## Static Binaries

In order to [create a static binary](https://www.arp242.net/static-go.html) we
not only need the `osusergo,netgo` build flags, but also have to add
`-extldflags=-static` to our `-ldflags`.

`xx-verify` is a nice touch to run a final sanity-check on the resulting binary
to ensure that we in fact ended up with a binary for the desired target
platform. The additional `--static` ensures that there were no shared libraries
sneaking into our build.
