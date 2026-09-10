import 'dart:convert';
import 'auth_token_normalizer.dart';
import 'automation_config.dart' show positiveInt;
import 'config_codec.dart';

/// Read-only commands need only a token; GUI automation exports also work.
class ClientConfig {
  final String token;
  final int? studentId, turnId, semesterId;
  const ClientConfig({
    required this.token,
    this.studentId,
    this.turnId,
    this.semesterId,
  });

  factory ClientConfig.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1 || json['token'] is! String) {
      throw const FormatException('配置需要 version: 1 和 token 字符串');
    }
    int? id(String name) =>
        json[name] == null ? null : positiveInt(json[name], name);
    return ClientConfig(
      token: AuthTokenNormalizer.normalize(json['token'] as String),
      studentId: id('studentId'),
      turnId: id('turnId'),
      semesterId: id('semesterId'),
    );
  }

  factory ClientConfig.fromBase64(String value) =>
      ClientConfig.fromJson(decodeClientConfiguration(value));
  Map<String, dynamic> toJson() => {
    'version': 1,
    'token': token,
    if (studentId != null) 'studentId': studentId,
    if (turnId != null) 'turnId': turnId,
    if (semesterId != null) 'semesterId': semesterId,
  };
  String toBase64() {
    ClientConfig.fromJson(toJson());
    return base64Encode(utf8.encode(jsonEncode(toJson())));
  }
}
