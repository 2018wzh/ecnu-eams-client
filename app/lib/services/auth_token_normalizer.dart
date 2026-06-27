class AuthTokenNormalizer {
  static String normalize(String input) {
    var token = input.trim();
    if ((token.startsWith('"') && token.endsWith('"')) ||
        (token.startsWith("'") && token.endsWith("'"))) {
      token = token.substring(1, token.length - 1).trim();
    }
    if (token.toLowerCase().startsWith('bearer ')) {
      token = token.substring(7).trim();
    }
    if (token.isEmpty) {
      throw const FormatException('Authorization token 不能为空');
    }
    return token;
  }

  static String redact(String text) {
    var redacted = text.replaceAll(
      RegExp(r'Authorization:\s*(Bearer\s+)?[^\s,;]+', caseSensitive: false),
      'Authorization: [REDACTED]',
    );
    redacted = redacted.replaceAll(
      RegExp(r'"authorization"\s*:\s*"[^"]*"', caseSensitive: false),
      '"authorization":"[REDACTED]"',
    );
    redacted = redacted.replaceAll(
      RegExp(r"'authorization'\s*:\s*'[^']*'", caseSensitive: false),
      "'authorization':'[REDACTED]'",
    );
    return redacted;
  }
}
