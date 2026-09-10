import 'dart:convert';
import 'auth_token_normalizer.dart';
import 'polling_config.dart';

class AutomationTarget {
  final int lessonId;
  final String name;
  final int virtualCost;
  const AutomationTarget(
      {required this.lessonId, required this.name, this.virtualCost = 0});

  factory AutomationTarget.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('课程名称不能为空');
    }
    return AutomationTarget(
      lessonId: positiveInt(json['lessonId'], 'lessonId'),
      name: name,
      virtualCost: boundedInt(json['virtualCost'], 'virtualCost', 0, 100),
    );
  }

  Map<String, dynamic> toJson() => {
        'lessonId': lessonId,
        'name': name,
        'virtualCost': virtualCost,
      };
}

class AutomationConfig {
  final String token;
  final int studentId;
  final int turnId;
  final int semesterId;
  final Duration interval;
  final DateTime? startAt;
  final PollingConfig polling;
  final List<AutomationTarget> targets;

  const AutomationConfig(
      {required this.token,
      required this.studentId,
      required this.turnId,
      required this.semesterId,
      required this.targets,
      this.interval = const Duration(milliseconds: 500),
      this.startAt,
      this.polling = PollingConfig.defaults});

  factory AutomationConfig.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) throw const FormatException('不支持的配置版本');
    if (json['token'] is! String) {
      throw const FormatException('配置必须包含 token 字符串');
    }
    final raw = json['targets'];
    if (raw is! List || raw.isEmpty || raw.length > 100) {
      throw const FormatException('请配置 1 至 100 门目标课程');
    }
    final targets = raw
        .map((v) =>
            AutomationTarget.fromJson(Map<String, dynamic>.from(v as Map)))
        .toList();
    if (targets.map((v) => v.lessonId).toSet().length != targets.length) {
      throw const FormatException('目标课程不能重复');
    }
    DateTime? start;
    if (json['startAt'] != null) {
      final text = json['startAt'];
      if (text is! String || !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(text)) {
        throw const FormatException('startAt 必须为包含时区的 ISO 8601 时间');
      }
      start = DateTime.parse(text).toUtc();
    }
    final poll = json['polling'] as Map<String, dynamic>;
    return AutomationConfig(
      token: AuthTokenNormalizer.normalize(json['token'] as String),
      studentId: positiveInt(json['studentId'], 'studentId'),
      turnId: positiveInt(json['turnId'], 'turnId'),
      semesterId: positiveInt(json['semesterId'], 'semesterId'),
      interval: Duration(
          milliseconds:
              boundedInt(json['intervalMs'], 'intervalMs', 200, 60000)),
      polling: PollingConfig(
          timeout: Duration(
              milliseconds: boundedInt(
                  poll['timeoutMs'], 'polling.timeoutMs', 3000, 30000)),
          interval: Duration(
              milliseconds: boundedInt(
                  poll['intervalMs'], 'polling.intervalMs', 200, 2000))),
      startAt: start,
      targets: List.unmodifiable(targets),
    );
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'token': token,
        'studentId': studentId,
        'turnId': turnId,
        'semesterId': semesterId,
        'intervalMs': interval.inMilliseconds,
        'startAt': startAt?.toUtc().toIso8601String(),
        'polling': polling.toJson(),
        'targets': targets.map((v) => v.toJson()).toList(),
      };

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());
  String toBase64() {
    validate();
    return base64Encode(utf8.encode(jsonEncode(toJson())));
  }

  factory AutomationConfig.fromBase64(String encoded) {
    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(base64Decode(encoded)));
    } on FormatException {
      // Decoder exceptions may contain the original credential-bearing input.
      throw const FormatException('配置必须为 UTF-8 JSON 的 Base64 字符串');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('配置必须为 JSON 对象');
    }
    return AutomationConfig.fromJson(decoded);
  }
  void validate() => AutomationConfig.fromJson(toJson());
}

int positiveInt(dynamic value, String name) =>
    boundedInt(value, name, 1, 2147483647);

int boundedInt(dynamic value, String name, int min, int max) {
  if (value is! int || value < min || value > max) {
    throw FormatException('$name 必须为 $min 至 $max 的整数');
  }
  return value;
}

/// The school's unzoned timestamps are China Standard Time, independent of the
/// host timezone (the CLI may run on a server configured in UTC).
DateTime parseSchoolTime(String value) {
  final text = value.trim().replaceFirst(' ', 'T');
  return DateTime.parse(
          RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(text) ? text : '$text+08:00')
      .toUtc();
}
