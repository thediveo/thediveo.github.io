# Testing (Your Go) for Leaks

Go's garbage collection cannot prevent certain leaks: Goroutines and file
descriptors ("fd" for short).

Goroutines cannot be "killed" but must always end themselves – in one way or
another, such as returning or `panic`king. But goroutines can be blocked in
reading from channels or writing into them.

File descriptors are OS-managed resources, and while they get closed when their
process terminates, they can pile up in long-running services. Fds can only be
automatically garbage collected when they are opened using one of the
"high-level" Go libraries, such as `os.Open` that ensure to close their
underlying OS resources when the application-facing Go value gets garbage
collected. But there are enough situations where applications or Go modules need
to work at the OS resource level.

Traditionally, leak checking is done by profiling, such as monitoring the
resource consumption of a service under test over periods of time.

But ... isn't this already a tad late? Why not adding leak checks to unit
tests much earlier in the game...?

## Gomega `gleak`


Admittedly, there's Über's highly useful and well-made
[@uber-go/goleak](https://github.com/uber-go/goleak) Go module ... if you like
plain (and brutal) `testing`. Personally, I prefer
[Gomega](https://github.com/onsi/gomega) and
[Ginkgo](https://github.com/onsi/ginkgo). Unfortunately, `goleak` was never
envisioned to be integrated into a TDD ecosystem, such as Gomega.

![Gleaky](_images/gleaky.png)

(_Gleaky, the leaky Gopher mascot_)

So I wrote my own goroutine matcher and integrated it not only figuratively, but
literally, into Gomega. This includes reusing Gomega matchers to filter out
"good" and non-leaking goroutines. My code has already gone upstream and is now
included as the [`gleak`
package](https://onsi.github.io/gomega/#codegleakcode-finding-leaked-goroutines)
in Gomega.

Often, all you need to add to your tests can be as simple as:

```go
AfterEach(func() {
    Eventually(Goroutines).ShouldNot(HaveLeaked())
})
```

For more details, please see Gomega's documentation.

## `fdooze`

![Goigi](_images/goigi.png)

(_Goigi, the leaky fd plumbing Gopher mascot_)

[@thediveo/fdooze](https://github.com/thediveo/fdooze) provides testing for file
descriptor leakages.

> [!INFO] **fdooze** is available **only for Linux**.

Often, all you need to add to your tests can be as simple as ... and trying to
plumb the leaks you'll find:

```go
BeforeEach(func() {
    goodfds := Filedescriptors()
    DeferCleanup(func() {
        Expect(Filedescriptors()).NotTo(HaveLeakedFds(goodfds))        
    })
})
```

Now, detecting leaked fds is a slightly ugly business. First, fd numbers are not
unambiguous identifiers like Goroutine IDs. So, fd numbers get reused. Then, we
are never told _who_ and _where_ an fd was opened.

Despite such limitations, fd leak testing still can be quite useful. Thus,
`fdooze` does not blindly just compare fd numbers, but takes as much additional
detail information as possible into account: like file paths, socket domains,
types, protocols and addresses, et cetera.

On finding leaked file descriptors, fdooze dumps these leaked fds in the failure
message of the `HaveLeakedFds` matcher. For instance:

```
Expected not to leak 1 file descriptors:
    fd 7, flags 0xa0000 (O_RDONLY,O_CLOEXEC)
        path: "/home/leaky/module/oozing_test.go"
```

For other types of file descriptors, such as pipes and sockets, several details
will differ: instead of a path, other parameters will be shown, like pipe inode
numbers or socket addresses.

## Leaky Tests instead of Leaky Production

Fun fact: I've found most leaks in my _unit tests_ instead of my production
code. However, at least I found one potential goroutine leak in production code
that would rarely, if ever, be triggered in production – but luckily was
reproducible triggered by some unit tests as a side effect of the different
behavior of the unit test compared to production use.

Ironically, this was also an example where it actually makes sense to use a
buffered channel in order to allow a goroutine to _fire and forget_ its
notification and not giving a fig whether anybody is still interested in the
notification.

## Leaky and Goigi

Goigi and Leaky the gopher mascots undoubtedly have been inspired by the Go
gopher art work of [Renee French](http://reneefrench.blogspot.com/).
