class PollingConfig {
  static const defaults = PollingConfig(
    timeout: Duration(seconds: 10),
    interval: Duration(milliseconds: 500),
  );

  final Duration timeout;
  final Duration interval;

  const PollingConfig({
    required this.timeout,
    required this.interval,
  });

  PollingConfig normalized() {
    Duration clamp(Duration value, Duration min, Duration max) {
      if (value < min) return min;
      if (value > max) return max;
      return value;
    }

    return PollingConfig(
      timeout: clamp(
          timeout, const Duration(seconds: 3), const Duration(seconds: 30)),
      interval: clamp(interval, const Duration(milliseconds: 200),
          const Duration(seconds: 2)),
    );
  }

  Map<String, dynamic> toJson() => {
        'timeoutMs': timeout.inMilliseconds,
        'intervalMs': interval.inMilliseconds,
      };

  static PollingConfig fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaults;
    return PollingConfig(
      timeout: Duration(
          milliseconds:
              _asInt(json['timeoutMs'], defaults.timeout.inMilliseconds)),
      interval: Duration(
          milliseconds:
              _asInt(json['intervalMs'], defaults.interval.inMilliseconds)),
    ).normalized();
  }

  static int _asInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
