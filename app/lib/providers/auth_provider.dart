import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  bool _isAuthenticated = false;
  String? _studentID;
  List<Map<String, dynamic>>? _turns;
  Map<String, dynamic>? _currentTurn;
  String? _errorMessage;

  bool get isAuthenticated => _isAuthenticated;
  String? get studentID => _studentID;
  List<Map<String, dynamic>>? get turns => _turns;
  Map<String, dynamic>? get currentTurn => _currentTurn;
  String? get errorMessage => _errorMessage;

  final ApiService _apiService = ApiService();

  Future<void> setAuthorization(String authorization) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('authorization', authorization);
    _apiService.setAuthorization(authorization);
    _isAuthenticated = true;
    notifyListeners();
  }

  Future<void> loadStudentInfo() async {
    try {
      _errorMessage = null;
      final studentIDs = await _apiService.getStudentID();
      if (studentIDs.isNotEmpty) {
        _studentID = studentIDs.first.toString();
        await loadTurns();
      } else {
        _errorMessage = '未找到学生信息';
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('authorization');
    _isAuthenticated = false;
    _studentID = null;
    _turns = null;
    _currentTurn = null;
    notifyListeners();
  }
}

