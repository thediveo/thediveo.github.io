---
title: "Using Docker API's `ImageBuild` With BuildKit"
shorttitle: "ImageBuild API & BuildKit"
description: "there's a BuildKit inside my Whale!"
---

# Using Docker API's `ImageBuild` With BuildKit

["BuildKit"](https://github.com/moby/buildkit) describes itself as "[...] _a
toolkit for converting source code to build artifacts in an efficient,
expressive and repeatable manner_".

At the same time, ["_BuildKit is the builder backend used by
Docker_"](https://docs.docker.com/build/buildkit/) (and
[Moby](https://github.com/moby/moby/)). In addition, the Docker/Moby daemons
still support what is called the "legacy builder".

When using the Moby/Docker Go client SDK API it has this
[`Client.ImageBuild`](https://pkg.go.dev/github.com/moby/moby/client#Client.ImageBuild)
method, and that takes a ton of options in form of
[`ImageBuildOptions`](https://pkg.go.dev/github.com/moby/moby/client#ImageBuildOptions).
But we're interested only in its `Version` field as it is related to which
builder to choose:

```go
type ImageBuildOptions struct {
    // Version specifies the version of the underlying builder to use
    Version build.BuilderVersion
}

type BuilderVersion string

const (
	// BuilderV1 is the first generation builder in docker daemon
	BuilderV1 BuilderVersion = "1"
	// BuilderBuildKit is builder based on moby/buildkit project
	BuilderBuildKit BuilderVersion = "2"
)
```

Easy, peasy ... right?

## No Active Session

Unfortunately, at first I did not notice the catch, as I originally had tested
using the BuildKit builder inside the Moby/Docker daemons with too simple a
`Dockerfile`. But as soon as I threw something like the following at it...

```dockerfile
FROM --platform=${BUILDPLATFORM} golang:1-alpine AS builder
FROM alpine AS final
ARG HELLO
RUN echo "..${HELLO}.."
```

... the API call bombed with "alpine: failed to resolve source metadata for
docker.io/library/alpine:latest: no active sessions" or similar. I quickly
noticed that pre-pulling the images made the error go away, but this was just a
sloppy band-aid for a deeper problem.

Problems ... apropos probLLMs: this turned in the usual parrot shitfest with
Kotpilot, Klaudia and ShitGPiT. Calling their verbal dysentery "mediocre" would
be a gross insult to mediocre. These mechanical parrots all told me very amply
how much I'm in the wrong to even attempt and that I must use BuildKit via its
client and sessions and using `/var/run/buildkit/buildkit.socket` (or some other
magic place). Pointing out that Moby/Docker obviously has a BuildKit integrated
and that I need to connect to it didn't help: oh, how this could _not be done_
because "the code" is internal ... blah ... blah blah ... At long last I tried
to prompt out where in the code I should look to, but reached ... \***PLONK**\*
(the sound of multiple clankers hitting rock-bottom).

## Natural Intelligence

While browsing the Docker API documentation I noticed an odd
[`/session`](https://docs.docker.com/reference/api/engine/version/v1.54/#tag/Session)
API endpoint: "_Start a new interactive session with a server_". More
importantly, it states:

> [!QUOTE] This endpoint hijacks the HTTP connection to HTTP2 transport that
> allows the client to expose gPRC services on that connection.[^hijack]

Now, I've had seen that BuildKit services are accessed via gRPC, so this was
starting to get interesting. When searching for `"/session"`, this turned up
_daemon-side_ route setup, but nothing nada zilch for the _client_ side.
However, looking instead for "hijack"[^PI] turned up
[`Client.DialHijack`](https://pkg.go.dev/github.com/moby/moby/client#Client.DialHijack).
So much for probLLMs parrotting[^sic] "there's no official way to do it".
**FFS**.

Okay, now where to look for proper usages of `DialHijack`? In the
`moby/moby/client` and `moby/buildkit` repos I only drew blanks. But wait,
`docker build ...`  is actually `docker buildx build ...` and buildx indeed is a
Docker **plugin**: off to [`docker/buildx`](https://github.com/docker/)!

Bingo! Searching for `DialHijack` in the buildx plugin's repository immediately
[hit the
mark](https://github.com/docker/buildx/blob/f30ef86d21e91400b6e645964b5151aae46b1402/driver/docker/driver.go#L62-L75):

```go
func (d *Driver) Dial(ctx context.Context) (net.Conn, error) {
	return d.DockerAPI.DialHijack(ctx, "/grpc", "h2c", d.DialMeta)
}

func (d *Driver) Client(ctx context.Context, opts ...client.ClientOpt) (*client.Client, error) {
	opts = append([]client.ClientOpt{
		client.WithContextDialer(func(context.Context, string) (net.Conn, error) {
			return d.Dial(ctx)
		}), client.WithSessionDialer(func(ctx context.Context, proto string, meta map[string][]string) (net.Conn, error) {
			return d.DockerAPI.DialHijack(ctx, "/session", proto, meta)
		}),
	}, opts...)
	return client.New(ctx, "", opts...)
}
```

Please note that `client` here refers to package
`github.com/moby/buildkit/client`.

So in this very spot we see the concise _master template_ of how to establish a
BuildKit session with the Moby/Docker Go client SDK API – the simple feat that
the clankers could not tell me even after hours (and after-hours); not even in
their constant degenerated hallucinations.

And next, a HUUUUUGE rabbit hole opened and its event horizon started to grow in
an alarming way...

## Session Transgression

We have a BuildKit client with all its API glory, but **no** way to still use
the Docker API's `Client.ImageBuild` method. Surely, BuildKit clients give
access to all of BuildKit's glorious wonders, in order to "just" build
`Dockerfile`s there is lots of plumbing to be done.

Oh, the probLLMs hallucinated tons of nice plumbing code that expectedly was
beyond any redemption; many repeated hallucinations of incorrect number and
types of parameters were on the lesser side of failure.

Now, the infamous
[`ImageBuildOptions`](https://pkg.go.dev/github.com/moby/moby/client#ImageBuildOptions)
have yet another intriguing field...

```go
type ImageBuildOptions struct {
    // BuildID is an optional identifier that can be passed together with the
	// build request. The same identifier can be used to gracefully cancel the
	// build with the cancel request.
	BuildID string
}
```

Looking around the BuildKit sources we find
[`Session.ID`](https://pkg.go.dev/github.com/moby/buildkit/session#Session.ID) –
while the terminology doesn't match, hopefully this is the same as the above
`BuildID`?

Spoiler: as it turns out luckily it is!

Dang! But we **don't** have a BuildKit session, only a BuildKit _client_.
Unfortunately, this client is completely useless to us. Hmm, how to make an
individually created BuildKit _session_ make use our hijacked Moby/Docker daemon
connection? The trick to know here is:

1. create the BuildKit _session_ using `bksession.NewSession(sessionCtx, "")`.

2. then establish and keep the session spinning in a separate Go routine:

    ```go
    buildkitSession.Run(sessionCtx, func(ctx context.Context, proto string, meta map[string][]string) (net.Conn, error) {
        return s.Client().(client.HijackDialer).DialHijack(ctx, "/session", proto, meta)
    })
    ```

3. ...kick off in the background some state channel processing magic (to be
   covered in a future post)...

4. call the Moby/Docker client SDK's `Client.ImageBuild`, passing it the ID of
   the BuildKit session.

And finally, no more "no active sessions" error results!

## IRL

Interested readers will hopefully find [my
implementation](https://github.com/thediveo/morbyd/blob/c0351c6931bd3eec9fc66e1a97133c0f5149981e/image_build.go#L66-L248)
for using `BuidImage` with buildkit instructive; it's part of my
[morbyd](https://github.com/thediveo/morbyd) Go package.

#### Notes

[^hijack]: <https://docs.docker.com/reference/api/engine/version/v1.54/#tag/Session>

[^PI]: adorable "Political Incorrectness".

[^sic]: the embodiment of "_parrot_" and "_rotting_".
