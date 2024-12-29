# Testing & Profiling

Go Modules that help with testing and measuring code coverage. Even in arcane
situations, such as when re-executing programs which need to switch Linux-kernel
namespaces. **Not** a drop-in replacement for `@ory/dockertest`, but instead
features an option function design.

## `morbyd`

Use [morbyd](https://github.com/thediveo/morbyd) to easily build and run
throw-away test Docker images and containers, and run commands inside them using
this thin layer on top of the standard Docker Go client.

[![PkgGoDev](https://img.shields.io/badge/-reference-blue?logo=go&logoColor=white&labelColor=505050)](https://pkg.go.dev/github.com/thediveo/morbyd)

```go
package main

import (
    "context"

    "github.com/thediveo/morbyd"
    "github.com/thediveo/morbyd/exec"
    "github.com/thediveo/morbyd/run"
    "github.com/thediveo/morbyd/session"
)

func main() {
    ctx := context.TODO()
    sess, _ := morbyd.NewSession(ctx, session.WithAutoCleaning("test.mytest="))
    defer sess.Close(ctx)

    // run a container and copy the container's combined output
    // of stdout and stderr to our stdout.
    cntr, _ := sess.Run(ctx, "busybox",
        run.WithCommand("/bin/sh", "-c", "while true; do sleep 1; done"),
        run.WithAutoRemove(),
        run.WithCombinedOutput(os.Stdout))

    // run a command inside the container and wait for this command
    // to finish.
    cmd, _ := cntr.Exec(ctx,
        exec.WithCommand("/bin/sh", "-c", "echo \"Hellorld!\""),
        exec.WithCombinedOutput(os.Stdout))
    exitcode, _ := cmd.Wait(ctx)
}
```

## `notwork`

[notwork](https://github.com/thediveo/morbyd) is a tiny package to help with
creating transient Linux virtual network elements for testing purposes. And for
messing around with mount namespaces.

[![PkgGoDev](https://pkg.go.dev/badge/github.com/thediveo/notwork)](https://pkg.go.dev/github.com/thediveo/notwork)

## `testbasher`

[testbasher](https://github.com/thediveo/testbasher) offers "painfully simple"
**in-test bash script management and execution** for simple unit test script
harnesses. The core idea here is to keep the harness scripts close the the test
itself, instead of having to separate it in form of many small bash scripts
making maintainance hard.

Perfect for crack tests which dynamically set up and tear down Linux-kernel
namespaces for individual tests.

[![PkgGoDev](https://pkg.go.dev/badge/thediveo/testbasher?status.svg)](https://pkg.go.dev/github.com/thediveo/testbasher)

## 💤`gons/reexec/testing`

> Excellent news from the Go project: [issue #51430 "cmd/cover: extend coverage
> testing to include applications"](https://github.com/golang/go/issues/51430)
> does not only support profiling applications, but even multiple runs,
> including re-executing your own binary.

[gons/reexec/testing](https://github.com/thediveo/gons/tree/master/reexec/testing)
provides **coverage profiling of re-executing Go applications**, such as those
using the
[gons/reexec](https://github.com/thediveo/gons/tree/master/reexec/testing)
package. Now of less importance with the much simpler to use `Mountineer`
technology in `lxkns` that avoids the need for re-executing the whole
application itself.

[![PkgGoDev](https://pkg.go.dev/badge/github.com/thediveo/gons?status.svg)](https://pkg.go.dev/github.com/thediveo/gons/reexec/testing)

## 💤`errxpect`

💤 _retired after having been integrated into Gomega_

Originally a separate add-on, `errxpect` has become an integral part of the
[Gomega BDD testing framework](https://github.com/onsi/gomega). The original
Gomega already has very nice built-in error checking for functions returning
multiple values. However, this was designed for the success cases, but not for
checking correct error return values with all other return values correctly
being zero values.

`errxpect` complements the built-in Gomega tesing functionality for the
situation where multi-return value functions need to be tested for errors. It
avoids noisy test code using lots of underscore assignments. Simply place
`Error()` between your `Expect(...)` and your particular error assertion, that's
it. No more juggling around the many `_`s.

```go
foo := func() (int, bool, error) { 
    return 0, false, errors.New("D'oh!")
}
Expect(foo()).Error().To(HaveOccured())
```
