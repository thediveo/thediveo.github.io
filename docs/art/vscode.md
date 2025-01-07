---
title: "Lost VSCode Ctrl-Click?"
description: "disabling and re-enabling extensions, seriously?"
---

# The Lost VSCode Ctrl-Click

Did you lost your Ctrl-Click in VSCode, so it does not go anywhere now – and
there's also absolutely **no visual feedback** to be seen? Yet F12 is still
working correctly?

Still hoping to find actually working advice on that "_radish_" forum?

Anyway:

- <key>Ctrl</key>+<key>Shift</key>+<key>P</key>, "Preferences: Open User
  Settings (JSON)",
- if present, delete the `"editor.multiCursorModifier": "ctrlCmd"` setting.

## References

- VSCode Basic Editing, [Multi-cursor
  modifier](https://code.visualstudio.com/docs/editor/codebasics#_multicursor-modifier)
