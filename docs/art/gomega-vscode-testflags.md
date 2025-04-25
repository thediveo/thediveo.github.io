---
title: "Ginkgo Colorization and VSCode go.testFlags"
shorttitle: "Ginkgo: go.testFlags"
description: "running and debugging colorized Ginkgo Go tests"
---

# Ginkgo and VSCode `go.testFlags`

The [Ginkgo modern testing framework for Go](https://github.com/onsi/ginkgo)
defaults to colorizing its output. The different colors for passed versus failed
or skipped tests aid in quickly spotting problems – at least if you are able to
discern the colors used.

While VSCode's "Debug Console" correctly renders Ginkgo's colorized output when
_debugging_ package tests, the "Output" pane used when _running_ package tests
does not interpret terminal escape sequences such as used for colorization.
Requests to fix this seemingly odd limitation of VSCode Output panes have been
opened over time several times: the "original" [microsoft/vscode
issue&nbsp;#571](https://github.com/microsoft/vscode/issues/571) was created
back in November 2015 and four years later closed without any fix, in October
2019, by the `vscodebot`.

## `go.testFlags`

Simply setting `go.testFlags` to `["--ginkgo.no-color"]` has the problem that it
breaks debugging tests. The reason is that `--ginkgo.no-color` unconditionally
gets passed to the test _build_ command, yet the Go toolchain doesn't understand
this flag.

There's actually a probably lesser known and often overlooked feature in
`go.testFlags` to work around such issues: `-args` as mentioned in
[golang/vscode-go
issue&nbsp;#2994](https://github.com/golang/vscode-go/issues/2994#issuecomment-1748893664). 

> [!QUOTE]
>
> `-args` test flag indicate the subsequent flag elements are application's
> flag. VS Code extension looks for this marker flag and uses it to distinguish
> the build/test flags and the user's application flags.

```json
// myproject.code-workspace
{
	"settings": {
		"go.testFlags": [
			"-v",
			"-args", // https://github.com/golang/vscode-go/issues/2994
			"--ginkgo.no-color"
		]
	}
}
```

This works ... yet feels somehow whacky, more so as the official Wiki page about
the available settings for the VSCode Go extension **doesn't** mention `-args`
in its rather Hitchhiker-like description of
[`go.testFlags`](https://github.com/golang/vscode-go/wiki/settings#gotestflags)
at all.

## Launch Configurations

While searching for solutions to this problem, the topic of [debug launch
configurations](https://code.visualstudio.com/docs/debugtest/debugging-configuration#_launch-configurations)
pops up in multiple places. For Go, this includes the [`launch.json`
attributes](https://github.com/golang/vscode-go/blob/master/docs/debugging.md#launchjson-attributes)
which are also configurable via `.code-workspace` files, using the `launch`
object.

Without further ado, here's how to set up separate package test and debug
package tests launch configurations:

```json
// myproject.code-workspace
{
	"launch": {
		"version": "0.2.0",
		"configurations": [
			{
				"name": "Test Package",
				"type": "go",
				"request": "launch",
				"mode": "test",
				"program": "${fileDirname}",
				"args": ["--ginkgo.no-color"],
				"buildFlags": ["-v"]
			},	
			{
				"name": "Debug Package Test",
				"type": "go",
				"request": "launch",
				"mode": "debug",
				"program": "${fileDirname}",
			}
		]
	}
}
```

This is pretty much stock configuration, but the important aspect here is to
**not** use `"mode":"auto"`. Instead we use separate launch configurations for
`"mode":"test"` and `"mode":"debug"`. Admittedly, I still find it confusing that
the Go extension for `"mode":"debug"` "somehow" decides whether to debugging a
(main) program or instead to debug a test binary.

When testing a package which sends its output to the Output pane, we don't want
Ginkgo to colorize the output because the pane then will mess up. We thus use
`args` in the "Test Package" launch configuration to stop Ginkgo from emitting
any terminal escape sequences. `args` are passed only to the _test binary_, but
not to the Go toolchain when _building_ the test binary (for that, use
`buildFlags` instead).
