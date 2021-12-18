# Docker cap-add & cap-drop

Unfortunately, the [Docker compose file
reference](https://docs.docker.com/compose/compose-file/compose-file-v2/#cap_add-cap_drop)
describes the `cap_add` and `cap_drop` elements in a rather terse fashion and
hardly useful manner:

> Add or drop container capabilities. See `man 7 capabilities` for a full list.

Yes, that's it. Hardly helpful, or is it?

How do `cap_add` and `cap_drop` actually interact, especially as there is no
order defined for them in a YAML composer document? YAML dictionaries don't
define any order of the keys, and `cap_add` and `cap_drop` are keys for two
arrays of capabilities.

And then, what happens if one or even both of `cap_add` and `cap_drop` contains
`ALL`?

To solve this mystery I had to dive into moby's source code and was lucky to
unexpectedly quickly find
[`TweakCapabilities`](https://github.com/moby/moby/blob/master/oci/caps/utils.go#L120).
`TweakCapabilities` takes a set of capabilities to add as well as a set of
capabilities to drop and then calculates the resulting set of capabilities.

## Full G(l)ory

The result of `TweakCapabilities` is most probably best illustrated in terms of
adding and dropping capabilities in an infographic:

![cap_add and cap_drop](/_images/docker-cap-add-cap-drop.svg)

The "default capabilities" depend on the intersection of:

1. Docker's own version-specific list of default capabilities,
2. the bounded capabilities of the Docker daemon process(es).

## Least Privilege

But in the end, there are only the following two "deterministic" combinations:
always include `cap_drop: ALL`, following the line of least privilege. And this
are the outcomes:

![cap_drop ALL](/_images/docker-cap-drop-all.svg)
