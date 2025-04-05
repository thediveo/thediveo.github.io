---
title: "eBPF DevContainer Features"
shorttitle: "eBPF Dev📦 Features"
description: "devcontainer features to help with eBPF."
---

# eBPF DevContainer Features

To improve my own quality of coding life I've done two
[eBPF](https://docs.ebpf.io/)-related devcontainer features that might be also
of interest to other eBPF afficionados.

The
[go-ebpf](https://github.com/thediveo/devcontainer-features/blob/master/src/go-ebpf/README.md)
devcontainer feature focuses on developing Go applications that make use of
eBPF. It installs clang and llvm, and then also Cilium's `bpf2go` tool that I
use to compile eBPF and generate matching Go source code to work with the eBPF
programs.

The
[bpftool](https://github.com/thediveo/devcontainer-features/blob/master/src/bpftool/README.md)
devcontainer feature was born out of the pain of being a Debian/Ubuntu user.
However, this feature is not restricted to Debian/Ubuntu-based devcontainers,
but works also with other distributions, namely the ~~Blue~~RedHat-derived ones.
On Debian/Ubuntu, installing from the official distro packages require to
install kernel-specific packages and huge pain tolerance, whereas other
distributions don't make such a fuss. But as distro packagers struggle massively
with correctly packaging fast evolving technology anyway, this feature simply
installs directly from [bpftool upstream](https://github.com/libbpf/bpftool):
thankfully, the bpftool repository provides binaries for the amd64 and arm64
architectures. This feature detects the CPU architecture and then downloads and
installs the correct binary.
