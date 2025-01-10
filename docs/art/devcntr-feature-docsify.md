---
title: "A Docsify DevContainer Feature"
shorttitle: "A Docsify Dev📦 Feature"
description: "work in DevContainers on your docsified documentation."
---

# A Docsify DevContainer Feature

I must confess: I'm _really late_ to "[Development
Containers](https://containers.dev/)" (or "devcontainers" for short).

As my first experiment I choose the repository for thediveo.github.io – the very
pages you're reading right now. These pages basially need just the
[docsify](https://docsify.js.org) on-the-fly document site generator. As I use
docsify for no-thrills documentation site of other projects, such as
[Edgeshark](https://edgeshark.siemens.io) and
[lxkns](https://thediveo.github.io/lxkns) reuse is a thing for me, so let's do a
[devcontainer
feature](https://code.visualstudio.com/blogs/2022/09/15/dev-container-features).

If you've ever seen how Gitlab ("_lab_", not "hub") made a total mess with its
copy-and-paste CI, you'll probably immediately see the benefit of centrally
well-maintained units – be it for devcontainers or CI workflows.

## Reusing the Feature

To reuse my docsify feature, you simply reference it in your
`devcontainer.json`, such as follows:

```json
{
    "features": {
        "ghcr.io/thediveo/devcontainers-features/docsify:0": {
            "port": "3300",            // default, just for documentation
            "livereload-port": "3301", // default, just for documentation
        }
    }
}
```

At this time, the base image needs to be a moderately recent Ubuntu LTS image,
such as `mcr.microsoft.com/devcontainers/base:ubuntu-24.04`. The `docsify`
feature will automatically reference `ghcr.io/devcontainers/features/node:1`.

See also the [docsify feature
README.md](https://github.com/thediveo/devcontainer-features/blob/master/src/docsify/README.md).

## Beyond the Feature: RSS XML Generation

Recently, I added RSS XML support to my docsify site and I rely on
[yq](https://github.com/mikefarah/yq) and `xmllint` to generate the RSS XML from
the documents and their YAML front matter (if any).

Now, this doesn't look like a general feature, so I'm keeping this part of the
devcontainer itself and not a feature.

Now, `yq` from the big Linux distro package repositories tend to be very
flea-bitten, so the only way forward here is to automatically install `yq`
directly from the project's own release page. And that's exactly the kind of
situation devcontainers thrive on.

So, in my site's `devcontainer.json` I declare not only to use the `docsify` feature, but additionally a `Dockerfile`:

```json
{
    "build":{
      "dockerfile": "Dockerfile"  
    }, 
}
```

Now, my `Dockerfile` pulls off a trick of its sleeve in order to avoid my
installation script ending up in the final devcontainer: it leverages the
ability of the `RUN` command to temporarily bind-mount files and directories
belonging to another image into the current layer just for the duration of the
`RUN`...

```dockerfile
FROM scratch as installer
COPY ./install.sh /tmp/install.sh

FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04 as final
RUN --mount=type=bind,from=installer,source=/tmp/install.sh,target=/tmp/install.sh \
    /tmp/install.sh
```

As a bind-mount is not a copy operation, the script is just made visible but not
added to the current layer.
