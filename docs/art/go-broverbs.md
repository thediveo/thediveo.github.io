---
title: "Go Broverbs, or: Words of Wishdom"
shorttitle: "Go Broverbs"
description: "use your brains, not broverb rule-based coding."
---

# Broverbs

Words of Wishdom for the faithful Gopher.

> [!QUOTE] **Brian:** Look, you've got it all wrong! You don't need to follow
> me. You don't need to follow anybody! You've got to think for yourselves!
> You're all individuals!
>
> **(Go) Crowd:** [in unison] Yes! We're all individuals![^Realsatire]

## Any(thing) Go(es)

[_`interface{}` says
nothing_](https://www.youtube.com/watch?v=PAAkCSZUG1c&t=456s) ... that broverb
aged like Liz Truss in Downing Street.

The [`slices`](https://pkg.go.dev/slices) package as of Go 1.26 says it 29 times
in its exported function signatures, in its fresher `any` shorthand. We can
safely accept that `interface{}`/`any` actually says a lot.

## Copy-on-Write

[_A little copying is better than a little
dependency_](https://www.youtube.com/watch?v=PAAkCSZUG1c&t=568s) ... until you
realize that you need proper unit tests, too.

## Abstractions are Distractions

Write testing assembler!

There is a strong feeling with several (including core team) Go developers that
(to paraphrase them) "_Abstractions are Distractions_" when it comes to writing
unit tests. I can imagine them then pasting another 🧿 eye bead unicode
character into their LLM prompts to be on the safe side, especially after
exposure to these pure evil TDD frameworks, like
[Gomega](https://github.com/onsi/gomega) plus
[Ginkgo](https://github.com/onsi/ginkgo),
[gotest.tools](https://github.com/gotestyourself/gotest.tools), as well as
several more.

If _you_ only need to write tests for flat data structures, the better for
_you_. But don't assume your horizon is the universe.

There are enough non-trivial and potentially recursive data models, where
writing this kind of "`testing` assembler" doesn't clearify things, it obstructs
them in a farrago of distracting low-level details, such as tons of

```go
if foo == nil {
    t.Error("foo should not be nil")
}
if foo.bar == nil {
    t.Error("foo.bar should not be nil")
}
if foo.bar.baz != 42 {
    t.Error("foo.bar.baz should be 42")
}
```

You think this example, erm, _artifical_? Then you have never worked with APIs
with lots of deeply nested, optional arguments, such as the Docker API and many
other APIs.

Another typical situation I face on an almost daily basis when writing unit
tests is to check a few nested attributes in a slice of elements – or even an
iterator – in a concise manner. Of course, if you never care to unit test your
Prometheus or OpenTelemetry output or prefer Go `testing` assembler, then the
following concise code comes straight from [It's evil, don't touch
it](https://www.youtube.com/watch?v=QKGbguoildA).

```go
Expect(sprockets).To(
    HaveEach(HaveField("fluxalia.size", Equals(1.35))))
```

#### Footnotes

[^Realsatire]: based on statements by some of the surviving Python members where
    they repeatedly, pardon, parroted dispelled statements on Brexit and the
    European Union they sadly never understood the depth of their own movie and
    have become the very type of people they mocked.
