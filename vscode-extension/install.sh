#!/usr/bin/env bash
# Install the claude-tab extension to the Cursor (or VS Code) server.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect server type
if [ -d "$HOME/.cursor-server" ]; then
    DEST="$HOME/.cursor-server/extensions/claude-tab-0.0.1"
    SERVER="Cursor"
elif [ -d "$HOME/.vscode-server" ]; then
    DEST="$HOME/.vscode-server/extensions/claude-tab-0.0.1"
    SERVER="VS Code"
else
    echo "Error: neither ~/.cursor-server nor ~/.vscode-server found."
    exit 1
fi

mkdir -p "$DEST"
cp "$SCRIPT_DIR/extension.js" "$DEST/"
cp "$SCRIPT_DIR/package.json" "$DEST/"

echo "Installed claude-tab extension to $DEST ($SERVER)"
echo ""
echo "Reload the remote window to activate:"
echo "  Ctrl+Shift+P → 'Developer: Reload Window'"
