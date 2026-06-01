const vscode = require('vscode');
const fs = require('fs');
const path = require('path');
const os = require('os');

const PENDING_FILE = path.join(os.homedir(), '.claude', '.pending-color');
const SESSIONS_DIR = path.join(os.homedir(), '.claude', 'sessions');

function activate(context) {
    const watchDir = vscode.Uri.file(path.join(os.homedir(), '.claude'));
    const watcher = vscode.workspace.createFileSystemWatcher(
        new vscode.RelativePattern(watchDir, '.pending-color')
    );
    watcher.onDidCreate(() => applyPending());
    watcher.onDidChange(() => applyPending());
    context.subscriptions.push(watcher);
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
    if (!color) return;

    // Wait until Claude finishes generating its response
    await waitForIdle(session_id);

    const terminal = vscode.window.activeTerminal;
    if (!terminal) return;

    terminal.sendText(`/color ${color}`);
    if (name) {
        await sleep(400);
        terminal.sendText(`/rename ${name}`);
    }

    try { fs.unlinkSync(PENDING_FILE); } catch {}
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
