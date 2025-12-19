import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../utils/error_dialog.dart';

// Conditional imports for webview
import 'package:webview_flutter/webview_flutter.dart' 
    if (dart.library.html) 'package:webview_flutter_web/webview_flutter_web.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _useExternalBrowser = false;

  @override
  void initState() {
    super.initState();
    _checkPlatform();
  }

  void _checkPlatform() {
    // 对于桌面平台，使用外部浏览器
    if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      _useExternalBrowser = true;
      _isLoading = false;
    } else {
      // 移动平台使用 WebView
      _initWebView();
    }
  }

  void _initWebView() {
    try {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              setState(() {
                _isLoading = true;
              });
            },
            onPageFinished: (String url) {
              setState(() {
                _isLoading = false;
              });
              
              // 检查是否登录成功（URL变化或特定元素出现）
              if (url.contains('byyt.ecnu.edu.cn') && !url.contains('login')) {
                _extractAuthorization();
              }
            },
          ),
        )
        ..loadRequest(Uri.parse('https://byyt.ecnu.edu.cn/'));
    } catch (e) {
      debugPrint('初始化WebView失败: $e');
      // 如果WebView初始化失败，回退到外部浏览器
      setState(() {
        _useExternalBrowser = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _extractAuthorization() async {
    try {
      if (_controller == null) return;
      
      // 尝试从localStorage获取Authorization token
      String? authorization;
      
      try {
        final token = await _controller!.runJavaScriptReturningResult(
          "localStorage.getItem('authorization') || localStorage.getItem('token') || sessionStorage.getItem('authorization') || sessionStorage.getItem('token')",
        );
        if (token != 'null' && token.toString().isNotEmpty) {
          authorization = token.toString();
        }
      } catch (e) {
        debugPrint('从localStorage获取token失败: $e');
      }
      
      // 如果localStorage中没有，尝试从请求头中获取
      if (authorization == null || authorization.isEmpty) {
        try {
          // 尝试通过JavaScript获取fetch请求的Authorization header
          final headerToken = await _controller!.runJavaScriptReturningResult(
            """
            (function() {
              try {
                var xhr = new XMLHttpRequest();
                xhr.open('GET', window.location.href, false);
                xhr.send();
                return xhr.getResponseHeader('Authorization') || 
                       xhr.getResponseHeader('authorization') ||
                       '';
              } catch(e) {
                return '';
              }
            })()
            """,
          );
          if (headerToken.toString().isNotEmpty && headerToken != 'null') {
            authorization = headerToken.toString();
          }
        } catch (e) {
          debugPrint('从请求头获取token失败: $e');
        }
      }
      
      // 如果仍然没有找到，显示输入对话框
      if (authorization == null || authorization.isEmpty) {
        if (mounted) {
          _showAuthorizationInputDialog();
        }
        return;
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('authorization', authorization);
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.setAuthorization(authorization);
      
      try {
        await authProvider.loadStudentInfo();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('登录成功！'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ErrorDialog.showError(
            context: context,
            error: e,
            title: '加载用户信息失败',
          );
        }
      }
    } catch (e) {
      debugPrint('提取Authorization失败: $e');
      if (mounted) {
        ErrorDialog.showError(
          context: context,
          error: e,
          title: '提取Authorization失败',
        );
        _showAuthorizationInputDialog();
      }
    }
  }

  Future<void> _openExternalBrowser() async {
    final url = Uri.parse('https://byyt.ecnu.edu.cn/');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      
      // 显示提示，让用户手动输入Authorization token
      if (mounted) {
        _showAuthorizationInputDialog();
      }
    } else {
      if (mounted) {
        ErrorDialog.show(
          context: context,
          title: '无法打开浏览器',
          message: '请检查系统是否安装了浏览器，或手动访问登录页面',
        );
      }
    }
  }

  void _showAuthorizationInputDialog() {
    final authController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('输入Authorization Token'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '请在浏览器中完成登录后，从浏览器开发者工具中复制Authorization token并粘贴到下方：',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: authController,
                decoration: const InputDecoration(
                  hintText: '粘贴Authorization token',
                  border: OutlineInputBorder(),
                  helperText: '例如: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              const Text(
                '获取方法：\n1. 按F12打开开发者工具\n2. 切换到Network标签\n3. 找到任意API请求\n4. 查看Request Headers中的Authorization字段\n5. 复制Authorization值（不包含"Bearer "前缀）',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (authController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入Authorization token')),
                );
                return;
              }
              
              String authorization = authController.text.trim();
              
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              await authProvider.setAuthorization(authorization);
              
              try {
                await authProvider.loadStudentInfo();
                
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('登录成功！'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ErrorDialog.showError(
                    context: context,
                    error: e,
                    title: '登录失败',
                  );
                }
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('登录ECNU选课系统'),
      ),
      body: _useExternalBrowser
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.open_in_browser, size: 64, color: Colors.blue),
                    const SizedBox(height: 24),
                    const Text(
                      '将在外部浏览器中打开登录页面',
                      style: TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _openExternalBrowser,
                      icon: const Icon(Icons.launch),
                      label: const Text('打开浏览器登录'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _showAuthorizationInputDialog,
                      child: const Text('我已登录，直接输入Authorization Token'),
                    ),
                  ],
                ),
              ),
            )
          : _controller != null
              ? Stack(
                  children: [
                    WebViewWidget(controller: _controller!),
                    if (_isLoading)
                      const Center(
                        child: CircularProgressIndicator(),
                      ),
                  ],
                )
              : const Center(
                  child: CircularProgressIndicator(),
                ),
    );
  }
}

