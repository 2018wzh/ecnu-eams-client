enum ActionOutcome {
  success,
  rejected,
  cancelled,
  uncertain,
  retryable,
  authExpired
}

class CourseActionResult {
  final ActionOutcome outcome;
  final String message;
  final String? requestId;
  final Map<String, dynamic> lessonResults;
  final int attempts;
  final int elapsedMs;
  final Duration? retryAfter;
  final List<Map<String, dynamic>> selectedLessons;
  bool get success => outcome == ActionOutcome.success;
  bool get authExpired => outcome == ActionOutcome.authExpired;

  const CourseActionResult({
    required this.outcome,
    required this.message,
    this.requestId,
    this.lessonResults = const {},
    this.attempts = 0,
    this.elapsedMs = 0,
    this.retryAfter,
    this.selectedLessons = const [],
  });

  factory CourseActionResult.success({
    required String requestId,
    required Map<String, dynamic> lessonResults,
    required int attempts,
    required int elapsedMs,
    List<Map<String, dynamic>> selectedLessons = const [],
  }) {
    return CourseActionResult(
      outcome: ActionOutcome.success,
      message: '已核对已选课程，操作成功',
      requestId: requestId,
      lessonResults: lessonResults,
      attempts: attempts,
      elapsedMs: elapsedMs,
      selectedLessons: selectedLessons,
    );
  }

  factory CourseActionResult.failure(
    String message, {
    String? requestId,
    int attempts = 0,
    int elapsedMs = 0,
    bool authExpired = false,
    ActionOutcome outcome = ActionOutcome.rejected,
    Duration? retryAfter,
  }) {
    return CourseActionResult(
      outcome: authExpired ? ActionOutcome.authExpired : outcome,
      message: message,
      requestId: requestId,
      attempts: attempts,
      elapsedMs: elapsedMs,
      retryAfter: retryAfter,
    );
  }
}
