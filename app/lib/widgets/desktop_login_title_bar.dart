import 'package:flutter/material.dart';

class DesktopLoginTitleBar extends StatelessWidget {
  final bool busy;
  final String? message;
  final VoidCallback onComplete;
  final VoidCallback onBack;
  final VoidCallback onReload;
  const DesktopLoginTitleBar({
    super.key,
    required this.busy,
    this.message,
    required this.onComplete,
    required this.onBack,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Row(
      children: [
        IconButton(
          onPressed: busy ? null : onBack,
          icon: const Icon(Icons.arrow_back, semanticLabel: '返回'),
        ),
        IconButton(
          onPressed: busy ? null : onReload,
          icon: const Icon(Icons.refresh, semanticLabel: '刷新'),
        ),
        const SizedBox(width: 8),
        // This Flutter view occupies only the toolbar's native child window.
        // Hover overlays cannot extend into the separate WebView2 surface.
        Expanded(
          child: Text(
            message ?? '进入“选课”后点击右侧按钮；关闭窗口取消登录。',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: message == null
                  ? null
                  : Theme.of(context).colorScheme.error,
            ),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: busy ? null : onComplete,
          icon: Icon(busy ? Icons.hourglass_top : Icons.check),
          label: Text(busy ? '正在读取凭据…' : '已登录，获取凭据并关闭'),
        ),
      ],
    ),
  );
}
