class AppLogService {
  AppLogService({Object? directory, int maxBytes = 256 * 1024});

  Future<void> write(
    String event,
    String message, {
    Map<String, dynamic>? data,
  }) async {}

  Future<String> readRecent() async => '';

  Future<void> clear() async {}
}
