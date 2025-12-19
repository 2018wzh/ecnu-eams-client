import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/course_provider.dart';
import '../widgets/course_card.dart';

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  final TextEditingController _intervalController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final courseProvider = context.read<CourseProvider>();
    _intervalController.text =
        courseProvider.monitorInterval.inSeconds.toString();
  }

  @override
  void dispose() {
    _intervalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, CourseProvider>(
      builder: (context, authProvider, courseProvider, _) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: courseProvider.isMonitoring
                  ? Colors.blue.shade50
                  : Colors.grey.shade100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        courseProvider.isMonitoring
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: courseProvider.isMonitoring
                            ? Colors.blue
                            : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          courseProvider.isMonitoring ? '监控进行中...' : '监控已停止',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Switch(
                        value: courseProvider.isMonitoring,
                        onChanged: (value) {
                          if (value) {
                            if (authProvider.studentID == null ||
                                authProvider.currentTurn == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('请先选择选课轮次')),
                              );
                              return;
                            }

                            if (courseProvider.monitorTargets.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('请先添加监控目标')),
                              );
                              return;
                            }

                            courseProvider.startMonitoring(
                              int.parse(authProvider.studentID!),
                              authProvider.currentTurn!['id'],
                            );
                          } else {
                            courseProvider.stopMonitoring();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 监控间隔设置
                  Row(
                    children: [
                      const Text('间隔(s):'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _intervalController,
                          keyboardType: TextInputType.number,
                          enabled: !courseProvider.isMonitoring,
                          decoration: const InputDecoration(
                            hintText: '5',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                          ),
                          onChanged: (value) {
                            final interval = int.tryParse(value);
                            if (interval != null && interval > 0) {
                              courseProvider.setMonitorInterval(
                                  Duration(seconds: interval));
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: courseProvider.monitorTargets.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.monitor,
                              size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('暂无监控目标'),
                          const SizedBox(height: 8),
                          Text(
                            '在搜索课程页面添加课程到监控列表',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: courseProvider.monitorTargets.length,
                      itemBuilder: (context, index) {
                        final target = courseProvider.monitorTargets[index];
                        final status = courseProvider
                                .monitorTargetStatuses[target['id']] ??
                            {};
                        return CourseCard(
                          course: target,
                          priority: target['priority'],
                          status:
                              courseProvider.isMonitoring && status.isNotEmpty
                                  ? status
                                  : null,
                          countInfo: status.isNotEmpty
                              ? {
                                  'stdCount': status['stdCount'] ?? 0,
                                  'amStdCount': 0, // 监控目标可能没有跨专业信息
                                }
                              : null,
                          showDropButton: true,
                          showCountInfo: true,
                          onDrop: () {
                            courseProvider.removeMonitorTarget(target['id']);
                          },
                          showDetailedInfo: false,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
