import 'dart:convert';

import 'auth_token_normalizer.dart';

const browserLoginScript = r'''
(() => {
  const result = {origin: location.origin, ready: document.readyState, token: null};
  if (location.origin !== 'https://byyt.ecnu.edu.cn') return result;
  // The current portal uses js-cookie with the deployed TOKEN_KEY.
  const cookieKeys = ['${TOKEN_KEY}', 'Admin-Token'];
  for (const entry of document.cookie.split(';')) {
    const separator = entry.indexOf('=');
    if (separator < 0) continue;
    const name = decodeURIComponent(entry.slice(0, separator).trim());
    if (cookieKeys.includes(name)) {
      const value = decodeURIComponent(entry.slice(separator + 1));
      if (value && value !== 'null' && value !== 'undefined') {
        result.token = value;
        return result;
      }
    }
  }
  for (const store of [localStorage, sessionStorage]) {
    for (const key of ['authorization', 'Authorization', 'token', 'access_token']) {
      const value = store.getItem(key);
      if (value && value.trim() && value !== 'null' && value !== 'undefined') {
        result.token = value;
        return result;
      }
    }
  }
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
