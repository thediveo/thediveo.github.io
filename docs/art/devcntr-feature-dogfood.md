---
title: "DevContainer Features in DevContainers"
shorttitle: "DevContainer Features in DevContainers"
description: "it's only consequential to develop DevContainer features in a DevContainer."
---

# Developing DevContainer Features in DevContainers

Yes, works also for my use cases where some features use Docker-in-Docker, so
I've put Docker-in-Docker in my feature development DevContainer...

```json
{
    "name": "TheDiveO's devcontainer features",
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu-24.04",
    "features": {
        "ghcr.io/devcontainers/features/node:1": {},
        "ghcr.io/devcontainers/features/docker-in-docker:2": {
            "version": "latest",
            "moby": false // go for the upstream Docker-CE
        },
        "ghcr.io/thediveo/devcontainer-features/pull-through-cache-registry:0": {
            "port": "9999"
        }
    },
    "postCreateCommand": "npm install -g @devcontainers/cli",
    "customizations": {
        "vscode": {
            "extensions": [
                "mads-hartmann.bash-ide-vscode"
            ]
        }
    }
}
```
