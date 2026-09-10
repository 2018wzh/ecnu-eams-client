import 'dart:async';

class OperationCancelled implements Exception {
  const OperationCancelled();
  @override
  String toString() => '任务已停止';
}

/// Cancels waits and prevents subsequent writes. An already sent write must
/// still be reconciled; cancellation cannot undo a server-side transaction.
class CancellationToken {
  final Completer<void> _cancelled = Completer<void>();
  bool get isCancelled => _cancelled.isCompleted;
  void cancel() {
    if (!isCancelled) _cancelled.complete();
  }

  void throwIfCancelled() {
    if (isCancelled) throw const OperationCancelled();
  }

  Future<void> delay(Duration duration) async {
    throwIfCancelled();
    if (duration <= Duration.zero) return;
    final timerDone = Completer<void>();
    final timer = Timer(duration, () => timerDone.complete());
    try {
      await Future.any([timerDone.future, _cancelled.future]);
      throwIfCancelled();
    } finally {
      timer.cancel();
    }
  }
}
