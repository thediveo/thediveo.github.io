---
title: "ioctl Request Values in Go"
description: "a small helper for constructing missing ioctl(2) request values."
---

# `ioctl` Request Values in Go

When doing system-level stuff in Go, one sometimes ends up with certain
(obscure?) [ioctl(2)](https://man7.org/linux/man-pages/man2/ioctl.2.html)
request values missing from the
[sys/unix](https://pkg.go.dev/golang.org/x/sys/unix) standard package.

So let's take a real-world example: the request values for
[ioctl_ns(2)](https://man7.org/linux/man-pages/man2/ioctl_ns.2.html) operations
are defined using C macros in
[`include/uapi/linux/nsfs.h`](https://elixir.bootlin.com/linux/v6.2.11/source/include/uapi/linux/nsfs.h#L10)
in the Linux kernel header sources as follows...

```c
#define NSIO 0xb7

// Returns a file descriptor that refers to an owning user namespace
#define NS_GET_USERNS _IO(NSIO, 0x1)
```

This translates straight into the following Go code, ignoring patronizing and
small-minded Go linters on
[`CONSTANT_CASE`](https://stringcase.org/cases/constant/):

```go
package main

import "github.com/thediveo/ioctl"

// Was:
//     #define NSIO 0xb7
const NSIO = 0xb7

// Was:
//     // Returns a file descriptor that refers to an owning user namespace
//     #define NS_GET_USERNS _IO(NSIO, 0x1)
var NS_GET_USERNS = ioctl.IO(NSIO, 0x01)

func main() {
    usernsfd, err := ioctl.RetFd(nsfd, NS_GET_USERNS)
}
```

For further details, please see the [`@thediveo/ioctl` package
documentation](https://pkg.go.dev/github.com/thediveo/ioctl).
