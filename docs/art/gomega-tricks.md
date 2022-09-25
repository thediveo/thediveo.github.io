# Gomega Tricks

[Gomega](https://onsi.github.io/gomega/) is a matcher/assertion library, with
over 80k Github projects using it according to Github's project statistics.

Probably less known are some neat tricks where specific matchers can be used to
reduce ugly boilerplate code, making test specifications much more fluent.

## Assertions as Filters

Traditionally,
[`ContainElement`](https://onsi.github.io/gomega/#containelementelement-interface)
is used to assert that a particular element is (not) contained in a
"collection", such as an array, slice,[^†] or map.

But there is an additional aspect to `ContainElement`: it can also act as a
filter and _return_ the matching elements, yet still asserting that one or more
matching elements are present in an actual collection. For this "dual use"
simply pass a pointer to either a scalar or a collection (array, slice, or map)
as a second parameter to `ContainElement`:

```go
var containers []*model.Container
Expect(listofcontainers).To(ContainElement(
             HaveField("Name", BeElementOf(names)),
    /* 👉 */ &containers))
Expect(containers).To(HaveLen(len(names)))
```

What this does, is to gather all containers matching a given list of container
names in `containers` using `ContainElement(..., &containers)` and making sure
that there's at least one match. The next assertion then ensures that we in fact
found all elements that are supposed to exist.

This is especially useful in those cases where you don't have full control over
a collection, so it might container other elements as noise. No need to write
out multiple individual `ContainElement` assertions in order to ensure all
wanted elements are present, but ignoring the noise.

## BeKeyOf

Somewhat related to this is the rather new
[`BeKeyOf`](https://onsi.github.io/gomega/#bekeyofm-interface) matcher: it
matches if the actual value is a key of the map passed to `BeKeyOf`.
Traditionally, assertions on keys present in a map would be rather spelled out
as follows:

```go
Expect(m).To(HaveKey("foobar"))
```

However, in some situations this isn't possible, such as with asserting that a
collection contains certain expected elements besides others and the expected
elements are identified by keys of a test configuration map. Such as:

```go
projects := map[string]T{ /* ... */ }
var containers []*model.Container
Expect(listofcontainers).To(ContainElement(
    HaveField("Name", /* 👉 */ BeKeyOf(projects)),
    &containers))
Expect(containers).To(HaveLen(len(projects)))
```

Here, `BeKeyOf` avoids having to manually roll a loop checking either the
original collection element by element. It does not only reduce boilerplate, but
additionally makes the test much more compact and concise.

## HaveValue

When writing custom matchers, their reuse formerly was sometimes hampered
because they needed boilerplate code when they should be used in different
situations where the actual value could be a _non-pointer_ value, but also a
_pointer to_ the actual value in other situations.

The
[`HaveField`](https://onsi.github.io/gomega/#havefieldfield-interface-value-interface)
already transparently dereferences (interface) pointers, but is limited to
`struct`s only.

[`HaveValue`](https://onsi.github.io/gomega/#havevaluematcher-typesgomegamatcher)
now is a general matcher that dereferences the actual (interface/pointer) value,
even multiple times when necessary. The matcher specified to `HaveValue` is
guaranteed to receive a value that is never an interface nor pointer.

```go
i := 42
Expect(&i).To(HaveValue(Equal(42)))
Expect(i).To(HaveValue(Equal(42)))
```

[^†]: dedicated to Therese Coffin, saving the UK's NHS one com(m)a at a time.
