import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:eams_core/eams_core.dart';
import '../utils/error_dialog.dart';

class CliExportDialog extends StatelessWidget {
  final AutomationConfig config;
  const CliExportDialog({super.key, required this.config});

  Future<void> _copy(BuildContext context, String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已复制')));
      }
    } catch (e) {
      if (context.mounted) {
        ErrorDialog.showError(context: context, error: e, title: '复制失败');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final encoded = config.toBase64();
    final command = 'eams --config "$encoded"';
    return AlertDialog(
      title: const Text('交给 CLI 运行'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('已停止 GUI 自动任务。配置包含 ${config.targets.length} 门课程，按列表顺序运行。'),
              const SizedBox(height: 12),
              const Text(
                  '配置已包含当前登录 Token，并编码为 Base64。复制启动命令即可运行，无需另外输入 Token。'),
              const SizedBox(height: 12),
              const SelectableText('eams --config "<Base64配置>"'),
              const SizedBox(height: 8),
              const Text('检查命令只验证配置和官网状态；启动命令开始抢课。CLI 运行时请保持电脑唤醒和网络连接。'),
              const SizedBox(height: 12),
              ExpansionTile(title: const Text('查看 Base64 配置'), children: [
                SelectableText(encoded, style: const TextStyle(fontSize: 12)),
              ]),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('关闭')),
        TextButton(
            onPressed: () => _copy(context, encoded),
            child: const Text('复制配置')),
        TextButton(
            onPressed: () => _copy(context, '$command --check'),
            child: const Text('复制检查命令')),
        FilledButton(
            onPressed: () => _copy(context, command),
            child: const Text('复制启动命令')),
      ],
    );
  }
}
