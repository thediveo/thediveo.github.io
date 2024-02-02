# `morbyd`
<img title="podman" src="art/_images/morbyd.png" width="250" style="float: right;">

`morbyd` is a thin layer on top of the standard Docker Go client to easily build
and run throw-away test Docker images and containers. And to run commands inside
these containers.

## The Silence of Dockertest

Ahh, there's `github.com/ory/dockertest/v3` for this for years, you say. Why
writing a new module, this isn't the Rust community!

True, until you hit the limitations of `dockertest/v3` hard, such as its
proprietary Docker client that is incompatible with Docker's stdout/stderr
streaming using `100 CONTINUE` headers. No reaction for months after filing this
issue, just total silence. Then there is `dockertest`'s callback function option
setting exposing the naked Docker API data structures and that begs the
question: why not real _option functions_? The incorrect implementation of
tri-state flags as only "true" or "default" (basically, "omitempty" in
`json.Marshal` parlance), but not as "true", "false", and "default". By then 23%
(sic!) code coverage probably doesn't matter anyway. And some missing newer API
parameters that I happen to need in my unit tests.

Time to cut my losses.

## Simplify Upstream

`morbyd` basically hides the gory details of some of the more difficult Docker
API knobs: for instance, when is a volume a volume and when is it a bind? And
how to correctly stream the output, and optionally input, of container and
commands via Dockers API. You simply just pass your `io.Writers` and
`io.Readers` – for instance, to make assertions in your tests about the expected
output. Or to dump the output only for failing tests, for better diagnosis.

This module makes heavy use of [option
functions](https://dave.cheney.net/2014/10/17/functional-options-for-friendly-apis).
So you can quickly get a grip on Docker's slightly excessive
knobs-for-everything API design. `morbyd` neatly groups the many `With...()`
options in packages, such as `run` for "run container" and `exec` for "container
execute". This design avoids stuttering option names that would otherwise clash
across different API operations for common configuration elements, such as
names, labels, and options.

A block of code is worth a thousand words...

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
    // note: error handling left out for brevity
    //
    // note: enable auto-cleaning of left-over containers and
    // networks, both when creating the session as well as when
    // closing the session. Use a unique label either in form of
    // "key=" or "key=value".
    sess, _ := morbyd.NewSession(ctx, session.WithAutoCleaning("test.mytest="))
    defer sess.Close(ctx)

    cntr, _ := sess.Run(ctx, "busybox",
        run.WithCommand("/bin/sh", "-c", "while true; do sleep 1; done"),
        run.WithAutoRemove(),
        run.WithCombinedOutput(os.Stdout))
    defer cntr.Stop(ctx)

    cmd, _ := cntr.Exec(ctx,
        exec.WithCommand("/bin/sh", "-c", "echo \"Hellorld!\""),
        exec.WithCombinedOutput(os.Stdout))
    exitcode, _ := cmd.Wait(ctx)
}
```

## Features

- testable examples for common tasks to get you quickly up and running. Please
  see the [package
  documentation](https://pkg.go.dev/github.com/thediveo/morbyd).

- option function design with extensive Go Doc comments that IDEs show upon
  option completion. No more pseudo option function "callbacks" that are none
  the better than passing the original Docker config type verbatim.

- uses the official Docker Go client in order to benefit from its security
  fixes, functional upgrades, and all the other nice things to get directly from
  upstream.

- “auto-cleaning” that runs when creating a new test session and again at its
  end, removing all containers and networks especially tagged using
  session.WithAutoCleaning for the test.

- uses context.Context throughout the whole module, especially integrating well
  with testing frameworks (such as Ginkgo) that support automatic unit test
  context creation.

- extensive unit tests with large coverage.

## Trivia

The module name `morbyd` is an amalgation of ["_Moby_
(Dock)"](https://www.docker.com/blog/call-me-moby-dock/) and _morbid_ –
ephemeral – test containers.
