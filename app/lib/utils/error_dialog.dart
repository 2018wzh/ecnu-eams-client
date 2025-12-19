import 'package:flutter/material.dart';

/// 错误弹窗工具类
class ErrorDialog {
  /// 显示错误弹窗
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String message,
    String? details,
    VoidCallback? onConfirm,
    String confirmText = '确定',
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 48,
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(fontSize: 16),
                ),
                if (details != null && details.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    '详细信息：',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      details,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm?.call();
              },
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }

  /// 显示网络错误弹窗
  static Future<void> showNetworkError({
    required BuildContext context,
    String? message,
    VoidCallback? onRetry,
  }) {
    return show(
      context: context,
      title: '网络错误',
      message: message ?? '网络连接失败，请检查网络设置后重试',
      onConfirm: onRetry,
      confirmText: onRetry != null ? '重试' : '确定',
    );
  }

  /// 显示API错误弹窗
  static Future<void> showApiError({
    required BuildContext context,
    required String message,
    String? details,
    VoidCallback? onRetry,
  }) {
    return show(
      context: context,
      title: '请求失败',
      message: message,
      details: details,
      onConfirm: onRetry,
      confirmText: onRetry != null ? '重试' : '确定',
    );
  }

  /// 显示认证错误弹窗
  static Future<void> showAuthError({
    required BuildContext context,
    String? message,
    VoidCallback? onLogin,
  }) {
    return show(
      context: context,
      title: '登录已过期',
      message: message ?? '您的登录已过期，请重新登录',
      onConfirm: onLogin,
      confirmText: '重新登录',
    );
  }

  /// 显示通用错误弹窗（从异常对象）
  static Future<void> showError({
    required BuildContext context,
    required dynamic error,
    String? title,
    VoidCallback? onConfirm,
  }) {
    String errorMessage = '发生未知错误';
    String? errorDetails;

    if (error is Exception) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    } else if (error is String) {
      errorMessage = error;
    } else {
      errorMessage = error.toString();
      errorDetails = error.toString();
    }

    return show(
      context: context,
      title: title ?? '错误',
      message: errorMessage,
      details: errorDetails,
      onConfirm: onConfirm,
    );
  }
}

