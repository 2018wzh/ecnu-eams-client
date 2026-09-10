import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:eams_core/eams_core.dart';
import '../providers/course_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/error_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _pollTimeoutController;
  late final TextEditingController _pollIntervalController;
  late final TextEditingController _robIntervalController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<CourseProvider>();
    _pollTimeoutController = TextEditingController(
      text: provider.pollingConfig.timeout.inSeconds.toString(),
    );
    _pollIntervalController = TextEditingController(
      text: provider.pollingConfig.interval.inMilliseconds.toString(),
    );
    _robIntervalController = TextEditingController(
      text: provider.robInterval.inMilliseconds.toString(),
    );
  }

  @override
  void dispose() {
    _pollTimeoutController.dispose();
    _pollIntervalController.dispose();
    _robIntervalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CourseProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OutlinedButton.icon(
            onPressed: () async {
              try {
                final config = await context
                    .read<AuthProvider>()
                    .exportClientConfig();
                await Clipboard.setData(
                  ClipboardData(
                    text:
                        'eams --config "${config.toBase64()}" --action verify',
                  ),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('已复制 CLI 验证命令，包含当前 Token；无需添加抢课目标'),
                    ),
                  );
                }
              } catch (error) {
                if (context.mounted) {
                  ErrorDialog.showError(context: context, error: error);
                }
              }
            },
            icon: const Icon(Icons.terminal),
            label: const Text('复制 CLI 只读验证命令'),
          ),
          const SizedBox(height: 24),
          Text('轮询设置', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _pollTimeoutController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '选退课结果超时',
              suffixText: '秒',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _applyPolling(provider),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pollIntervalController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '选退课轮询间隔',
              suffixText: '毫秒',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _applyPolling(provider),
          ),
          const SizedBox(height: 24),
          Text('抢课设置', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _robIntervalController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '抢课间隔',
              suffixText: '毫秒',
              helperText: '低于 500ms 可能增加限流或账号风险，最低 200ms',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              final ms = int.tryParse(value);
              if (ms != null) {
                provider.setRobInterval(Duration(milliseconds: ms));
              }
            },
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () async {
              try {
                await provider.clearAutomationTargets();
              } catch (e) {
                if (context.mounted) {
                  ErrorDialog.showError(context: context, error: e);
                }
                return;
              }
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已清空抢课和监控目标')));
              }
            },
            icon: const Icon(Icons.clear_all),
            label: const Text('清空抢课/监控目标'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final logs = await provider.readLogs();
              if (!context.mounted) return;
              showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('最近日志'),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: SingleChildScrollView(
                      child: SelectableText(logs.isEmpty ? '暂无日志' : logs),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('关闭'),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.article),
            label: const Text('查看日志'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              await provider.clearLogs();
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已清空日志')));
              }
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('清空日志'),
          ),
        ],
      ),
    );
  }

  void _applyPolling(CourseProvider provider) {
    final timeoutSeconds = int.tryParse(_pollTimeoutController.text);
    final intervalMs = int.tryParse(_pollIntervalController.text);
    if (timeoutSeconds == null || intervalMs == null) return;
    provider.setPollingConfig(
      PollingConfig(
        timeout: Duration(seconds: timeoutSeconds),
        interval: Duration(milliseconds: intervalMs),
      ),
    );
  }
}
