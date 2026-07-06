const vscode = require('vscode');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { readSessionFile } = require('./lib/session-status');

const PENDING_FILE = path.join(os.homedir(), '.claude', '.pending-color');
const SESSIONS_DIR = path.join(os.homedir(), '.claude', 'sessions');
const POLL_MS = 500;

let applying = false;      // in-flight guard: one applyPending at a time
let invalidReads = 0;      // bounded retries for a half-written pending file

function activate(context) {
    // Poll for pending-color file every 500ms.
    // File watcher doesn't reliably fire for paths outside the workspace root,
    // so polling is more robust.
    const timer = setInterval(() => {
        if (!applying && fs.existsSync(PENDING_FILE)) {
            applying = true;
            applyPending().finally(() => { applying = false; });
        }
    }, POLL_MS);

    context.subscriptions.push({ dispose: () => clearInterval(timer) });
}

async function applyPending() {
    let content;
    try { content = fs.readFileSync(PENDING_FILE, 'utf8').trim(); }
    catch { return; }

    const data = {};
    for (const line of content.split('\n')) {
        const eq = line.indexOf('=');
        if (eq > 0) data[line.slice(0, eq).trim()] = line.slice(eq + 1).trim();
    }
    const { session_id, color, name } = data;

    // Validate before consuming: the writer's truncate-then-write isn't atomic,
    // so an empty/partial read gets left in place and retried next poll.
    // Bounded so a genuinely malformed file can't spin forever.
    if (!color) {
        invalidReads += 1;
        if (invalidReads >= 10) {
            invalidReads = 0;
            try { fs.unlinkSync(PENDING_FILE); } catch {}
        }
        return;
    }
    invalidReads = 0;

    // Delete now that the payload parsed, to prevent double-firing
    try { fs.unlinkSync(PENDING_FILE); } catch { return; }

    // Capture the terminal up front: at event receipt the just-started Claude
    // session's terminal is the active one. Re-reading activeTerminal after the
    // idle wait would target whatever the user focused in the meantime.
    const terminal = vscode.window.activeTerminal;
    if (!terminal) return;

    // Wait until the Claude session is idle before sending commands
    await waitForIdle(session_id);

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

async function waitForIdle(sessionId, timeoutMs = 30000, graceMs = 5000) {
    // No sessions dir at all: idle-tracking unavailable, don't stall the event.
    if (!fs.existsSync(SESSIONS_DIR)) return;
    const start = Date.now();
    while (Date.now() - start < timeoutMs) {
        try {
            const session = readSessionFile(SESSIONS_DIR, sessionId);
            if (session) {
                if (session.status !== 'busy') return;
            } else if (Date.now() - start >= graceMs) {
                // Session file never appeared: this poller can beat the writer at
                // session start, so a missing file means "not written yet", not
                // "idle". Give it a grace window before proceeding anyway.
                return;
            }
        } catch {}
        await sleep(250);
    }
}

const sleep = ms => new Promise(r => setTimeout(r, ms));

function deactivate() {}
module.exports = { activate, deactivate };
