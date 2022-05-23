# Debug Go Programs as Root in VSCode

Debugging system tools, such as my
[@thediveo/lxkns](https://github.com/thediveo/lxkns) Linux kernel namespaces
discovery engine, traditionally has been hampered because this type of Go stuff
needs to be debugged as root.

VSCode as of version 1.65.0 finally got an experimental launch option `"asRoot":
true` that needs to be combined with `"console": "integratedTerminal"`. When
launching such a configuration, a new debug terminal session opens (or might get
reused from last time) and `dlv` is run via `sudo`. You then can authenticate
against `sudo` in the terminal (this does not work in the integrated _console_
but only in either the _integrated terminal_ or an _external interactive
terminal_).

> [!WARNING] Make sure to include your Go bin directory (containing `dlv`) in
> the `secure_path` option in `/etc/sudoers`.

The documentation of VSCode's Go extension notes that in order to avoid
compiling the code as root in order to debug it as root, it's better to first
define a _build task_ and then run this build task before the launch
configuration. Unfortunately, the documentation seems to need some good
debugging too...

## Test Binary Build Task

First, create a new file `.vscode/tasks.json` or add the following build task
definition inside the `tasks` array to it, if you already have one:

```json
{
    // See https://go.microsoft.com/fwlink/?LinkId=733558
    // for the documentation about the tasks.json format
    "version": "2.0.0",
    "tasks": [
        {
            "label": "go build (debug)",
            "type": "shell",
            "command": "go",
            "args": [
                "test",
                "-c",
                "-o",
                "${fileDirname}/__debug_bin"
            ],
            "options": {
                "cwd": "${fileDirname}",
                "env": {
                    "PATH": "${env:PATH}:/snap/bin"
                }
            },
            "problemMatcher": [],
            "group": {
                "kind": "build",
                "isDefault": true
            }
        }
    ]
}
```

This task builds a test binary `__debug_bin` in the directory of the currently
viewed package source code and test code.

## Launch Configuration

Second, create a new `.vscode/launch.json` or add the following launch
configuration to it, if you already have the file:

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Debug test as root",
            "type": "go",
            "request": "launch",
            "mode": "exec",
            "asRoot": true,
            "program": "${fileDirname}/__debug_bin",
            "cwd": "${fileDirname}",
            "console": "integratedTerminal",
            "preLaunchTask": "go build (debug)",
            "env": {
                "PATH": "${env:PATH}:/snap/bin"
            }
        }
    ]
}
```

Please note that trying to put the launch configuration into the workspace
configuration file seems to cause failures to find the correct build tasks.

## Usage

Open a (tests) source code file of the package where you want to debug its
tests. Then press F5. The test binary should be build now, then you should be
asked by sudo in an integrated terminal for your credentials, and finally the
debugger should correctly come up. And stop at a breakpoint you set before
pressing F5. You set a breakpoint, right...?
