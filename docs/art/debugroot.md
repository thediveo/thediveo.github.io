# Debug Go Programs as Root in VSCode

Debugging system tools, such as my
[@thediveo/lxkns](https://github.com/thediveo/lxkns) Linux kernel namespaces
discovery engine, traditionally has been hampered because this type of Go stuff
needs to be debugged as root.

VSCode as of version 1.65.0 finally got an experimental launch option `"asRoot":
true` that needs to be combined with `"console": "integratedTerminal"`. When
launching the following configuration by pressing F5, a new debug terminal
session opens (or might get reused from last time) and `dlv` is run via `sudo`.
You then can authenticate against `sudo` in the terminal (this does not work in
the integrated _console_ but only in either the _integrated terminal_ or an
_external interactive terminal_).

> [!WARNING] Make sure to include your Go bin directory (containing `dlv`) in
> the `secure_path` option in `/etc/sudoers`.

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Test/dbg pkg as root",
            "type": "go",
            "request": "launch",
            "mode": "test",
            "program": "${fileDirname}",
            "console": "integratedTerminal",
            "asRoot": true,
    	},
    ]
}
```
