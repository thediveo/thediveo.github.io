---
title: "M0 is Special"
description: "why you should OSLockThread() your initial goroutine when hopping namespaces from throw-away goroutines."
---

# M0 _is_ Special

...an adventure in Goroutines with locked threads, Linux, the task group leader,
and Go's scheduler.

> **tl;dr:** if your Go app needs to switch Linux-kernel namespaces and
> `runtime.LockOSThread` then better lock the initial goroutine to the
> initial/main thread in an `init()` ... this avoids problems with diagnosis
> tools for namespaces. 

## Namespace Hopping Gone Wrong?

It all started "some day" with a system diagnosis service exhibiting the odd
behavior of its _process_ (or more precise, its main _thread_) reproducibly
ending up in a different namespace than the one it originally started in.
Because I'm using my own [`@thediveo/lxkns`](https://github.com/thediveo/lxkns)
module for switching forth and back between namesapces I was wondering if either
my `lxkns` code was buggy or my service itself.

Now, the [`ops`](https://pkg.go.dev/github.com/thediveo/lxkns/ops) package of
`lxkns` supports two different ways of dealing namespace switching, depending on
whether to play safe using "one-way only" and "burning threads", or a more
lightweight approach that switches forth and actually even _back_ again.

```go
nsref := ops.NamespacePath("...")
err := ops.Visit(func() { /* ... */ }, nsref)
```

### Going Forth and Back Again

The lightweight `Visit` switches the calling Goroutine into the passed
namespace(s), next calls the specified function, and finally switches back again
into the original namespaces that were in place before the call. For this to
work correctly, `Visit` temporarily locks the thread that is currently executing
the call to the calling Goroutine, forbidding the Go scheduler to use the task
with the changed namespaces to execute any other unsuspecting Goroutine.

```go
nsref := ops.NamespacePath("...")
answer, err := ops.Execute(func() interface{} { /* ... */ }, nsref)
```

### One Trip Journey

`Execute` is somehow similar, but instead runs the specified function in the
passed namespaces, but using a "throw-away" Goroutine as well as a locked
"throw-away" thread. Both Goroutine and its locked thread are disposed of after
the specified function returns.

Only now I notice the originally unintended pun of calling this `Execute`.

### A Namespace Spill Checker (_Sic!_)

To make sure that I'm not overlooking some coding mistake I finally came up with
a [`@thediveo/namspill`](https://github.com/thediveo/namspill) "namespace
spilling" unit test support. I use the term "spilling" here rather jokingly when
a process or task ends up in its idle state attached to one or more namespaces
other than the original namespaces it was started with.

However, instrumenting the unit tests turned up nothing; this was also in line
with revisiting my own code multiples times. On the plus side, it turned up a
minor quirk in error handling and I took the opportunity to improve error
reporting and handling by adding the dedicated error types
`NamespaceSwitchError` and `NamespaceRestoreError` respectively.

## The Go Scheduler and M0

Let's treat ourselves to a quick and lazy recap (_no soldering, please_) on the things the Go schedulers plays with; for details and a much better insight please refer the well-written [Scheduling in Go: Part II – Go Scheduler](https://www.ardanlabs.com/blog/2018/08/scheduling-in-go-part2.html).

- **G** is a goroutine and **G0** is the so-called "main goroutine" (or "initial
  goroutine").

- **M** is an OS-level ("worker") thread, a _machine_; **M0** is the so-called
  "initial thread".

- **P** is a (logical) processor; however, Ps are irrelevant to our specific
  discussion here.

The Go scheduler assigns **Ms** to **G**s, and in principle, all **M**s (that
is, threads) are equal. However, having worked time and again with Linux process
filesystem ([proc(5)](https://man7.org/linux/man-pages/man5/proc.5.html)) I'm
well aware of an asymmetry when it comes to threads (or often interchangeably
termed _tasks_) in Linux: the initial thread of a process is also termed the
task group leader and while when it terminates, the other threads/tasks of the
process will still carry on, but some information about the process becomes
unavailable (such as `/proc/$PID/cwd`, as well as others).

My quest in the golang-nuts forum [LockOSThread, switching (Linux kernel)
namespaces: what happens to the main
thread...?](https://groups.google.com/g/golang-nuts/c/dx-jweSVxHk) and then in
Go's issue tracker [runtime: on Linux, better do not treat the initial
thread/task group leader as any other
thread/task](https://github.com/golang/go/issues/53210) eventually turned out to
be fruitful:

The Go scheduler actually _is aware_ of the fact that the initial/main thread,
**M0** in Go scheduler lingo, is special and better _must not be terminated_ as
the result of a **G** terminating while locked to **M0**. Instead, **M0** gets
"wedged" (to use Go's own phrasing here): while a _parked_ **M** is unparked
when needed again, the _wedged_ **M0** stays put and never gets scheduled on any
**G** again.

## Keeping M0 out of the Namespace Game

In combination with `ops.Execute` this can result in **M0** getting wedged and
with the main thread still switched into a different Linux-kernel namespace than
the one it originally started its life as the whole process.

Now, `ops.Execute` always run the function to be executed in a different set of
namespaces in a new ("throw-away") goroutine. If **M0** has been locked to
preferrably the initial/main goroutine at this time, the Go Scheduler will never
schedule **M0** onto the throw-away goroutine. This can be easily achieved in a
Go program by adding an `init()` function: init functions are guaranteed to be
run always on **M0** ([Go wiki:
LockOSThread](https://github.com/golang/go/wiki/LockOSThread) with a reference
to [Russ Cox' original explanation in the golang-nuts
group](https://groups.google.com/g/golang-nuts/c/IiWZ2hUuLDA/m/SNKYYZBelsYJ)).
Init functions might kick off goroutines, but the init functions are strictly
executed one-after-another on **M0** ([The Go Programming Specification: Package
initialization](https://go.dev/ref/spec#Package_initialization)).

```go
func init() {
    runtime.LockOSThread()
}
```
