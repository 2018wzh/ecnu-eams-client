import 'dart:convert';

import 'auth_token_normalizer.dart';

const browserLoginScript = r'''
(() => {
  const result = {origin: location.origin, ready: document.readyState, token: null};
  if (location.origin !== 'https://byyt.ecnu.edu.cn') return result;
  result.documentsChecked = 0;
  result.blockedFrames = 0;
  result.source = null;
  const valid = value => value && value.trim() && value !== 'null' && value !== 'undefined';
  const visit = win => {
    let origin;
    try {
      origin = win.location.origin;
    } catch (error) {
      if (error.name !== 'SecurityError') throw error;
      result.blockedFrames++;
      return false;
    }
    if (origin !== 'https://byyt.ecnu.edu.cn') return false;
    result.documentsChecked++;
    // The portal uses a session; only the student selection cookie is an API token.
    for (const entry of win.document.cookie.split(';')) {
      const separator = entry.indexOf('=');
      if (separator < 0) continue;
      const name = decodeURIComponent(entry.slice(0, separator).trim());
      if (name !== 'cs-course-select-student-token') continue;
      const value = decodeURIComponent(entry.slice(separator + 1));
      if (valid(value)) {
        result.token = value;
        result.source = 'selection-cookie';
        return true;
      }
    }
    // The official portal hands the token to this specific app in its query.
    if (win.location.pathname.startsWith('/course-selection/')) {
      const value = new URLSearchParams(win.location.search).get('token');
      if (valid(value)) {
        result.token = value;
        result.source = 'selection-url';
        return true;
      }
    }
    for (let i = 0; i < win.frames.length; i++) {
      if (visit(win.frames[i])) return true;
    }
    return false;
  };
  visit(window);
  return result;
})()
''';

class BrowserLoginSnapshot {
  final String origin;
  final String ready;
  final String? token;

  BrowserLoginSnapshot._(this.origin, this.ready, this.token);

  static BrowserLoginSnapshot? parse(String? value) {
    if (value == null || value == 'null') return null;
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic> ||
        decoded['origin'] is! String ||
        decoded['ready'] is! String) {
      throw const FormatException('浏览器登录状态格式无效');
    }
    final origin = decoded['origin'] as String;
    final rawToken = decoded['token'];
    String? token;
    if (origin == 'https://byyt.ecnu.edu.cn' && rawToken != null) {
      if (rawToken is! String) {
        throw const FormatException('浏览器 Token 格式无效');
      }
      if (rawToken.trim().isNotEmpty &&
          rawToken != 'null' &&
          rawToken != 'undefined') {
        token = AuthTokenNormalizer.normalize(rawToken);
      }
    }
    return BrowserLoginSnapshot._(origin, decoded['ready'] as String, token);
  }
}
