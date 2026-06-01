#!/usr/bin/env bash
# Install the claude-tab extension to the appropriate server extension directory.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect server type — prefer code-server (local share), then cursor, then vscode
if [ -d "$HOME/.local/share/code-server/extensions" ]; then
    EXT_ROOT="$HOME/.local/share/code-server/extensions"
    SERVER="code-server"
elif [ -d "$HOME/.cursor-server" ]; then
    EXT_ROOT="$HOME/.cursor-server/extensions"
    SERVER="Cursor"
elif [ -d "$HOME/.vscode-server" ]; then
    EXT_ROOT="$HOME/.vscode-server/extensions"
    SERVER="VS Code"
else
    echo "Error: no supported server extension directory found."
    exit 1
fi

DEST="$EXT_ROOT/claude-tab-0.0.1"
mkdir -p "$DEST"
cp "$SCRIPT_DIR/extension.js" "$DEST/"
cp "$SCRIPT_DIR/package.json" "$DEST/"

# Register in extensions.json with the same format the server uses
python3 - "$EXT_ROOT" "$DEST" <<'PYEOF'
import json, sys, os, time

ext_root, dest = sys.argv[1], sys.argv[2]
index_file = os.path.join(ext_root, "extensions.json")

try:
    entries = json.load(open(index_file))
except Exception:
    entries = []

# Remove any existing claude-tab entry
entries = [e for e in entries if e.get("identifier", {}).get("id", "") != "dgilford.claude-tab"]

entries.append({
    "identifier": {"id": "dgilford.claude-tab"},
    "version": "0.0.1",
    "location": {
        "$mid": 1,
        "fsPath": dest,
        "external": f"file://{dest}",
        "path": dest,
        "scheme": "file"
    },
    "relativeLocation": "claude-tab-0.0.1",
    "metadata": {
        "isApplicationScoped": False,
        "isMachineScoped": False,
        "isBuiltin": False,
        "installedTimestamp": int(time.time() * 1000),
        "pinned": False,
        "source": "gallery"
    }
})

with open(index_file, "w") as f:
    json.dump(entries, f, indent=2)

print(f"Registered in {index_file}")
PYEOF

echo "Installed claude-tab extension ($SERVER) → $DEST"
echo ""
echo "Reload the window to activate:"
echo "  Ctrl+Shift+P → 'Developer: Reload Window'"
