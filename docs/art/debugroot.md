---
title: "Debug Go Programs as Root in VSCode"
description: "the Go extension's documentation needs some debugging, too."
---

# Debug Go Programs as Root in VSCode

Debugging _system tools_, such as my
[@thediveo/lxkns](https://github.com/thediveo/lxkns) Linux kernel namespaces
discovery engine, traditionally has been inconvenient at best times: because
this kind of Go code needs to be debugged as _root_.

[VSCode](https://code.visualstudio.com/) (including [VSCode in the
browser](https://github.com/coder/code-server), ...) as of version 1.65.0
finally got a launch option `"asRoot": true` that needs to be combined with
`"console": "integratedTerminal"`. When launching such a configuration, a new
debug terminal session opens (or might get reused from last time) and `dlv` is
run via `sudo`. You then can authenticate against `sudo` in the terminal.

> [!NOTE] This works only in either the _integrated terminal_ or an _external
> interactive terminal_, but not in the integrated _console_).

> [!WARNING] Make sure to include the Go binaries `bin` directory that contains
> `dlv` in the `secure_path` option in `/etc/sudoers`.

The documentation of VSCode's go add-on about debugging now has a useful section
dedicated especially to [debugging programs and tests as
root](https://github.com/golang/vscode-go/blob/master/docs/debugging.md#debugging-programs-and-tests-as-root),
including the necessary `.vscode/tasks.json` and `.vscode/launch.json`
configurations.

After hitting some initial problems with an early version of the documentation,
I luckily could help iron them (hopefully) out and sent both small changes as
well as additional test-specific configuration examples upstream, which were
gladly accepted.
