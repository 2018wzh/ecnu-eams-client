import 'dart:convert';
import 'package:eams_core/eams_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const credentialStorage = FlutterSecureStorage();

ApiService createApiService() => ApiService(
  authorizationProvider: () => credentialStorage.read(key: 'authorization'),
  portalSessionProvider: readPortalSession,
  onAuthorizationRenewed: (previous, next) async {
    if (await credentialStorage.read(key: 'authorization') != previous) {
      throw StateError('登录凭据已改变，拒绝覆盖');
    }
    await credentialStorage.write(key: 'authorization', value: next);
  },
);

Future<PortalSession?> readPortalSession() async {
  final value = await credentialStorage.read(key: 'portalSession');
  if (value == null) return null;
  try {
    return PortalSession.fromJson(jsonDecode(value));
  } on FormatException {
    throw const FormatException('保存的门户会话无效，请重新网页登录');
  }
}

Future<void> writePortalSession(PortalSession? session) async {
  if (session == null) {
    await credentialStorage.delete(key: 'portalSession');
  } else {
    await credentialStorage.write(
      key: 'portalSession',
      value: jsonEncode(session.toJson()),
    );
  }
}
