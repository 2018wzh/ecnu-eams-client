import 'api_service.dart';

class StudentAccount {
  final int studentId;
  final List<Map<String, dynamic>> turns;
  const StudentAccount(this.studentId, this.turns);
  Map<String, dynamic> toJson() => {'studentId': studentId, 'turns': turns};
}

class SelectionScope {
  final int studentId, turnId, semesterId;
  final Map<String, dynamic> detail;
  const SelectionScope(
    this.studentId,
    this.turnId,
    this.semesterId,
    this.detail,
  );
  Map<String, dynamic> toJson() => {
    'studentId': studentId,
    'turnId': turnId,
    'semesterId': semesterId,
  };
}

class ClientSession {
  final ApiService api;
  const ClientSession(this.api);

  Future<StudentAccount> loadAccount({int? studentId}) async {
    final ids = await api.getStudentID();
    if (ids.isEmpty) throw StateError('未找到学生信息');
    if (studentId != null && !ids.contains(studentId)) {
      throw StateError('配置的学生不属于当前登录账号');
    }
    final id = studentId ?? ids.first;
    return StudentAccount(id, await api.getOpenTurns(id));
  }

  Future<SelectionScope> openTurn(
    StudentAccount account,
    int turnId, {
    int? semesterId,
  }) async {
    final matches = account.turns.where((t) => t['id'] == turnId);
    if (matches.length != 1) throw StateError('指定轮次不在当前账号的开放轮次中');
    if (matches.single['allowEnter'] != true) {
      throw StateError('当前轮次不允许进入');
    }
    final detail = await api.getSelectDetail(account.studentId, turnId);
    final semester = detail['semester'];
    if (semester is! Map || semester['id'] is! int || semester['id'] <= 0) {
      throw const FormatException('轮次缺少有效学期');
    }
    final actual = semester['id'] as int;
    if (semesterId != null && semesterId != actual) {
      throw StateError('配置学期与当前轮次不一致');
    }
    return SelectionScope(account.studentId, turnId, actual, detail);
  }
}
