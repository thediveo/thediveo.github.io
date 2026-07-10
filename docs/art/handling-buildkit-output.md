---
title: "Handling `ImageBuild`'s BuildKit Output"
shorttitle: "Handling BuildKit Output"
description: "how to correctly handle the multiple layers of data streams when using `ImageBuild` with BuildKit."
---

# Handling `ImageBuild`'s BuildKit Output

In the first part titled [Using Docker API's `ImageBuild` With
BuildKit](/art/buildkit.md) we learned how to create the additional plumbing in
order to get the trusty old
[`ImageBuild`](https://pkg.go.dev/github.com/moby/moby/client#Client.ImageBuild)
Docker API method working (again) when selecting BuildKit as the builder. We
successfully ditched the superior wisdom of LLMs that told us that this isn't
possible, or it's internal, or it's whatever the statisticial fool tools cough
up.

## ImageBuild JSON Stream

In this second part we now deal with what the `ImageBuild` client method
_streams_ as output: at its outmost layer, this isn't plain text but a stream of
_JSON objects_. Regardless of whether we're using the old legacy builder or the
now standard BuildKit, this JSON object stream is important to us in all cases,
if it is just for the reason that only this stream tells us the ID of the built
image. The API method call itself won't give this important information.

Thankfully, the Moby Go client SDK hides the unpleasant details from us when it
comes to parsing this stream with its
[`jsonmessage.DisplayStream`](https://pkg.go.dev/github.com/moby/moby/client/pkg/jsonmessage#DisplayStream).
This helper guzzles the trickling response body, handling for us the complex
mechanics of the different stream JSON objects, as well as finally rendering
textual output to an `io.Writer` we're supplying. This output is crucial in
diagnosing a large class of failing image builds. A typical use case is to
supply a
[`GinkgoWriter`](https://pkg.go.dev/github.com/onsi/ginkgo/v2#GinkgoWriter) that
keeps the output for itself unless the test spec fails and only then the
`GinkgoWriter` spills the beans.

## Auxiliary JSON Stream Messages

At this outer level and regardless of the builder we're using, we're especially
interested in what is termed "auxiliary jsonstream messages" in the SDK, and
here only in those aux messages that carry out-of-band data that again is JSON
inside the JSON and has an `ID` (all uppercase) field. This inner `ID` field
tells us at (somewhere near) the specific reference of the image that we've just
finished building.

> [!IMPORTANT] Please don't confuse the _outer_ `ID` field of the [JSON stream
> messages](https://pkg.go.dev/github.com/moby/moby/api/types/jsonstream#Message)
> with the _inner_ `ID` field of the JSON contained in the _outer_ `Aux` field.

```go
resp, err := s.moby.ImageBuild(ctx, bios.Context, bios.ImageBuildOptions)
if err != nil {
    return fmt.Errorf("image build failed, reason: %w", err)
}
defer func() { _ = resp.Body.Close() }()
err = jsonmessage.DisplayStream(resp.Body, bios.Out,
    jsonmessage.WithAuxCallback(func(auxmsg jsonstream.Message) {
        // Please note that the image ID is reported using an aux message
        // with its own embedded JSON message and not directly via an "ID"
        // JSON message.
        aux := struct {
            ID string `json:"ID"`
        }{}
        if err := json.Unmarshal(*auxmsg.Aux, &aux); err != nil || aux.ID == "" {
            return
        }
        // Pick up the image ID when it floats by ... and is non-zero.
        idval.Store(aux.ID)
    }))
// ...
```

## BuildKit Aux Messages

Now, let's dig into the next layer: those auxiliary JSON stream messages that
have an _outer_ `ID` of `"moby.buildkit.trace"`. As it turns out, these BuildKit
auxiliary messages are rather complex in that they are protobuf-encoded. Luckily
(again), further digging into the BuildKit code base turns up buildkit client
"progressui" functionality that understands these buildkit trace [status
responses](https://pkg.go.dev/github.com/moby/buildkit/api/services/control#StatusRequest)...

```go
statech = make(chan *bkclient.SolveStatus, 32)

err = jsonmessage.DisplayStream(resp.Body, bios.Out,
    jsonmessage.WithAuxCallback(func(auxmsg jsonstream.Message) {
        if auxmsg.ID == "moby.buildkit.trace" {
            if auxmsg.Aux == nil {
                return
            }
            var bkpbmsg []byte
            if err := json.Unmarshal(*auxmsg.Aux, &bkpbmsg); err != nil {
                return
            }
            var status bkcontrol.StatusResponse
            if err := proto.Unmarshal(bkpbmsg, &status); err != nil {
                return
            }
            statech <- bkclient.NewSolveStatus(&status)
            return
        }
        // Please note that the image ID is reported using an aux message
        // with its own embedded JSON message and not directly via an "ID"
        // JSON message.
        aux := struct {
            ID string `json:"ID"`
        }{}
        if err := json.Unmarshal(*auxmsg.Aux, &aux); err != nil || aux.ID == "" {
            return
        }
        // Pick up the image ID when it floats by ... and is non-zero.
        idval.Store(aux.ID)
    }))
```

## BuildKit Status Response Messages

Now that these status response messages are protobuf elements, they're very raw
and not for direct human consumption or direct writing to a log as-is. Again,
we're relying on BuildKit convenience helpers to deal with the complexities of
separating text output from final warnings, and more. This processing has to be
done on its own go routine, with the `chan *bkclient.SolveStatus` plumbing the
BuildKit auxiliary messages into the BuildKit "display" updating as follows:

```go
bkdisplay, err := progressui.NewDisplay(bios.Out, progressui.AutoMode)
statech = make(chan *bkclient.SolveStatus, 32)
warnings, err := bkdisplay.UpdateFrom(ctx, statech)
```

## Running the Show

By now you might be very well "somewhat" lost, so let's recap: the following
"cogs" (in form of go routines) engage and turn simultaneously...

1. processing `ImageBuild`'s JSON messages stream, picking up the final image
   `ID`, as well as any BuildKit messages.
2. running a BuildKit session,
3. processing BuildKit (solver status) messages, updating the textual
   (diagnosis) output and collecting warnings.

For the no-error case, this should be fairly straightforward. But the tricky
part is correct error handling while neither getting stuck nor leaving go
routines leaking around. This is in part, because BuildKit throws a very huge
 and very yellow spanner at us: the `Run` method of BuildKit sessions has fallen
victim to the dreaded mixed error reporting anti-pattern. Now, where did we saw
this before? Yep, the defective `client.Events` API of p.o.'d.man.

When `client.Events` or `buildkitsession.Run` return with an error, we have no
idea if the function failed before doing its work, or whether it did some of its
work and then failed because we cancelled its context to make it stop. The
important difference between these cases is that in the first case it is a real
error that must be reported to the user and the other go routines also wound
down, but in the second case we don't want to report something that's rather
internal.

Now, all these three cogs can fail early during the initialization phases.
Devilishly, these errors can be follow-up of earlier failures in a different
cog. Thus, while using an `errgroup` we must be careful in _when_ each of the
three above listed concurrent go routines eventually terminate and report any
error. If a go routine fails but isn't the first domino, without further
measures it races with the first domino go routine in returning the error code,
completely mudding the waters.

But there's also the situation where the first domino cannot trip another domino
