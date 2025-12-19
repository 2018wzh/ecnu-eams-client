import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/course_provider.dart';

class RobScreen extends StatefulWidget {
  const RobScreen({super.key});

  @override
  State<RobScreen> createState() => _RobScreenState();
}

class _RobScreenState extends State<RobScreen> {
  final TextEditingController _intervalController = TextEditingController();

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
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      final now = DateTime.now();
      final scheduledTime = DateTime(
        now.year,
        now.month,
        now.day,
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
                          courseProvider.isRobbing ? '抢课进行中...' : '抢课已停止',
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
                                ? '${courseProvider.scheduledStartTime!.hour.toString().padLeft(2, '0')}:${courseProvider.scheduledStartTime!.minute.toString().padLeft(2, '0')}'
                                : '选择时间',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () =>
                            courseProvider.setScheduledStartTime(null),
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
                          decoration: const InputDecoration(
                            hintText: '500',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
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
                ],
              ),
            ),
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
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(target['course']['nameZh'] ?? ''),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('优先级: ${target['priority']}'),
                                if (courseProvider.isRobbing &&
                                    status.isNotEmpty)
                                  Text(
                                    '状态: ${status['status']} | 余量: ${status['available']}/${status['limitCount']} | 已选: ${status['stdCount']}',
                                    style: TextStyle(
                                      color: status['available'] > 0
                                          ? Colors.green
                                          : Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                if (status['lastChecked'] != null)
                                  Text(
                                    '最后检查: ${status['lastChecked'].hour.toString().padLeft(2, '0')}:${status['lastChecked'].minute.toString().padLeft(2, '0')}:${status['lastChecked'].second.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.grey),
                                  ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                courseProvider.removeRobTarget(target['id']);
                              },
                            ),
                          ),
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
