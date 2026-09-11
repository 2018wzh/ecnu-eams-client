/// School portal authentication, scoped exclusively to the renewal endpoint.
class PortalSession {
  final String session;
  final String gateway;
  const PortalSession({required this.session, required this.gateway});

  factory PortalSession.fromJson(Object? value) {
    if (value is! Map ||
        value.keys.toSet().difference({'SESSION', 'cookie'}).isNotEmpty) {
      throw const FormatException('门户会话格式无效');
    }
    String read(String key) {
      final text = value[key];
      if (text is! String || text.isEmpty) {
        throw FormatException('缺少门户会话 Cookie：$key，请从学校门户进入选课后重试');
      }
      final octets =
          text.startsWith('"') && text.endsWith('"') && text.length >= 2
          ? text.substring(1, text.length - 1)
          : text;
      if (octets.isEmpty ||
          text.length > 8192 ||
          !RegExp(
            r'^[\x21\x23-\x2B\x2D-\x3A\x3C-\x5B\x5D-\x7E]+$',
          ).hasMatch(octets)) {
        throw FormatException('门户会话 Cookie 格式无效：$key，请重新网页登录');
      }
      return text;
    }

    return PortalSession(session: read('SESSION'), gateway: read('cookie'));
  }

  Map<String, String> toJson() => {'SESSION': session, 'cookie': gateway};
  String get cookieHeader {
    PortalSession.fromJson(toJson());
    return 'SESSION=$session; cookie=$gateway';
  }

  @override
  String toString() => 'PortalSession([REDACTED])';
}
