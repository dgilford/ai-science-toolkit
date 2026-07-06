// Pure helper extracted from extension.js's waitForIdle so it can be unit
// tested without a `vscode` module in scope (the extension host isn't
// available outside VS Code). No side effects beyond reading the filesystem.
const fs = require('fs');
const path = require('path');

// Reads SESSIONS_DIR for a session file matching sessionId (or the first one,
// if sessionId is falsy). Returns the parsed session object, or null if the
// directory can't be read or no matching session file exists.
function readSessionFile(sessionsDir, sessionId) {
    let files;
    try {
        files = fs.readdirSync(sessionsDir).filter(f => f.endsWith('.json'));
    } catch {
        return null;
    }
    const session = files
        .map(f => { try { return JSON.parse(fs.readFileSync(path.join(sessionsDir, f))); } catch { return null; } })
        .find(d => d && (!sessionId || d.sessionId === sessionId));
    return session || null;
}

module.exports = { readSessionFile };
