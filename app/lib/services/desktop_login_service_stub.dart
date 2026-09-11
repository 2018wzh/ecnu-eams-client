import 'package:eams_core/eams_core.dart';

class DesktopLoginResult {
  final String? authorization;
  final PortalSession? portalSession;
  final String? errorMessage;

  const DesktopLoginResult({
    this.authorization,
    this.errorMessage,
    this.portalSession,
  });

  bool get success => authorization != null && authorization!.isNotEmpty;
}

class DesktopLoginService {
  Future<DesktopLoginResult> login() async {
    return const DesktopLoginResult(errorMessage: '当前平台不支持内置登录');
  }
}
