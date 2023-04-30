# Docker cap-add & cap-drop

**[Linux
capabilities](https://man7.org/linux/man-pages/man7/capabilities.7.html)** – the
holy grail of security. Or, hell envisioned by POSIX and offered to unsuspecting
penguins. You decide.

Anyway, how are Linux capabilities assigned containers? Or more precise, how are
the capabilities declared on container deployment in order to then become the
"effective" and "bounded" capabilities for the processes running inside the
container?

## Container Capability Declaration

Unfortunately, the [Docker compose file
reference](https://docs.docker.com/compose/compose-file/compose-file-v2/#cap_add-cap_drop)
describes the `cap_add` and `cap_drop` elements in rather terse fashion and
hardly useful manner:

> [!QUOTE]
> Add or drop container capabilities. See `man 7 capabilities` for a full list.

Yes, that's it. Now we're enlighted, or are we?

- How do `cap_add` and `cap_drop` actually interact, especially as there is no
  order defined for them in a YAML composer document? Please remember, YAML
  dictionaries don't define any order of the keys, and `cap_add` and `cap_drop`
  are keys for two arrays of capabilities.

- What happens if one or even both of `cap_add` and `cap_drop` contains `ALL`?

To solve this mystery I had to dive into moby's source code and was lucky to
(unexpectedly quickly) find
[`TweakCapabilities`](https://github.com/moby/moby/blob/master/oci/caps/utils.go#L120).
`TweakCapabilities` takes a set of capabilities to add as well as a set of
capabilities to drop and then calculates the resulting set of capabilities.

## Full G(l)ory

The result of `TweakCapabilities` is most probably best illustrated in terms of
adding and dropping capabilities using an infographic:

![cap_add and cap_drop](/_images/docker-cap-add-cap-drop.svg)

The "default capabilities" depend on the intersection of:

1. Docker's own version-specific list of default capabilities,
2. the bounded capabilities of the Docker daemon process(es).

## Least Privilege

But in the end, there are only the following two "deterministic" combinations:
always include `cap_drop: ALL`, following the line of least privilege. And this
are the outcomes:

![cap_drop ALL](/_images/docker-cap-drop-all.svg)

## To CAP_ or Not To CAP_

Since Docker 19.x both capabilities naming schemes are supported, so it doesn't
matter whether a particular capability is added or dropped as `CAP_SYS_ADMIN` or
just `SYS_ADMIN`.

However, before Docker 19, you must use the odd `CAP_`-less capabilities names,
which are at odds with all existing Linux capabilitiy naming practise: Docker up
to and including 18.x only accepts `SYS_ADMIN` and rejects the Linux standard
`CAP_SYS_ADMIN`.

Normally, you most probably won't bother about Docker 18.x or 19.x in 2022
(decimal, not octal). Unless, well, unless you are working in some special
fields that solely survive on alternate time scales.
