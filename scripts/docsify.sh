#!/bin/bash
set -e

# In case the user hasn't set an explicit installation location, avoid polluting
# our own project...
NPMBIN=$(cd $HOME && npm root)/.bin
export PATH="$NPMBIN:$PATH"
if ! command -v docsify-cli &>/dev/null; then
    (cd $HOME && npm install docsify-cli)
fi

docsify serve -p 3300 -P 3301 ./docs
