import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/course_provider.dart';
import '../widgets/course_card.dart';
import '../widgets/cli_export_dialog.dart';
import '../utils/error_dialog.dart';

class RobScreen extends StatefulWidget {
  const RobScreen({super.key});

  @override
  State<RobScreen> createState() => _RobScreenState();
}

class _RobScreenState extends State<RobScreen> {
  final TextEditingController _intervalController = TextEditingController();
  String? _loadedContext;

  @override
  void initState() {
    super.initState();
    final courseProvider = context.read<CourseProvider>();
    _intervalController.text =
        courseProvider.robInterval.inMilliseconds.toString();
  }

  @override
  void dispose() {
    _intervalController.dispose();
    super.dispose();
  }

  Future<void> _selectScheduledTime(
      BuildContext context, CourseProvider courseProvider) async {
    final date = await showDatePicker(
        context: context,
        initialDate: courseProvider.scheduledStartTime ?? DateTime.now(),
        firstDate: DateTime.now().subtract(const Duration(days: 1)),
        lastDate: DateTime.now().add(const Duration(days: 366)));
    if (date == null || !context.mounted) return;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      final scheduledTime = DateTime(
        date.year,
        date.month,
        date.day,
        picked.hour,
        picked.minute,
      );
      courseProvider.setScheduledStartTime(scheduledTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, CourseProvider>(
      builder: (context, authProvider, courseProvider, _) {
        if (_loadedContext != courseProvider.contextKey) {
          _loadedContext = courseProvider.contextKey;
          _intervalController.text =
              courseProvider.robInterval.inMilliseconds.toString();
        }
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: courseProvider.isRobbing
                  ? Colors.orange.shade50
                  : Colors.grey.shade100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        courseProvider.isRobbing
                            ? Icons.flash_on
                            : Icons.flash_off,
                        color: courseProvider.isRobbing
                            ? Colors.orange
                            : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          courseProvider.isRobbing
                              ? '任务运行中（停止后等待结果核对）'
                              : '抢课已停止',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Switch(
                        value: courseProvider.isRobbing,
                        onChanged: (value) {
                          if (value) {
                            if (authProvider.studentID == null ||
                                authProvider.currentTurn == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('请先选择选课轮次')),
                              );
                              return;
                            }

                            if (courseProvider.robTargets.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('请先添加抢课目标')),
                              );
                              return;
                            }

                            courseProvider.startRob(
                              int.parse(authProvider.studentID!),
                              authProvider.currentTurn!['id'],
                            );
                          } else {
                            courseProvider.stopRob();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '按优先级检查可选余量并选课。应用需要保持运行；长时间运行可交给 CLI。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.orange.shade800,
                        ),
                  ),
                  const SizedBox(height: 16),
                  // 定时开始设置
                  Row(
                    children: [
                      const Text('定时开始:'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: courseProvider.isRobbing
                              ? null
                              : () =>
                                  _selectScheduledTime(context, courseProvider),
                          child: Text(
                            courseProvider.scheduledStartTime != null
                                ? courseProvider.scheduledStartTime!
                                    .toLocal()
                                    .toString()
                                    .substring(0, 16)
                                : '选择时间',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: courseProvider.isRobbing
                            ? null
                            : () => courseProvider.setScheduledStartTime(null),
                        icon: const Icon(Icons.clear),
                        tooltip: '清除定时',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 间隔设置
                  Row(
                    children: [
                      const Text('间隔(ms):'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _intervalController,
                          keyboardType: TextInputType.number,
                          enabled: !courseProvider.isRobbing,
                          decoration: InputDecoration(
                            hintText: '500',
                            helperText:
                                '实际间隔 ${courseProvider.robInterval.inMilliseconds}ms（200–60000）',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                          ),
                          onChanged: (value) {
                            final interval = int.tryParse(value);
                            if (interval != null && interval > 0) {
                              courseProvider.setRobInterval(
                                  Duration(milliseconds: interval));
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    OutlinedButton.icon(
                        onPressed: courseProvider.robTargets.isEmpty || courseProvider.isExporting
                            ? null
                            : () async {
                                try {
                                  final config =
                                      await courseProvider.exportRobConfig();
                                  if (context.mounted) {
                                    await showDialog<void>(
                                        context: context,
                                        builder: (_) =>
                                            CliExportDialog(config: config));
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ErrorDialog.showError(
                                        context: context, error: e);
                                  }
                                }
                              },
                        icon: const Icon(Icons.terminal),
                        label: Text(courseProvider.isExporting
                            ? '正在验证登录…' : '停止并导出 CLI 配置')),
                    if (courseProvider.hasUncertainActions)
                      TextButton(
                          onPressed: () async {
                            try {
                              await courseProvider.reconcileActions();
                            } catch (e) {
                              if (context.mounted) {
                                ErrorDialog.showError(
                                    context: context, error: e);
                              }
                            }
                          },
                          child: const Text('核对未确认结果')),
                    if (courseProvider.hasUncertainActions &&
                        !courseProvider.isRobbing &&
                        !courseProvider.isActing)
                      TextButton(
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                        title: const Text('确认已经人工核对'),
                                        content: const Text(
                                            '仅当你已在官网确认操作结果且不存在待处理请求时继续。清除标记后可以重新运行选课。'),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('取消')),
                                          FilledButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text('已核对，允许重新操作')),
                                        ]));
                            if (confirmed != true) return;
                            try {
                              await courseProvider
                                  .acknowledgeUncertainActions();
                            } catch (e) {
                              if (context.mounted) {
                                ErrorDialog.showError(
                                    context: context, error: e);
                              }
                            }
                          },
                          child: const Text('我已在官网核对')),
                  ]),
                ],
              ),
            ),
            if (courseProvider.automationError != null)
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(courseProvider.automationError!,
                      style: const TextStyle(color: Colors.red))),
            Expanded(
              child: courseProvider.robTargets.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_circle_outline,
                              size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('暂无抢课目标'),
                          const SizedBox(height: 8),
                          Text(
                            '在搜索课程页面添加课程到抢课列表',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: courseProvider.robTargets.length,
                      itemBuilder: (context, index) {
                        final target = courseProvider.robTargets[index];
                        final status =
                            courseProvider.robTargetStatuses[target['id']] ??
                                {};
                        return Column(children: [
                          CourseCard(
                            course: target,
                            priority: index + 1,
                            status: status.isEmpty ? null : status,
                            showDropButton: true,
                            showCountInfo: false,
                            onDrop: () {
                              courseProvider.removeRobTarget(target['id']);
                            },
                            showDetailedInfo: false,
                          ),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                    tooltip: '提高优先级',
                                    icon: const Icon(Icons.arrow_upward),
                                    onPressed:
                                        courseProvider.isRobbing || index == 0
                                            ? null
                                            : () => courseProvider
                                                .moveRobTarget(index, -1)),
                                IconButton(
                                    tooltip: '降低优先级',
                                    icon: const Icon(Icons.arrow_downward),
                                    onPressed: courseProvider.isRobbing ||
                                            index ==
                                                courseProvider
                                                        .robTargets.length -
                                                    1
                                        ? null
                                        : () => courseProvider.moveRobTarget(
                                            index, 1)),
                              ]),
                        ]);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
