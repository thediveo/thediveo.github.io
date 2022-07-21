# Testing (Your Go) for Leaks

Go's garbage collection cannot prevent certain leaks: Goroutines and file
descriptors ("fd" for short).

Goroutines cannot be "killed" but must always end themselves – in one way or
another, such as returning or `panic`king. But goroutines can be blocked in
reading from channels or writing into them.

File descriptors are OS-managed resources, and while they get closed when their
process terminates, they can pile up in long-running services. Fds are only
automatically garbage collected when they are opened using one of the
"high-level" Go libraries, such as `os.Open` that ensure to close their
underlying OS resources when the application-facing Go value gets garbage
collected. But there are enough situations where applications or Go modules
either somehow keep `*File`s from getting garbage-collected or need to work at
the OS fd resource level without the `*File` safety net.

Traditionally, leak checking is done by profiling, such as monitoring the
resource consumption of a service under test over periods of time.

But ... isn't this already a tad late? Why not adding leak checks to unit
tests much earlier in the game...?

## Gomega `gleak`


First of all, there's Über's super useful and well-made
[@uber-go/goleak](https://github.com/uber-go/goleak) Go module ... if you like
plain (and brutal) `testing`. Personally, I prefer
[Gomega](https://github.com/onsi/gomega) and
[Ginkgo](https://github.com/onsi/ginkgo). Unfortunately, `goleak` was never
envisioned to be integrated into a TDD ecosystem, such as Gomega.

![Gleaky](_images/gleaky.png)

(_Gleaky, the leaky Gopher mascot_)

After seriously pondering to submit changes upstream to open the currently
internal parts for reuse, I decided against it. Instead, I wrote my own
goroutine discovery and matchers, and integrated all not only figuratively, but
literally, into Gomega. This includes reusing Gomega matchers to filter out
"good" and non-leaking goroutines. My work already has gone upstream and is now
included as the [`gleak`
package](https://onsi.github.io/gomega/#codegleakcode-finding-leaked-goroutines)
in Gomega as of v1.20.0.

Often, all you need to add to your tests can be as simple as:

```go
AfterEach(func() {
    Eventually(Goroutines).ShouldNot(HaveLeaked())
})
```

Depending on how complex your goroutine usage is and how much time they need to
properly wind down, you might want to tweak the overall maximum waiting time and
polling intervall.

```go
AfterEach(func() {
    Eventually(Goroutines).
        WithTimeout(2*time.Second).WithInterval(250*time.Millisecond)
            ShouldNot(HaveLeaked())
})
```

For more details, please head over to [gleak: Finding Leaked
Goroutines](https://onsi.github.io/gomega/#codegleakcode-finding-leaked-goroutines)
in Gomega's documentation.

## `fdooze`

![Goigi](_images/goigi.png)

(_Goigi, the leaky fd plumbing Gopher mascot_)

[@thediveo/fdooze](https://github.com/thediveo/fdooze) provides testing for file
descriptor leakages.

> [!INFO] **fdooze** is available **only for Linux**.

Often, all you need to add to your tests can be as simple as...

```go
BeforeEach(func() {
    goodfds := Filedescriptors()
    DeferCleanup(func() {
        Expect(Filedescriptors()).NotTo(HaveLeakedFds(goodfds))        
    })
})
```

...and then trying hard to plumb all the fd leaks you'll find. 😆

Now, detecting leaked file descriptors is a "slightly" ugly business. First,
file descriptors are simple `int` numbers and these fd numbers aren't
unambiguous identifiers (like Goroutine IDs). So, fd numbers get reused.

To add insult to injury, we are never told _who_ and _where_ a file descriptor
was opened.

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

For other types of file descriptors, such as pipes and sockets, the details
usually will differ: instead of a path, other parameters will be shown, such as
pipe inode numbers or socket addresses.

## Leaky Tests instead of Leaky Production

Fun fact: I've found most leaks in my _unit tests_ instead of my production
code. However, at least I found two potential goroutine leaks in production
code. One that would rarely, if ever, be triggered in production – but luckily
was reproducible triggered by some unit tests as a side effect of the different
behavior of the unit test compared to production use. Ironically, this was also
an example where it actually makes sense to use a buffered channel in order to
allow a goroutine to _fire and forget_ its notification and not giving a fig
whether anybody is still interested in the notification.

Another one that was a clear oversight in cleaning out the elements (with
associated goroutines) in a map.

## Leaky and Goigi

Goigi and Leaky the gopher mascots undoubtedly have been inspired by the Go
gopher art work of [Renee French](http://reneefrench.blogspot.com/).
