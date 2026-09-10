import 'package:flutter/material.dart';

class CourseCard extends StatelessWidget {
  final Map<String, dynamic> course;
  final VoidCallback? onTap;
  final bool showDropButton;
  final VoidCallback? onDrop;
  final bool showDetailedInfo;
  final bool showCountInfo;
  final Map<String, dynamic>? status; // 监控状态信息
  final int? priority; // 优先级
  final Map<String, dynamic>? countInfo; // 课程名额信息

  const CourseCard({
    super.key,
    required this.course,
    this.onTap,
    this.showDropButton = false,
    this.onDrop,
    this.showDetailedInfo = true,
    this.showCountInfo = false,
    this.status,
    this.priority,
    this.countInfo,
  });

  @override
  Widget build(BuildContext context) {
    final courseInfo = course['course'] as Map<String, dynamic>?;
    final teachers = course['teachers'] as List?;
    final dateTimePlace = course['dateTimePlace'] as Map<String, dynamic>?;
    final campus = course['campus'] as Map<String, dynamic>?;
    final department = course['department'] as Map<String, dynamic>?;
    final courseType = course['courseType'] as Map<String, dynamic>?;
    final courseProperty = course['courseProperty'] as Map<String, dynamic>?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行：课程名称 + 删除按钮
              Row(
                children: [
                  Expanded(
                    child: Text(
                      courseInfo?['nameZh'] ??
                          courseInfo?['nameEn'] ??
                          course['nameZh'] ??
                          course['nameEn'] ??
                          '未知课程',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  if (showDropButton && onDrop != null)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: onDrop,
                    ),
                ],
              ),

              const SizedBox(height: 8),

              // 基本信息行
              Row(
                children: [
                  // 教学班信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '教学班: ${course['code'] ?? course['lessonCode'] ?? '未知'}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (courseInfo != null) ...[
                          Text(
                            '课程代码: ${courseInfo['code'] ?? '未知'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            '学分: ${courseInfo['credits'] ?? '未知'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // 名额信息（如果显示）
                  if (showCountInfo)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getCountColor().shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _getCountColor().shade300),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 本专业名额
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.school,
                                  size: 14, color: Colors.blue),
                              const SizedBox(width: 4),
                              Text(
                                _getRegularCountText(),
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          // 跨专业名额
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.swap_horiz,
                                  size: 14, color: Colors.purple),
                              const SizedBox(width: 4),
                              Text(
                                _getAcrossMajorCountText(),
                                style: const TextStyle(
                                  color: Colors.purple,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              // 教师信息
              if (teachers != null && teachers.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.person, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        teachers
                            .map((t) => t['nameZh'] ?? t['nameEn'] ?? '未知')
                            .join(', '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],

              // 时间地点信息
              if (dateTimePlace != null) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.schedule, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        dateTimePlace['textZh'] ??
                            dateTimePlace['text'] ??
                            '未知',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],

              // 优先级信息
              if (priority != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.priority_high,
                          size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        '优先级: $priority',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (status != null && status!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: status!['phase'] == 'succeeded'
                        ? Colors.green.shade50
                        : status!['phase'] == 'uncertain' ||
                                status!['phase'] == 'failed'
                            ? Colors.orange.shade50
                            : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${status!['status']}',
                            style: const TextStyle(fontSize: 12)),
                        Text('尝试 ${status!['attemptCount'] ?? 0} 次',
                            style: const TextStyle(fontSize: 12)),
                        if (status!['lastRequestId'] != null)
                          SelectableText('请求: ${status!['lastRequestId']}',
                              style: const TextStyle(fontSize: 11)),
                        if (status!['lastChecked'] != null)
                          Text('更新: ${status!['lastChecked'].toLocal()}',
                              style: const TextStyle(fontSize: 11)),
                      ]),
                ),
              ],

              // 详细信息（可选显示）
              if (showDetailedInfo) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    // 校区信息
                    if (campus != null)
                      _buildInfoChip(
                        icon: Icons.location_on,
                        label: campus['nameZh'] ?? '未知校区',
                        color: Colors.green,
                      ),

                    // 开课部门
                    if (department != null)
                      _buildInfoChip(
                        icon: Icons.business,
                        label: department['nameZh'] ?? '未知部门',
                        color: Colors.orange,
                      ),

                    // 课程类型
                    if (courseType != null)
                      _buildInfoChip(
                        icon: Icons.category,
                        label: courseType['nameZh'] ?? '未知类型',
                        color: Colors.purple,
                      ),

                    // 课程属性
                    if (courseProperty != null)
                      _buildInfoChip(
                        icon: Icons.label,
                        label: courseProperty['nameZh'] ?? '未知属性',
                        color: Colors.teal,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  MaterialColor _getCountColor() {
    if (countInfo == null) return Colors.grey;

    final limitCount = course['limitCount'] as int? ?? 0;
    final stdCount = countInfo!['stdCount'] as int? ?? 0;
    final available = limitCount - stdCount;
    if (available > 10) return Colors.green;
    if (available > 0) return Colors.orange;
    return Colors.red;
  }

  String _getRegularCountText() {
    final limitCount = course['limitCount'] as int? ?? 0;
    if (countInfo == null) {
      return '人数未知';
    }

    final stdCount = countInfo!['stdCount'] as int? ?? 0;
    return '已选 $stdCount/$limitCount';
  }

  String _getAcrossMajorCountText() {
    final acrossMajorLimitCount = course['acrossMajorLimitCount'] as int?;
    if (countInfo == null) {
      return '人数未知';
    }

    final amStdCount = countInfo!['amStdCount'] as int? ?? 0;
    return '跨专业 $amStdCount/${acrossMajorLimitCount ?? '不限'}';
  }
}
