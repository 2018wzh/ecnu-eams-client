import 'dart:io';

/// One writer per student on this machine, shared by the GUI and CLI.
class ExecutionLease {
  static final Set<int> _held = {};
  final int studentId;
  final RandomAccessFile _file;
  ExecutionLease._(this.studentId, this._file);

  static Future<ExecutionLease> acquire(int studentId) async {
    if (!_held.add(studentId)) throw StateError('该学生已有选课任务运行');
    RandomAccessFile? handle;
    try {
      final file = File('${Directory.systemTemp.path}${Platform.pathSeparator}'
          'ecnu-eams-$studentId.lock');
      handle = await file.open(mode: FileMode.append);
      await handle.lock(FileLock.exclusive);
      return ExecutionLease._(studentId, handle);
    } catch (_) {
      await handle?.close();
      _held.remove(studentId);
      throw StateError('该学生已有选课进程运行，或无法取得运行锁');
    }
  }

  Future<void> release() async {
    try {
      await _file.unlock();
    } finally {
      try {
        await _file.close();
      } finally {
        _held.remove(studentId);
      }
    }
  }
}
