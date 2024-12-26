# As we don't want to have the installation script "install.sh" for building the
# devcontainer image in an intermediate layer still present, we copy it into its
# own minimalist image. This works around the limitation that we cannot execute
# the script without copying it from the context first: instead, we later
# bind-mount the installer script from this installer image just for the
# duration of running the installer script...
FROM scratch as installer
COPY ./install.sh /tmp/install.sh

# https://github.com/devcontainers/images/tree/main/src/base-ubuntu
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04 as final
# Bind-mount the installer script just for the time it runs into this build
# stage, so that it itself will be automatically removed without any traces
# after it has done its work, installing missing software.
RUN --mount=type=bind,from=installer,source=/tmp/install.sh,target=/tmp/install.sh \
    /tmp/install.sh
