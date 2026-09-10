import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import test from 'node:test';

const source = readFileSync(new URL('../packages/eams_core/lib/src/browser_login_snapshot.dart', import.meta.url), 'utf8');
const script = source.match(/const browserLoginScript = r'''([\s\S]*?)''';/)[1];
function snapshot(origin, cookie = '', values = {}) {
  const store = { getItem: key => values[key] ?? null };
  return vm.runInNewContext(script, {
    location: { origin }, document: { readyState: 'complete', cookie },
    localStorage: store, sessionStorage: store,
  });
}
test('extract the current portal cookie and decode cookie encoding', () => {
  assert.equal(snapshot('https://byyt.ecnu.edu.cn',
    '%24%7BTOKEN_KEY%7D=Bearer%20test-token').token, 'Bearer test-token');
});
test('empty and unrelated cookies never become tokens', () => {
  assert.equal(snapshot('https://byyt.ecnu.edu.cn', 'session=not-a-token').token, null);
  assert.equal(snapshot('https://byyt.ecnu.edu.cn', '', { token: '' }).token, null);
});
test('never read credentials outside the exact school HTTPS origin', () => {
  for (const origin of ['https://sso.ecnu.edu.cn', 'http://byyt.ecnu.edu.cn',
    'https://byyt.ecnu.edu.cn.example.com']) {
    assert.equal(snapshot(origin, 'Admin-Token=test-token', { token: 'other' }).token, null);
  }
});
