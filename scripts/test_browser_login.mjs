import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import test from 'node:test';

const source = readFileSync(new URL('../packages/eams_core/lib/src/browser_login_snapshot.dart', import.meta.url), 'utf8');
const script = source.match(/const browserLoginScript = r'''([\s\S]*?)''';/)[1];
function page(origin, cookie = '', pathname = '/home/', search = '', frames = []) {
  return { location: { origin, pathname, search },
    document: { readyState: 'complete', cookie }, frames };
}
function snapshot(win) {
  return vm.runInNewContext(script, { window: win, ...win, URLSearchParams });
}
const school = 'https://byyt.ecnu.edu.cn';
test('read student selection cookies, not portal/admin credentials', () => {
  assert.equal(snapshot(page(school,
    'Admin-Token=wrong; cs-course-select-student-token=Bearer%20test-token')).token, 'Bearer test-token');
  assert.equal(snapshot(page(school, 'Admin-Token=wrong; cs-course-select-admin-token=wrong')).token, null);
});
test('empty and unrelated cookies never become tokens', () => {
  assert.equal(snapshot(page(school, 'session=not-a-token')).token, null);
  assert.equal(snapshot(page(school, 'cs-course-select-student-token=')).token, null);
});
test('accept only exact school HTTPS origin', () => {
  for (const origin of ['https://sso.ecnu.edu.cn', 'http://byyt.ecnu.edu.cn',
    'https://byyt.ecnu.edu.cn.example.com']) {
    assert.equal(snapshot(page(origin, 'cs-course-select-student-token=test-token')).token, null);
  }
});
test('read same-origin selection iframe handoff, not unrelated URL tokens', () => {
  const inner = page(school, '', '/course-selection/', '?token=frame-token');
  assert.equal(snapshot(page(school, '', '/home/', '', [inner])).token, 'frame-token');
  assert.equal(snapshot(page(school, '', '/home/', '?token=wrong')).token, null);
});
test('skip cross-origin frames explicitly; other script failures propagate', () => {
  const frame = {};
  Object.defineProperty(frame, 'location', { get() {
    const error = new Error('blocked'); error.name = 'SecurityError'; throw error;
  }});
  assert.equal(snapshot(page(school, '', '/home/', '', [frame])).blockedFrames, 1);
  assert.throws(() => snapshot(page(school, 'cs-course-select-student-token=%ZZ')), {name: 'URIError'});
});
