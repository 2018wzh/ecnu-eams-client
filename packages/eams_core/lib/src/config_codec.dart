import 'dart:convert';

Map<String, dynamic> decodeClientConfiguration(String encoded) {
  try {
    final value = jsonDecode(utf8.decode(base64Decode(encoded)));
    if (value is Map<String, dynamic>) return value;
  } on FormatException {
    // Never attach the credential-bearing input to a decoding exception.
  }
  throw const FormatException('配置必须为 UTF-8 JSON 对象的 Base64 字符串');
}
