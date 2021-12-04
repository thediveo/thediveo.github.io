# Testing & Profiling

Modules helping with testing and measuring code coverage even in arcane
situations, such as when re-executing programs which need to switch Linux-kernel
namespaces.

## `gons/reexec/testing`

[gons/reexec/testing](https://github.com/TheDiveO/gons/tree/master/reexec/testing) gives you coverage profiling of re-executing Go applications, such as those using the [gons/reexec](https://github.com/TheDiveO/gons/tree/master/reexec/testing) package.

[![GoDoc](https://pkg.go.dev/badge/github.com/TheDiveO/gons?status.svg)](https://pkg.go.dev/github.com/thediveo/gons/reexec/testing)

### `testbasher`

[testbasher](https://github.com/TheDiveO/testbasher) gives you painfully simple
bash script management and execution package for simple unit test script
harnesses. Perfect for crack tests which dynamically set up and tear down
Linux-kernel namespaces for individual tests.

[![GoDoc](https://pkg.go.dev/badge/TheDiveO/testbasher?status.svg)](https://pkg.go.dev/github.com/thediveo/testbasher)

## `errxpect`

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
