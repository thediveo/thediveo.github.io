#!/usr/bin/env bash

# This installs the missing tools needed by scripts/feed.sh. As Ubuntu currently
# ships with a completely outdated yq package, we fetch the yq binary directly
# from its Github releases.

set -e

echo "installing required packages..."
apt-get update && apt-get install -y libxml2-utils 

echo "determining CPU architecture..."
CPU_ARCH=$(uname -m)
case $CPU_ARCH in
    "x86_64") CPU_ARCH="amd64";;
    "aarch64" | "arm64") CPU_ARCH="arm64";;
    *) echo "Unsupported CPU architecture: $CPU_ARCH"; exit 1;;
esac
echo "CPU architecture: ${CPU_ARCH}"

echo "fetching latest 'yq' binary for Linux ${CPU_ARCH}..."
YQ_LATEST_BINARY_URL=$(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest | grep "browser_download_url.*linux_${CPU_ARCH}\"" | cut -d '"' -f 4)
YQ_FILENAME=${YQ_LATEST_BINARY_URL##*/}
curl -Lo "/tmp/$YQ_FILENAME" "$YQ_LATEST_BINARY_URL"
echo "installing 'yq' binary..."
mv "/tmp/$YQ_FILENAME" /usr/bin/yq
chown root:root /usr/bin/yq
chmod 0755 /usr/bin/yq

echo "cleaning up..."
rm -rf /var/lib/apt/lists/*
