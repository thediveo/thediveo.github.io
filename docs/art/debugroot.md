# Debug Go Programs as Root in VSCode

Debugging system tools, such as my
[@thediveo/lxkns](https://github.com/thediveo/lxkns) Linux kernel namespaces
discovery engine, traditionally has been inconvenient at best times because
this type of Go stuff needs to be debugged as _root_.

VSCode as of version 1.65.0 finally got a launch option `"asRoot":
true` that needs to be combined with `"console": "integratedTerminal"`. When
launching such a configuration, a new debug terminal session opens (or might get
reused from last time) and `dlv` is run via `sudo`. You then can authenticate
against `sudo` in the terminal (this does not work in the integrated _console_
but only in either the _integrated terminal_ or an _external interactive
terminal_).

> [!WARNING] Make sure to include your Go bin directory (containing `dlv`) in
> the `secure_path` option in `/etc/sudoers`.

The VSCode go add-on documentation about debugging now has a useful section
dedicated especially to
[debugging programs and tests as root](https://github.com/golang/vscode-go/blob/master/docs/debugging.md#debugging-programs-and-tests-as-root)
with the necessary `.vscode/tasks.json` and `.vscode/launch.json` configuration.
After hitting some problems, I luckily could help iron them (hopefully) out and
sent both small changes as well as additional test-specific configuration examples
upstream, which were gladly accepted.
