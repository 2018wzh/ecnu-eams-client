import 'package:eams_core/eams_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const credentialStorage = FlutterSecureStorage();

ApiService createApiService() => ApiService(
  authorizationProvider: () => credentialStorage.read(key: 'authorization'),
);
