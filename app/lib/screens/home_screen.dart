import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/course_provider.dart';
import '../utils/error_dialog.dart';
import '../services/api_service.dart';
import 'course_search_screen.dart';
import 'selected_courses_screen.dart';
import 'rob_screen.dart';
import 'monitor_screen.dart';
import 'about_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final courseProvider = Provider.of<CourseProvider>(context, listen: false);

    try {
      await authProvider.loadStudentInfo();

      if (authProvider.currentTurn != null) {
        final turnID = authProvider.currentTurn!['id'] as int;
        await courseProvider.loadQueryCondition(turnID);
        if (authProvider.studentID != null) {
          await courseProvider.loadSelectedCourses(
            turnID,
            int.parse(authProvider.studentID!),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorDialog.showError(
          context: context,
          error: e,
          title: '加载数据失败',
          onConfirm: () => _loadData(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ECNU选课系统'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: '关于',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '退出登录',
            onPressed: () async {
              final authProvider =
                  Provider.of<AuthProvider>(context, listen: false);
              await authProvider.logout();
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _TurnSelector(),
          CourseSearchScreen(),
          SelectedCoursesScreen(),
          RobScreen(),
          MonitorScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_today),
            label: '选课轮次',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            label: '搜索课程',
          ),
          NavigationDestination(
            icon: Icon(Icons.book),
            label: '已选课程',
          ),
          NavigationDestination(
            icon: Icon(Icons.flash_on),
            label: '抢课',
          ),
          NavigationDestination(
            icon: Icon(Icons.visibility),
            label: '监控',
          ),
        ],
      ),
    );
  }
}

class _TurnSelector extends StatefulWidget {
  const _TurnSelector();

  @override
  State<_TurnSelector> createState() => _TurnSelectorState();
}

class _TurnSelectorState extends State<_TurnSelector> {
  bool _isLoadingCourses = false;

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, CourseProvider>(
      builder: (context, authProvider, courseProvider, _) {
        if (authProvider.errorMessage != null && authProvider.turns == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  authProvider.errorMessage!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await authProvider.loadStudentInfo();
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
                  label: const Text('重试'),
                ),
              ],
            ),
          );
        }

        if (authProvider.turns == null || authProvider.turns!.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        return Stack(
          children: [
            ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: authProvider.turns!.length,
              itemBuilder: (context, index) {
                final turn = authProvider.turns![index];
                final isSelected =
                    authProvider.currentTurn?['id'] == turn['id'];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: isSelected ? Colors.blue.shade50 : null,
                  child: ListTile(
                    title: Text(turn['name'] ?? ''),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text('开放时间: ${turn['openDateTimeText'] ?? ''}'),
                        Text('选课时间: ${turn['selectDateTimeText'] ?? ''}'),
                        if (turn['bulletin'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              turn['bulletin'],
                              style: const TextStyle(fontSize: 12),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Colors.blue)
                        : const Icon(Icons.radio_button_unchecked),
                    onTap: () async {
                      if (isSelected) return; // 已经是当前轮次

                      setState(() {
                        _isLoadingCourses = true;
                      });

                      try {
                        authProvider.setCurrentTurn(turn);

                        // 加载筛选条件
                        await courseProvider.loadQueryCondition(turn['id']);

                        // 加载已选课程
                        if (authProvider.studentID != null) {
                          await courseProvider.loadSelectedCourses(
                            turn['id'],
                            int.parse(authProvider.studentID!),
                          );
                        }

                        // 加载所有课程（第一页，无筛选条件）
                        final selectDetail = await ApiService().getSelectDetail(
                          int.parse(authProvider.studentID!),
                          turn['id'],
                        );
                        final semesterID = (selectDetail['semester']
                            as Map<String, dynamic>)['id'] as int;

                        await courseProvider.searchCourses(
                          studentID: int.parse(authProvider.studentID!),
                          turnID: turn['id'],
                          semesterID: semesterID,
                          pageNo: 1,
                        );

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('已选择: ${turn['name']}，并加载了课程数据')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ErrorDialog.showError(
                            context: context,
                            error: e,
                            title: '加载课程数据失败',
                          );
                        }
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isLoadingCourses = false;
                          });
                        }
                      }
                    },
                  ),
                );
              },
            ),
            if (_isLoadingCourses)
              Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        '正在加载课程数据...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
