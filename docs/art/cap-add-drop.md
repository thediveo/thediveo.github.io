# Docker cap-add & cap-drop

The [Docker compose file
reference](https://docs.docker.com/compose/compose-file/compose-file-v2/#cap_add-cap_drop)
describes the `cap_add` and `cap_drop` elements in a rather terse fashion and
hardly useful manner:

> Add or drop container capabilities. See `man 7 capabilities` for a full list.

But how do `cap_add` and `cap_drop` interact, especially as there is no order
defined for them in a YAML composer document, both elements being in a
dictionary? And what happens if one or both of `cap_add` and `cap_drop` contains
`ALL`?

To solve this mystery I had to dive into moby's source code and was lucky to
unexpectedly quickly find
[`TweakCapabilities`](https://github.com/moby/moby/blob/master/oci/caps/utils.go#L120).
`TweakCapabilities` takes a set of capabilities to add as well as a set of
capabilities to drop and then calculates the resulting set of capabilities.

The result of `TweakCapabilities` can be illustrated in terms of adding and
dropping capabilities as follows:

![cap_add and cap_drop](/_images/docker-cap-add-cap-drop.svg)

But in the end, there's only the following two "deterministic" combinations that
always include `cap_drop: ALL` and that follow the line of least privilege:

![cap_drop ALL](/_images/docker-cap-drop-all.svg)
