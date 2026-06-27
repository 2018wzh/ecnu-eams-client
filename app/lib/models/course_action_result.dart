class CourseActionResult {
  final bool success;
  final String message;
  final String? requestId;
  final Map<String, dynamic> lessonResults;
  final int attempts;
  final int elapsedMs;
  final bool authExpired;

  const CourseActionResult({
    required this.success,
    required this.message,
    this.requestId,
    this.lessonResults = const {},
    this.attempts = 0,
    this.elapsedMs = 0,
    this.authExpired = false,
  });

  factory CourseActionResult.success({
    required String requestId,
    required Map<String, dynamic> lessonResults,
    required int attempts,
    required int elapsedMs,
  }) {
    return CourseActionResult(
      success: true,
      message: '成功',
      requestId: requestId,
      lessonResults: lessonResults,
      attempts: attempts,
      elapsedMs: elapsedMs,
    );
  }

  factory CourseActionResult.failure(
    String message, {
    String? requestId,
    int attempts = 0,
    int elapsedMs = 0,
    bool authExpired = false,
  }) {
    return CourseActionResult(
      success: false,
      message: message,
      requestId: requestId,
      attempts: attempts,
      elapsedMs: elapsedMs,
      authExpired: authExpired,
    );
  }
}
