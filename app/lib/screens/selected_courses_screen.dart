import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/course_provider.dart';
import '../utils/error_dialog.dart';
import '../widgets/course_card.dart';

class SelectedCoursesScreen extends StatelessWidget {
  const SelectedCoursesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, CourseProvider>(
      builder: (context, authProvider, courseProvider, _) {
        if (authProvider.currentTurn == null) {
          return const Center(
            child: Text('请先选择选课轮次'),
          );
        }

        if (courseProvider.selectedCourses.isEmpty &&
            !courseProvider.isLoading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.book_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('暂无已选课程'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await courseProvider.loadSelectedCourses(
                        authProvider.currentTurn!['id'],
                        int.parse(authProvider.studentID!),
                      );
                    } catch (e) {
                      if (context.mounted) {
                        ErrorDialog.showError(
                          context: context,
                          error: e,
                          title: '加载失败',
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('刷新'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            if (authProvider.studentID != null) {
              try {
                await courseProvider.loadSelectedCourses(
                  authProvider.currentTurn!['id'],
                  int.parse(authProvider.studentID!),
                );
              } catch (e) {
                if (context.mounted) {
                  ErrorDialog.showError(
                    context: context,
                    error: e,
                    title: '刷新失败',
                  );
                }
              }
            }
          },
          child: courseProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: courseProvider.selectedCourses.length,
                  itemBuilder: (context, index) {
                    final course = courseProvider.selectedCourses[index];
                    return CourseCard(
                      course: course,
                      showDropButton: true,
                      onDrop: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('确认退课'),
                            content: Text(
                                '确定要退选 ${course['course']['nameZh'] ?? course['course']['nameEn']} 吗？'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('取消'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('确认',
                                    style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true &&
                            authProvider.studentID != null) {
                          final success = await courseProvider.dropCourse(
                            int.parse(authProvider.studentID!),
                            authProvider.currentTurn!['id'],
                            course['id'],
                          );

                          if (context.mounted) {
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('退课成功'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              ErrorDialog.showApiError(
                                context: context,
                                message: courseProvider.errorMessage ?? '退课失败',
                              );
                            }
                          }
                        }
                      },
                    );
                  },
                ),
        );
      },
    );
  }
}
