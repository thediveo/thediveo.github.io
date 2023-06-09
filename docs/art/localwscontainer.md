# Go Workspaces in Container Builds

_...and now for something completely different_: may I please have my local [Go
workspace](https://go.dev/blog/get-familiar-with-workspaces) in my container
image build stage when building _locally_?

And no vendoring, please?

Oh, and of course, the build stage should still work as before in a CI(/CD)
pipeline, without the need to maintain separate `Dockerfile`s.

🤯

Yes, it should go without saying that taking one's local workspace into a build
stage is exactly the opposite of reproducible CI/CD. Thus, the idea and its
solution presented here is intended for building _locally outside_ any CI/CD
pipeline for "local consumption" only. That is, for rapid turn-arounds while
prototyping and debugging slightly difficult code. Yet, the same `Dockerfile`
should still work correctly inside a CI/CD, but then with only a fake Go
workspace consisting only of your module, and nothing else, so we keep the CI/CD
reproducible.

This solution was developed in order to work on my
[lxkns](https://github.com/thediveo/lxkns) namespaces and container discovery
service. It allows me to simultaneously work on upstream modules required by
lxkns, while being able to test everything inside a container.

## Go Workspace Discovery

> [!NOTE] The following assumes that the shell code is executed with the current
> working directory set to the root directory of the "main" module where we want
> to build a binary (or binaries) from.

The first task to solve is to detect if the Go module used in the build is
currently part of a Go workspace or not. Fortunately, that's easy – albeit `go
work edit ...` is kind of a misnomer in this case:

```bash
workspace_details=$(go work edit --json)
```

This will return either an exit code of 1 (and an error message on stderr) if
we're not inside a workspace or otherwise some JSON describing the workspace
configuration, such as:

```json
{
    "Go": "1.20",
    "Use": [
        {
            "DiskPath": "./lxkns"
        }
    ],
    "Replace": null
}
```

When **not** inside a workspace, we'll simply take the current module anyway.
But when we're **inside a workspace**, extracting the disk paths of the modules
currently in use simply conjures up some `jq` magic.

```bash
MAINUSE=./lxkns # <-- adapt this to reflect the "main" module

contexts=()
if [[ ${workspace_details} ]]; then
    goworkdir=$(dirname $(go env GOWORK))
    diskpaths=$(echo ${workspace_details} | jq --raw-output '.Use | .[]? | .DiskPath')
    while IFS= read -r module; do
        if [[ "${module}" != "${MAINUSE}" ]]; then
            relcontext=$(realpath --relative-to="." ${goworkdir}/${module})
            contexts+=( ${relcontext} )
        fi
    done <<< ${diskpaths}
else
    diskpaths="${MAINUSE}"
fi
```

We end up with the `contexts` array containing the paths _relative_ to our
current main module directory to the other currently used modules. 

## Docker Build Contexts

A [Docker build context](https://docs.docker.com/build/building/context/) is a
set of files located in a path (or URL) specified as an argument to the `docker
build` command. An obvious idea now might be to simply pass the workspace folder
as the build context – but this might easily blow into your face as then any
`.dockerignore` file must be in the workspace root. Any exclusion of, say, a
`node_modules` iceberg would get ignored. And maintaining a workspace-specific
`.dockerignore` is beside the point.

Fortunately, Docker since around May 2022 finally supports [multiple build
contexts](https://www.docker.com/blog/dockerfiles-now-support-multiple-build-contexts/):
so we can use a separate build context for each module actively used in the
workspace.

In the following, we will use the "main" build context as before for the "main"
module with its application to be build. The shell code references to it in its
`MAINUSE` variable.

So let's create a set of `docker build` arguments that specify the additional
build contexts we'll use, depending on the workspace configuration. Please
ignore the additional `build-args` for the moment, we'll come to them in a
moment.

```bash
buildctxargs=()
buildargs=()
ctxno=1
for ctx in "${contexts[@]}"; do
    buildctxargs+=( "--build-context=bctx${ctxno}=${ctx}" )
    buildargs+=( "--build-arg=MOD${ctxno}=./$(basename ./${ctx})/" )
    ((ctxno=ctxno+1))
done
```

In our `Dockerfile`, inside the appropriate build stage, we then simply copy
everything (subject to the particular context's `.dockerignore`) into our build
stage.

```dockerfile
FROM golang:${GO_VERSION}-alpine${ALPINE_VERSION} AS builder

ARG MOD1=./
ARG MOD2=./
ARG MOD3=./

WORKDIR /ws
# Copy the additionally used modules into the soon-to-be workspace.
COPY --from=bctx1 . ${MOD1}
COPY --from=bctx2 . ${MOD2}
COPY --from=bctx3 . ${MOD3}
# ...and so on, and on, and on...
COPY --from=bctx9 . ${MOD9}
```

As you might already suspect from this part of the `Dockerfile`, there isn't
much flexibility in Dockerfiles. `COPY` doesn't take kindly to being presented
an unset context. So we need to plan for the maximum amount of workspace modules
in use we want to support simultaneously and then fill the unused "slots".

```bash
NUMCONTEXTS=9

for ((;ctxno<=NUMCONTEXTS;ctxno++)); do
    buildctxargs+=( "--build-context=bctx${ctxno}=${EMPTYCONTEXT}" )
done
```

## Establishing the Go Workspace

At this point in the `Dockerfile` we've created a `/ws/` directory and copied
those module directories into it that are currently _in use_ in the host's main
build context workspace. But we didn't copy over our main module's sources yet.

For the following to work correctly, we need to pass the `WSDISKPATHS` as...

```
--build-arg=WSDISKPATHS="$(echo ${diskpaths})"
```

...which is the list of _used_ module directories inside the workspace
(including the directory for our main module).

```dockerfile
# ...we're still in /ws at this point.

# Make sure we have the main module containing a main package to be build...
COPY go.mod go.sum ./lxkns/

# Establish the Go workspace
RUN go work init ${WSDISKPATHS}

WORKDIR /ws/lxkns
# We now try to cache only the dependencies in a separate layer, so we can speed
# up things in case the dependencies do not change. This then reduces the amount
# of fetching and compiling required when compiling the final binary later.
RUN go mod download -x

# ...
```

And that's it. Existing `Dockerfile`s can quickly be upgraded. The main
difference is that there's now a workspace directory "above" the main module's
sources. Normally, this should rarely, if ever, affect existing Dockerfiles.

## docker-build.sh

To tie up the loose ends, instead of invoking `docker build` (or `docker buildx
build`) directly, wrap it into invoking `docker-build.sh` instead. The first arg
now must be the path of the Dockerfile (without any preceeding `-f`) and all
following args will be passed on to `docker buildx build`.

```bash
#!/bin/bash

dockerfile="$1"
args="${@:2}"

MAINUSE=./lxkns # <-- adapt this to reflect the "main" module
EMPTYCONTEXT=.emptyctx
NUMCONTEXTS=9

# find out if we are in workspace mode -- and it we are, then the list of
# modules actually used.
mkdir -p ${EMPTYCONTEXT}
trap 'rm -rf -- "${EMPTYCONTEXT}"' EXIT

contexts=()
workspace_details=$(go work edit --json)
if [[ ${workspace_details} ]]; then
    goworkdir=$(dirname $(go env GOWORK))
    echo "found workspace" ${goworkdir}
    diskpaths=$(echo ${workspace_details} | jq --raw-output '.Use | .[]? | .DiskPath')
    echo "modules used in workspace:" ${diskpaths}
    while IFS= read -r module; do
        if [[ "${module}" == "${MAINUSE}" ]]; then
            echo "  🏠" ${module};
        else
            relcontext=$(realpath --relative-to="." ${goworkdir}/${module})
            contexts+=( ${relcontext} )
            echo "  🧩" ${module} "» 📁" ${relcontext}
        fi
    done <<< ${diskpaths}
else
    diskpaths="${MAINUSE}"
fi

buildctxargs=()
buildargs=()
ctxno=1
for ctx in "${contexts[@]}"; do
    buildctxargs+=( "--build-context=bctx${ctxno}=${ctx}" )
    buildargs+=( "--build-arg=MOD${ctxno}=./$(basename ./${ctx})/" )
    ((ctxno=ctxno+1))
done
for ((;ctxno<=NUMCONTEXTS;ctxno++)); do
    buildctxargs+=( "--build-context=bctx${ctxno}=${EMPTYCONTEXT}" )
done
echo "args:" ${buildctxargs[*]} ${buildargs[*]}
echo "build inside:" ${CWD}

docker buildx build \
    -f ${dockerfile} \
    ${buildargs[@]} \
    ${buildctxargs[@]} \
    --build-arg=WSDISKPATHS="$(echo ${diskpaths})" \
    ${args} \
    .
```

That's all. Happy Go "Workspacing" in your Dockerfiles!
