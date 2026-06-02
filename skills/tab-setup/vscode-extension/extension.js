const vscode = require('vscode');
const fs = require('fs');
const path = require('path');
const os = require('os');

const PENDING_FILE = path.join(os.homedir(), '.claude', '.pending-color');
const SESSIONS_DIR = path.join(os.homedir(), '.claude', 'sessions');
const POLL_MS = 500;

function activate(context) {
    // Poll for pending-color file every 500ms.
    // File watcher doesn't reliably fire for paths outside the workspace root,
    // so polling is more robust.
    const timer = setInterval(() => {
        if (fs.existsSync(PENDING_FILE)) {
            applyPending();
        }
    }, POLL_MS);

    context.subscriptions.push({ dispose: () => clearInterval(timer) });
}

async function applyPending() {
    let content;
    try { content = fs.readFileSync(PENDING_FILE, 'utf8').trim(); }
    catch { return; }

    // Delete immediately to prevent double-firing
    try { fs.unlinkSync(PENDING_FILE); } catch { return; }

    const data = {};
    for (const line of content.split('\n')) {
        const eq = line.indexOf('=');
        if (eq > 0) data[line.slice(0, eq).trim()] = line.slice(eq + 1).trim();
    }
    const { session_id, color, name } = data;
    if (!color) return;

    // Wait until the Claude session is idle before sending commands
    await waitForIdle(session_id);

    const terminal = vscode.window.activeTerminal;
    if (!terminal) return;

    // Set terminal tab overhead color via VS Code command (same as right-click → Change Color)
    try {
        await vscode.commands.executeCommand('workbench.action.terminal.changeColor', {
            terminal,
            color: { id: `terminal.ansi${color.charAt(0).toUpperCase()}${color.slice(1)}` }
        });
    } catch {}

    terminal.sendText(`/color ${color}`);
    if (name) {
        await sleep(400);
        terminal.sendText(`/rename ${name}`);
    }
}

async function waitForIdle(sessionId, timeoutMs = 30000) {
    const start = Date.now();
    while (Date.now() - start < timeoutMs) {
        try {
            const files = fs.readdirSync(SESSIONS_DIR).filter(f => f.endsWith('.json'));
            const session = files
                .map(f => { try { return JSON.parse(fs.readFileSync(path.join(SESSIONS_DIR, f))); } catch { return null; } })
                .find(d => d && (!sessionId || d.sessionId === sessionId));
            if (!session || session.status !== 'busy') return;
        } catch {}
        await sleep(250);
    }
}

const sleep = ms => new Promise(r => setTimeout(r, ms));

function deactivate() {}
module.exports = { activate, deactivate };
