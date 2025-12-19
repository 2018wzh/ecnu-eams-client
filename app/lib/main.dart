import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/course_provider.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化通知服务
  await NotificationService.initialize();

  // 初始化认证状态
  final authProvider = AuthProvider();
  await _initializeAuth(authProvider);

  runApp(MyApp(authProvider: authProvider));
}

Future<void> _initializeAuth(AuthProvider authProvider) async {
  final prefs = await SharedPreferences.getInstance();
  final authorization = prefs.getString('authorization');
  if (authorization != null && authorization.isNotEmpty) {
    await authProvider.setAuthorization(authorization);
    final isValid = await authProvider.checkTokenValidity();
    if (!isValid) {
      await prefs.remove('authorization');
      authProvider.logout();
    }
  }
}

class MyApp extends StatelessWidget {
  final AuthProvider authProvider;

  const MyApp({super.key, required this.authProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => CourseProvider()),
      ],
      child: MaterialApp(
        title: 'ECNU选课系统',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          // 配置中文字体支持
          fontFamily: null, // 使用系统默认字体
          fontFamilyFallback: const [
            // 中文字体回退列表，按平台优先级排序
            'PingFang SC', // macOS/iOS 首选
            'Hiragino Sans GB', // macOS 备选
            'Microsoft YaHei', // Windows 首选
            'SimHei', // Windows 备选
            'WenQuanYi Micro Hei', // Linux 首选
            'Noto Sans CJK SC', // Linux 备选
            'Source Han Sans SC', // 通用备选
            'sans-serif', // 最终回退
          ],
          appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        ),
        home: const AuthWrapper(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isAuthenticated) {
          return const HomeScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
