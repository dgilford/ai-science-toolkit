#!/usr/bin/env node
// Smoke test for vscode-extension/lib/session-status.js's readSessionFile.
// Run directly: node tests/smoke_test_session_status.js
'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');
const { readSessionFile } = require('../vscode-extension/lib/session-status');

const sandbox = fs.mkdtempSync(path.join(os.tmpdir(), 'session-status-test-'));
fs.copyFileSync(path.join(__dirname, 'fixtures', 'session-status-busy.json'), path.join(sandbox, 'busy.json'));
fs.copyFileSync(path.join(__dirname, 'fixtures', 'session-status-idle.json'), path.join(sandbox, 'idle.json'));

let ok = true;
function check(desc, expected, actual) {
    if (JSON.stringify(expected) !== JSON.stringify(actual)) {
        console.error(`FAIL ${desc}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
        ok = false;
    } else {
        console.error(`  ok ${desc}`);
    }
}

check('finds busy session by id', 'busy', (readSessionFile(sandbox, 'session-busy-fixture') || {}).status);
check('finds idle session by id', 'idle', (readSessionFile(sandbox, 'session-idle-fixture') || {}).status);
check('unknown session id returns null', null, readSessionFile(sandbox, 'no-such-session'));
check('missing sessions dir returns null', null, readSessionFile(path.join(sandbox, 'does-not-exist'), 'anything'));

fs.rmSync(sandbox, { recursive: true, force: true });

console.log(ok ? 'PASS' : 'FAIL');
process.exit(ok ? 0 : 1);
