---
title: "Docsify DevContainer Feature"
shorttitle: "Docsify DevCntr Feature"
description: "work in DevContainers on your docsified documentation."
---

# Docsify DevContainer Feature

I confess: I'm really late to "[Development
Containers](https://containers.dev/)" (or "devcontainers" for short).

As my first experiment I choose the repository for thediveo.github.io – the very
pages you're reading right now. These basially need just the
[docsify](https://docsify.js.org) on-the-fly document site generator. As I have
added RSS XML support recently, for writing I additionaly need
[yq](https://github.com/mikefarah/yq) and `xmllint`. Unfortunately, `yq` tends
to be in package repositories to be rather very stale, so automatically
installing a binary directly from the project's release page is where
devcontainers thrill at.

However, `xmllint` and `yq` aside that are specific to my particular needs, I
use `docsify` in several projects, both from the company I work for, as well as
in my personal projects.

Thankfully, devcontainers allow for so-called "features" which are
self-contained, shareable units of installation code and devcontainer
configuration.

If you've ever seen that Gitlab ("_lab_", not "hub") CI copy-and-paste total
mess, you'll probably immediately see the benefit of centrally maintained units
– be it for devcontainers or CI workflows.

To reuse this docsify feature, you simply reference it in your
`devcontainer.json`, such as follows:

```json
{
    "features": {
        "ghcr.io/thediveo/devcontainers-features/docsify:0": {
            "port": "3300",
            "livereload-port": "3301",
        }
    }
}
```

At this time, the base image needs to be a moderately recent Ubuntu LTS image,
such as `mcr.microsoft.com/devcontainers/base:ubuntu-24.04`. The `docsify`
feature will automatically reference `ghcr.io/devcontainers/features/node:1`.

See also the [docsify feature
README.md](https://github.com/thediveo/devcontainer-features/blob/master/src/docsify/README.md).
