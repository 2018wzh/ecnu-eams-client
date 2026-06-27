class DesktopLoginResult {
  final String? authorization;
  final String? errorMessage;

  const DesktopLoginResult({this.authorization, this.errorMessage});

  bool get success => authorization != null && authorization!.isNotEmpty;
}

class DesktopLoginService {
  Future<DesktopLoginResult> login() async {
    return const DesktopLoginResult(errorMessage: '当前平台不支持内置登录');
  }
}
