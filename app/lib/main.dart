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

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
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
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        home: const AuthWrapper(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final authorization = prefs.getString('authorization');
    setState(() {
      _isLoggedIn = authorization != null && authorization.isNotEmpty;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return _isLoggedIn ? const HomeScreen() : const LoginScreen();
  }
}
