import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eams_core/eams_core.dart';
import '../services/credentials.dart';

class AuthProvider with ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isInitializing = true;
  String? _studentID;
  List<Map<String, dynamic>>? _turns;
  Map<String, dynamic>? _currentTurn;
  String? _errorMessage;

  bool get isAuthenticated => _isAuthenticated;
  bool get isInitializing => _isInitializing;
  String? get studentID => _studentID;
  List<Map<String, dynamic>>? get turns => _turns;
  Map<String, dynamic>? get currentTurn => _currentTurn;
  String? get errorMessage => _errorMessage;

  final ApiService _apiService;
  AuthProvider({ApiService? apiService})
    : _apiService = apiService ?? createApiService();

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('authorization') &&
          !await prefs.remove('authorization')) {
        throw StateError('清除旧登录凭据失败');
      }
      final token = await credentialStorage.read(key: 'authorization');
      if (token != null && token.isNotEmpty) await setAuthorization(token);
    } catch (e) {
      _errorMessage = '恢复登录失败，请重试: $e';
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> setAuthorization(String authorization) async {
    final normalized = AuthTokenNormalizer.normalize(authorization);
    _apiService.setAuthorization(normalized);
    try {
      await loadStudentInfo();
      if (_studentID == null) throw StateError('未找到学生信息');
      await credentialStorage.write(key: 'authorization', value: normalized);
      _isAuthenticated = true;
      notifyListeners();
    } catch (e) {
      _isAuthenticated = false;
      _studentID = null;
      _turns = null;
      _currentTurn = null;
      _apiService.clearAuthorization();
      if (e is ApiException && e.authExpired) {
        await credentialStorage.delete(key: 'authorization');
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loadStudentInfo() async {
    try {
      _errorMessage = null;
      final studentIDs = await _apiService.getStudentID();
      if (studentIDs.isNotEmpty) {
        _studentID = studentIDs.first.toString();
        await loadTurns();
      } else {
        _studentID = null;
        throw StateError('未找到学生信息');
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = '加载学生信息失败: $e';
      debugPrint(_errorMessage);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loadTurns() async {
    if (_studentID == null) return;

    try {
      _errorMessage = null;
      _turns = await _apiService.getOpenTurns(int.parse(_studentID!));
      notifyListeners();
    } catch (e) {
      _errorMessage = '加载选课轮次失败: $e';
      debugPrint(_errorMessage);
      notifyListeners();
      rethrow;
    }
  }

  void setCurrentTurn(Map<String, dynamic> turn) {
    _currentTurn = turn;
    notifyListeners();
  }

  Future<void> logout() async {
    await credentialStorage.delete(key: 'authorization');
    _apiService.clearAuthorization();
    _isAuthenticated = false;
    _studentID = null;
    _turns = null;
    _currentTurn = null;
    _errorMessage = null;
    notifyListeners();
  }
}
