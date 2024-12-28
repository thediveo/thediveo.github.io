#!/usr/bin/env bash
set -e

DOCSIFY_SERVE_PATH="/usr/local/bin/docsify-serve"

echo "Activating feature 'docsify-cli'..."
npm install -g docsify-cli

tee "$DOCSIFY_SERVE_PATH" > /dev/null \
<< EOF
#!/usr/bin/env sh
nohup bash -c "docsify serve -p=${PORT} -P=${LIVERELOAD_PORT} --no-open ./docs &" >/tmp/nohup.log 2>&1
EOF
chmod 0755 /usr/local/bin/docsify-serve
