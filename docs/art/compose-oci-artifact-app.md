---
title: "Docker Compose OCI Artifact Apps"
shorttitle: "🐙 OCI Artifact Apps"
description: "bye-bye curl and wget, welcome `oci://` to fetch Docker compose stacks."
---

# Docker Compose OCI Artifact Apps

Since around March 2025[^compose-release] Docker compose supports handling
compose YAML configuration files as OCI artifacts, pushing and pulling them to
and from registries. This way, we can say _bye-bye_ to `curl` and `wget` and
_thanks for the fish_! All our users need is a suitable Docker compose v2
plugin[^lts] and off we deploy!

Docker outlines how to use OCI artifact apps in its [Package and deploy Docker
Compose applications as OCI
artifacts](https://docs.docker.com/compose/how-tos/oci-artifact/) documentation.

Basically:

1. publish a `docker-compose.yaml`[^dcy] with `docker compose publish ...`
2. then your users can consume it using `docker compose -f oci://... up`.

But now let's dive right into it: real-world experience instead of vibe
hallucination and random word salad posing as "understanding".[^probLLMs]

## Compose Plugin

Not unexpectedly, after quickly reading through the documentation some blanks
remain, as well as some compose versions belly flopping despite implementing
`docker compose publish`. At the time of this writing, a non-representative
random sample yielded success for the following plugin versions:

- works: **v5.0.2** of the docker compose plugin from upstream Docker CE
  packages.
- public GH codespaces:
  - works: **v2.38.2-1** docker compose plugin inside the codespace
    VM's[^nsenter] itself.
  - works: due to limits to the Docker API version skew the devcontainer inside
    the codespace VM should preferably use a Docker client around version "24.0"
    using the `docker-outside-of-docker` feature. At the time of this writing
    this installs the docker compose plugin **v2.40.3**.

Please note that the codespace default devcontainer image uses the
`docker-in-docker` feature which installs much more recent Docker engine and CLI
versions, as well as a recent docker compose plugin.

## Publishing SemVersion'ed OCI Artifact Apps

A `docker-compose.yaml` file can be pushed into an OCI registry with [`docker
compose publish
...`](https://docs.docker.com/reference/cli/docker/compose/publish/). It expects
the compose YAML file(s) passed via `-f` _before_ the `publish` subcommand. The
subcommand takes some optional CLI flags and always expects a repository
reference. For instance:

```bash
docker compose \
    -f deployments/app/docker-compose.yaml \
    publish --resolve-image-digests \
    ghcr.io/thediveo/lxkns/app:1.23.4
```

If you want to use multiple tags, such as (_gasp_) `latest`, `1`, `1.23` and
`1.23.4` you'll need to take four turns.

When using version-tagged OCI artifact apps we also want to pin the image
references of the app to specific sha256's using `--resolve-image-digests`.

To give a [concrete CI
example](https://github.com/thediveo/lxkns/blob/master/.github/workflows/buildandrelease.yaml)
for GitHub – this pushes the OCI artifact app only when the trigger was a tag.
For convenience, we show some context so you can better see where the (final)
OCI artifact publishing step comes in and what its context is:

```yaml
jobs:
  build-and-publish:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      # ...the usual initial steps

      - name: Log into the container registry
        uses: docker/login-action@c94ce9fb468520275223c153574b00df6fe4bcc9 # v3
        if: github.ref_type == 'tag'
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Docker metadata
        uses: docker/metadata-action@c299e40c65443455700f0fdfc63efafe5b349051 # v5
        id: metadata # later referenced as "steps.metadata."
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=semver,pattern={{major}}
            type=raw,value={{sha}},enable=${{ github.ref_type != 'tag' }}

      - name: Build and push Docker image     
        uses: docker/build-push-action@263435318d21b8e681c14492fe198d362a7d2c83 # v6
        # ...

      - name: Publish compose file as OCI artifact
        if: github.ref_type == 'tag'
        shell: bash
        run: |
          echo "${{ steps.metadata.outputs.tag-names }}" | while read -r tag; do
            TAG="$tag" docker compose \
              -f deployments/oci-artifact-app/docker-compose.yaml \
              publish --resolve-image-digests \
                ghcr.io/${{ github.repository }}/app:$tag
          done
```

You might now wonder why this uses `steps.metadata.outputs.tag-names` instead of
`steps.metadata.outputs.tags`? Contrary to the output names, `tags` does contain
the full image refs. However, we just need the tags and these are available
through `tag-names` from `docker/metadata-action`.

We also set the `TAG` environment variable when running the `docker compose
publish` command: the reason hopefully becomes clear when we show our
[`docker-compose.yaml`](https://github.com/thediveo/lxkns/blob/master/deployments/oci-artifact-app/docker-compose.yaml):

```yaml
name: lxkns
services: 
    lxkns:
        image: ghcr.io/thediveo/lxkns:${TAG:-latest} # gets sha256-pinned as part of publication
        # ...
```

The `TAG` environment variable gets interpolated to the correct image tag (which
we pushed in the previous step) when `docker compose` reads the compose file.
However, as we'll see shortly, `docker compose publish` won't modify the compose
file contents, but instead append another YAML document overriding the image
references.

> [!NOTE]
>
> Please note that the optional [`--app` CLI flag currently is
> useless](https://github.com/docker/compose/issues/13428) when publishing on
> GitHub and Gitlab.

## Deploying OCI Artifact Apps

To deploy, simply reference the OCI artifact app with an `oci://` URL. For
whatever reasons, `docker compose` might spit out error 404 info logs when the
OCI URL is on GitHub (and probably also on Gitlab) but otherwise succeeds.

```bash
docker compose -f oci://ghcr.io/thediveo/lxkns/app:0.40.0 up -d
```

Despite the 404 info logs the required container image should be pulled and the
compose project then brought up. Please notice the message about the location
where the cached composer YAML is stored.

```console
INFO[0000] fetch failed after status: 404 Not Found      host=ghcr.io spanID=... traceID=...
INFO[0001] fetch failed after status: 404 Not Found      host=ghcr.io spanID=... traceID=...
Your compose stack "oci://ghcr.io/thediveo/lxkns/app:0.40.0" is stored in "/home/.../.cache/docker-compose/4e8325a13957dd7cfac95829d68e8b8771dd72d8f801b08f2e4ec959452726ab"
[+] up 1/1
 ✔ Container lxkns-lxkns-1 Running
```

> [!ATTENTION]
>
> If `docker compose -f oci://ghcr.io/thediveo/lxkns/app up -d` gives you the
> error that `/lxkns` cannot be executed, you're unfortunately using a broken
> version of the Docker compose plugin. You'll need to upgrade.

Now, let's take a look at the composer YAML inside the above mentioned location:

```yaml
name: lxkns
services: 
    lxkns:
        image: ghcr.io/thediveo/lxkns:${TAG:-latest} # gets sha256-pinned as part of publication
        # ...
---
services:
  lxkns:
    image: ghcr.io/thediveo/lxkns:0.40.0@sha256:42799f9267893413ae40c9c896e4f2ed2216253239a9db629b253e99e9e30e67
```

At first, you might be surprised that the non-interpolated composer YAML is
being used ... where's the image pinning?!

After the first shock, please notice the trailing additional YAML document,
separated by `---` from the original composer YAML. And this second YAML
document now overrides the image references with properly sha256-pinned images.
Also, here the tag has been properly interpolated; otherwise, it would have been
impossible to get the sha256 at all.

#### Notes

[^compose-release]: according to the [release information for @docker/compose
    v2.34.0](https://github.com/docker/compose/releases/tag/v2.34.0).

[^lts]: Debian Docker packages be like: "I'm not overaged! I'm long-term
    stable!!!"

[^dcy]: I'm sticking to `docker-compose.yaml` here for maximum clarity, as
    `compose.yaml` could also be Amadeus' long lost opus (not: octopus) on
    maritime life.

[^probLLMs]: oh, it was a joy to see the totally useless crap vomitted by
    various ProbLLMs when asked about `docker compose publish`. As expected,
    this LLM vomit was neither grounded in the official documentation nor source
    code. Instead, it was very visibly interpolated based on statistics, not
    facts. When asked about the infamous `--app` flag the result was just that
    this is specify the app. Then asking further about what an "app" actually
    is, the hallucinations were much extremer than an infamous Roman Orgy. The
    only less hopeless LLM was Docker's, which admitted defeat saying that the
    documentation doesn't contain information about what an app in this context
    is – but only five prompts later after I had grilled it by pointing out that
    the answers and references given where fully out of context and incorrect,
    not answering my questions. **However you're prompting it, it is that
    stupid.**

[^nsenter]: deploy devcontainer with `"capAdd":["ALL"]`,
    `"runArgs":["--pid=host"]` and `"securityOpt":["apparmor=unconfined"]`, then
    a `sudo nsenter -t 1 -m docker compose ...` runs the VM's docker CLI.
