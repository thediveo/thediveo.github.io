---
title: "🐋 Hub Cache DevContainer Feature"
shorttitle: "🐋 Hub Cache Dev📦 Feature"
description: "a CNCF Distribution Registry as pull-through cache inside your DevContainer to play well with the Docker Hub pull rate limit."
---

# CNCF Distribution Registry as Pull-Through Cache

Most of the time, the Docker engine's image caching should avoid running into
[Docker Hub's pull rate limitation](https://docs.docker.com/docker-hub/usage/),
especially when working with containers in unit tests. However, there are
situations where image caching can't really kick in: upstream image pull tests
and unit tests that run non-Docker container engines inside Docker containers.

[@siemens/turtlewatcher](https://github.com/siemens/turtlewatcher) and
[@thediveo/whalewatcher](https://github.com/thediveo/whalewatcher) are two such
examples. In the unit tests of these projects, podman gets deployed inside a
base image container in order to shield the host or the hosting devcontainer
from the unfortunately shoddy work of distribution packagers where installing
podman packages destroys the existing Docker installation (with not least Debian
as case in point). These tests also deploy `containerd` and `cri-o` engines with
the k8s CRI API enabled. As these container engine instances are ephemeral
running any canary workload on them causes fresh image pulls on each test run,
and even on each test in some situations.

So, operating a local OCI registry as a transparent mirror/cache for Docker Hub
(or, fwiw, any other public or private OCI image registry) becomes necessary.
The beauty of a DevContainer feature is that we can leave the host's Docker
setup untouched, as well as we can easily replicate and reuse a transparent
mirror/cache setup in multiple projects and with multiple developers.

Looking around I could not find such a DevContainer feature already existing
(surely not the most pressing DevContainer feature to most devs), so I wrote one
myself. This is fortunately quite straightforward thanks to the [CNCF
Distribution Registry](https://distribution.github.io/distribution/) and
especially their ["Registry as a pull through cache"
recipe](https://distribution.github.io/distribution/recipes/mirror/)[^cache-mirror].

This new `pull-through-cache-registry` DevContainer feature...

- deploys `registry:3` with some overridden settings, such as logging only info
  or above, and a configurable upstream registry URL, defaulting to
  `https://registry-1.docker.io`.

- configures the Docker demon _inside the DevContainer_ to use the
  DevContainer-local registry service as its registry mirror.

> [!IMPORTANT] This feature only supports and strictly depends on the
  [Docker-in-Docker](https://github.com/devcontainers/features/tree/main/src/docker-in-docker)
  feature.

Please see [pull-through-cache-registry feature
README.md](https://github.com/thediveo/devcontainer-features/blob/master/src/pull-through-cache-registry/README.md)
for more details.

As usual, this DevContainer feature has tests to ensure it works as intended.

#### Notes

[^cache-mirror]: judging from the recipe's URL and title even the CNCF is
    confused as to the canonical terminology: is it a "mirror"? It it a
    "pull-through cache"? Is the CNCF short on dashes?
