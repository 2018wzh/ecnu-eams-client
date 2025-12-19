import 'package:flutter/material.dart';

class CourseCard extends StatelessWidget {
  final Map<String, dynamic> course;
  final VoidCallback? onTap;
  final bool showDropButton;
  final VoidCallback? onDrop;

  const CourseCard({
    super.key,
    required this.course,
    this.onTap,
    this.showDropButton = false,
    this.onDrop,
  });

  @override
  Widget build(BuildContext context) {
    final courseInfo = course['course'] as Map<String, dynamic>?;
    final teachers = course['teachers'] as List?;
    final dateTimePlace = course['dateTimePlace'] as Map<String, dynamic>?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      course['course']['nameZh'] ??
                          course['course']['nameEn'] ??
                          '',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (showDropButton && onDrop != null)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: onDrop,
                    ),
                ],
              ),
              if (courseInfo != null) ...[
                const SizedBox(height: 8),
                Text('教学班: ${courseInfo['nameZh']} (${courseInfo['code']})'),
                Text('学分: ${courseInfo['credits']}'),
              ],
              if (teachers != null && teachers.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '教师: ${teachers.map((t) => t['nameZh']).join(', ')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (dateTimePlace != null) ...[
                const SizedBox(height: 8),
                Text(
                  dateTimePlace['textZh'] ?? '',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (course['limitCount'] != null) ...[
                const SizedBox(height: 8),
                Chip(
                  label: Text('名额: ${course['limitCount']}'),
                  avatar: const Icon(Icons.people, size: 18),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
