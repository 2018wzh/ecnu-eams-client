class ExecutionLease {
  static final Set<int> _held = {};
  final int studentId;
  ExecutionLease._(this.studentId);
  static Future<ExecutionLease> acquire(int studentId) async {
    if (!_held.add(studentId)) throw StateError('该学生已有选课任务运行');
    return ExecutionLease._(studentId);
  }

  Future<void> release() async => _held.remove(studentId);
}
