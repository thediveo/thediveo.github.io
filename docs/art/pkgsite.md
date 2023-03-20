# ~~godoc~~ ⇢ pkgsite

Coming as a rather nasty surprise to those Go developers that actually write,
maintain and rely on useable Go module documentation: [godoc is
deprecated](https://github.com/golang/go/issues/49212).

Or, in the best of "Marie Gontoinette" mentality: let 'em eat `pkgsite`!

In case you expect `pkgsite` to be a polished drop-in to `godoc`, you're in for
a nasty surprise and might want to see to the Marie Gontoinette drama dragging
along in [issue #40371: x/pkgsite: local setup – tracking
issue](https://github.com/golang/go/issues/40371).

Thankfully, milan[at]mdaverde.com comes to the rescue: Milan's [Previewing the
HTML of your go docs from
localhost](https://mdaverde.com/posts/golang-local-docs/) paves the way and
explains all the necessary pieces.

## Local pkgsite with Hot Reload

Now, instead of (mis)typing in all those hard-to-remember CLi commands over and
over again, let's wrap everything into a nice shell script. In addition, install
the required Go and npm modules automatically, if they're not already present
and in the user's `PATH`.

Create `pkgsite.sh` in your workspace directory:

```bash
#!/bin/bash
# pkgsite.sh
set -e

if ! command -v pkgsite &>/dev/null; then
    export PATH="$(go env GOPATH)/bin:$PATH"
    if ! command -v pkgsite &>/dev/null; then
        go install golang.org/x/pkgsite/cmd/pkgsite@master
    fi
fi

# In case the user hasn't set an explicit installation location,
# avoid polluting our own project...
NPMBIN=$(cd $HOME && npm root)/.bin
export PATH="$NPMBIN:$PATH"
if ! command -v browser-sync &>/dev/null; then
    (cd $HOME && npm install browser-sync)
fi

if ! command -v nodemon &>/dev/null; then
    (cd $HOME && npm install nodemon)
fi

# https://stackoverflow.com/a/2173421
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

# https://mdaverde.com/posts/golang-local-docs
browser-sync start --port 6060 --proxy localhost:6061 \
    --reload-delay 2000 --reload-debounce 5000 \
    --no-ui --no-open &
PKGSITE=$(which pkgsite)
nodemon --signal SIGTERM --watch './**/*' -e go \
    --exec "browser-sync --port 6060 reload && $PKGSITE -http=localhost:6061 ."
```

In my experience, adding `--reload-delay` and `--reload-debounce` settings
improves the overall user experience and especially makes the initial page
display more reliable.

## VSCode Tasks

Let's go one step further: run `pkgsite` as an admittedly rather long-running
task and instead of opening the documentation in a separate browser, use
VSCode's own "Simple Browser" (yes, that's what Microsoft calls it).

First, create a `.vscode/tasks.json`, or extend your existing one, adjusting the
URL to open in the `"args"` field at the bottom to the import path of your own
package:

```json
{
    // See https://go.microsoft.com/fwlink/?LinkId=733558
    // for the documentation about the tasks.json format
    "version": "2.0.0",
    "tasks": [
        {
            // use "Tasks: Run Task" on this task.
            "label": "view Go module documentation",
            "dependsOrder": "parallel",
            "dependsOn": [
                "don't Run Task this! -- pkgsite service",
                "don't Run Task this! -- view pkgsite"
            ],
            "problemMatcher": []
        },
        {
            // do NOT Run Task this!
            "label": "don't Run Task this! -- view pkgsite",
            "command": "${input:pkgsite}",
        },
        {
            // do NOT Run Task this!
            "label": "don't Run Task this! -- pkgsite service",
            "type": "shell",
            "command": "${workspaceFolder}/pkgsite.sh",
            "presentation": {
                "echo": true,
                "reveal": "always",
                "focus": false,
                "panel": "shared",
                "showReuseMessage": false,
                "close": true,
            }
        },
    ],
    "inputs": [
        {
            "id": "pkgsite",
            "type": "command",
            "command": "simpleBrowser.api.open",
            "args": "http://localhost:6060/github.com/thediveo/go-plugger/v2"
        }
    ]
}
```

Then, view the package documentation from a locally running pkgsite, open the
command palette in VSCode and select "**Tasks: Run Task**". Select "**view Go
module documentation**". Then wait for `pkgsite` to spin up and the new "Simple
Browser" to render the pkgsite.

Press Ctrl-C in the pkgsite task terminal to terminate pkgsite and close the
terminal.

Please note that `pkgsite` in this local setup does not support searching, just
viewing package documentation when you know the correct import path.

Do **not** run any of the "don't Run Task this! -- view pkgsite" and "don't Run
Task this! -- pkgsite service" tasks directly, as they are internal tasks and
VSCode unfortunately does not support hiding "internal" tasks.
