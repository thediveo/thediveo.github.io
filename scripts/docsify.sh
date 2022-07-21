#!/bin/bash
set -e

# In case the user hasn't set an explicit installation location, avoid polluting
# our own project...
NPMBIN=$(cd $HOME && npm bin)
export PATH="$NPMBIN:$PATH"
if ! command -v docsify-cli &>/dev/null; then
    (cd $HOME && npm install docsify-cli)
fi

docsify serve ./docs
