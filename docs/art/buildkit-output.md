---
title: "Dealing With `ImageBuild`'s BuildKit Output"
shorttitle: "ImageBuild's BuildKit Output"
description: "how to correctly deal with the multiple layers of data streams when using `ImageBuild` with BuildKit."
---

# Dealing With `ImageBuild`'s BuildKit Output

In our first part [Using Docker API's `ImageBuild` With
BuildKit](/art/buildkit.md) we learned how to do the additional plumbing in
order to get the trusty old
[`ImageBuild`](https://pkg.go.dev/github.com/moby/moby/client#Client.ImageBuild)
Docker API method working (again) when selecting BuildKit as the builder.

## ImageBuild JSON Stream

In this second part we deal with the output streamed by the `ImageBuild` client
method: which, at the outmost layer, is a stream of JSON objects. Regardless of
whether we're using the old legacy build or BuildKit, this JSON object stream is
important to us in all cases, if it is just for the reason that only this stream
tells us the ID of the built image.

Thankfully, the Moby Go client SDK hides the unpleasant details from us when it
comes to parsing this stream:
[`jsonmessage.DisplayStream`](https://pkg.go.dev/github.com/moby/moby/client/pkg/jsonmessage#DisplayStream).
This helper guzzles the trickling response body, especially handling the complex
mechanics of rendering textual output to an `io.Writer` we're supplying. This
output is crucial in diagnosing a large class of failing image builds. A typical
use case is to supply a
[`GinkgoWriter`](https://pkg.go.dev/github.com/onsi/ginkgo/v2#GinkgoWriter) that
keeps the output for itself unless the test fails and then it spills the beans. 

In particular, we're interested at this level mostly in what is termed
"auxiliary jsonstream messages" in the SDK, and there only those aux messages
that carry out-of-band data that again is JSON inside the JSON and has an `ID`
(all uppercase) field. This inner `ID` field tells us at (somewhere near) the
end the specific reference of the image that we've just finished building.

> [!IMPORTANT] Please don't confuse the (outer) `ID` filed of the [JSON stream
> messages](https://pkg.go.dev/github.com/moby/moby/api/types/jsonstream#Message)
> with the (inner) `ID` field of the JSON contained in the (outer) `Aux` field.

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

Now, onto the next layer: those auxiliary JSON stream messages that have an
outer `ID` of `"moby.buildkit.trace"`. As it turns out, these BuildKit auxiliary
messages are rather complex in that they are protobuf-encoded. Luckily (again),
digging deeper into the BuildKit code base turns up client "progressui"
functionality that "feeds" on [status
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

As these status response messages are protobuf elements, they're very raw and
not for diagnosis consumption. Again, we're relying on BuildKit convenience
helpers to deal with the complexities of separating text output from final
warnings, and more. The has to be done on its own go routine, with the `chan
*bkclient.SolveStatus` plumbing the BuildKit auxiliary messages into the
BuildKit "display" updating.

```go
bkdisplay, err := progressui.NewDisplay(bios.Out, progressui.AutoMode)
statech = make(chan *bkclient.SolveStatus, 32)
warnings, err := bkdisplay.UpdateFrom(ctx, statech)
```

## Running the Show

By now you might be very well somewhat lost, so let's recap: the following go
routine "cogs" engage and turn simultaneously...

1. processing `ImageBuild`'s JSON messages stream, picking up the final image
   `ID`, as well as any BuildKit messages.
2. running a BuildKit session,
3. processing BuildKit (solver status) messages, updating the textual
   (diagnosis) output and collecting warnings.

The tricky part here is correct error handling, because BuildKit throws a very
nice huge yellow spanner at us: the `Run` method of BuildKit sessions has fallen
victim to the dreaded mixed error reporting anti-pattern. Now, where did we saw
this also? Yep, the defective `client.Events` of p.o.'d.man.

When `client.Events` or `buildkitsession.Run` return with an error, we have no
idea if the function failed before doing its work, or did some of its work and
then failed because we cancelled its context to make it stop. The important
difference between these cases is that in the first case it is a real error that
must be reported to the user, but in the second case we don't want to report
something that's rather internal.

Now, all these three cogs can fail early during the initialization phases.
Devilishly, these errors can be follow-up of earlier failures in a different
cog. Thus, while using an `errgroup` we must be careful in _when_ each of the
three above listed concurrent go routines eventually terminate and report any
error. If a go routine fails but isn't the first domino, without further
measures it races with the first domino go routine in returning the error code,
completely mudding the waters.

But there's also the situation where the first domino cannot trip another domino
