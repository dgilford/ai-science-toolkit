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

    // Reject embedded control characters before anything reaches the terminal.
    // sendText submits what it's given, so a CR inside a value would terminate
    // the /color or /rename line early and run the remainder as a second
    // command. \n can't survive the line-based parse above, which makes \r the
    // reachable case — and these values are not as trusted as they look: name
    // defaults to `basename "$PWD"` in setup.sh, and Linux permits \r in
    // directory names, so opening a session inside a hostile checkout is enough.
    // Drop the payload rather than sanitizing it: a tab name is never worth
    // guessing at, and the file is already consumed so this can't spin.
    if (/[\r\n]/.test(color) || /[\r\n]/.test(name || '')) {
        console.error('claude-tab: refusing pending payload with control characters');
        return;
    }

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

    // Prepend Ctrl-E + Ctrl-U so anything the user has typed into the prompt is
    // cleared before the command is sent. sendText appends to the terminal input
    // buffer, so without this the typed text merges into "/color"/"/rename" and
    // corrupts both. Ctrl-E (end-of-line) then Ctrl-U (kill-to-start) clears the
    // whole line regardless of cursor position; these are Claude Code's own
    // readline bindings, so they behave the same as in the iTerm path.
    const CLEAR_LINE = '\x05\x15';
    terminal.sendText(`${CLEAR_LINE}/color ${color}`);
    if (name) {
        await sleep(400);
        terminal.sendText(`${CLEAR_LINE}/rename ${name}`);
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
