import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/course_provider.dart';
import '../utils/error_dialog.dart';
import '../widgets/course_card.dart';
import '../widgets/filter_dialog.dart';
import '../services/api_service.dart';

class CourseSearchScreen extends StatefulWidget {
  const CourseSearchScreen({super.key});

  @override
  State<CourseSearchScreen> createState() => _CourseSearchScreenState();
}

class _CourseSearchScreenState extends State<CourseSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService();
  String? _selectedCampusId;
  String? _selectedCourseTypeId;
  String? _selectedCoursePropertyId;
  String? _selectedDepartmentId;
  String? _selectedMajorId;
  String? _selectedGrade;
  String? _teacherName;
  String? _lessonName;
  String? _creditGte;
  String? _creditLte;
  String? _selectedWeek;
  bool _onlyAvailable = false;
  bool _onlyWithCount = false;
  String _sortField = 'lesson';
  String _sortType = 'ASC';

  bool _hasSearchFilters() {
    return _searchController.text.isNotEmpty ||
        _selectedCampusId != null ||
        _selectedCourseTypeId != null ||
        _selectedCoursePropertyId != null ||
        _selectedDepartmentId != null ||
        _selectedMajorId != null ||
        _selectedGrade != null ||
        _teacherName != null ||
        _lessonName != null ||
        _creditGte != null ||
        _creditLte != null ||
        _selectedWeek != null ||
        _onlyAvailable ||
        _onlyWithCount;
  }

  Future<void> _search({int pageNo = 1}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final courseProvider = Provider.of<CourseProvider>(context, listen: false);

    if (authProvider.studentID == null || authProvider.currentTurn == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择选课轮次')),
      );
      return;
    }

    final turn = authProvider.currentTurn!;

    try {
      // 获取学期ID
      final selectDetail = await _apiService.getSelectDetail(
        int.parse(authProvider.studentID!),
        turn['id'],
      );
      final semesterID =
          (selectDetail['semester'] as Map<String, dynamic>)['id'] as int;

      await courseProvider.searchCourses(
        studentID: int.parse(authProvider.studentID!),
        turnID: turn['id'],
        semesterID: semesterID,
        courseName: _searchController.text,
        teacherName: _teacherName,
        lessonName: _lessonName,
        campusId: _selectedCampusId,
        courseTypeId: _selectedCourseTypeId,
        coursePropertyId: _selectedCoursePropertyId,
        departmentId: _selectedDepartmentId,
        majorId: _selectedMajorId,
        grade: _selectedGrade,
        week: _selectedWeek,
        creditGte: _creditGte,
        creditLte: _creditLte,
        onlyAvailable: _onlyAvailable,
        onlyWithCount: _onlyWithCount,
        sortField: _sortField,
        sortType: _sortType,
        pageNo: pageNo,
      );

      // 如果搜索后出现错误，显示弹窗
      if (courseProvider.errorMessage != null && mounted) {
        ErrorDialog.showApiError(
          context: context,
          message: courseProvider.errorMessage!,
          onRetry: () => _search(pageNo: pageNo),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorDialog.showError(
          context: context,
          error: e,
          title: '搜索失败',
          onConfirm: () => _search(pageNo: pageNo),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, CourseProvider>(
      builder: (context, authProvider, courseProvider, _) {
        // 初始化筛选条件缓存
        if (courseProvider.filterConditions != null &&
            _selectedCampusId == null) {
          final cached = courseProvider.filterConditions!;
          _selectedCampusId = cached['campusId'];
          _selectedCourseTypeId = cached['courseTypeId'];
          _selectedCoursePropertyId = cached['coursePropertyId'];
          _selectedDepartmentId = cached['departmentId'];
          _selectedMajorId = cached['majorId'];
          _selectedGrade = cached['grade'];
          _teacherName = cached['teacherName'];
          _lessonName = cached['lessonName'];
          _creditGte = cached['creditGte'] as String?;
          _creditLte = cached['creditLte'] as String?;
          _selectedWeek = cached['week'];
          _onlyAvailable = cached['onlyAvailable'] ?? false;
          _onlyWithCount = cached['onlyWithCount'] ?? false;
          _sortField = cached['sortField'] ?? 'lesson';
          _sortType = cached['sortType'] ?? 'ASC';
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: '搜索课程名称或代码',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: () async {
                      if (authProvider.currentTurn == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('请先选择选课轮次')),
                        );
                        return;
                      }

                      final turnID = authProvider.currentTurn!['id'];
                      await courseProvider.loadQueryCondition(turnID);

                      if (courseProvider.queryCondition == null) {
                        await courseProvider.loadQueryCondition(turnID);
                      }

                      final result = await showDialog<Map<String, Object?>>(
                        context: context,
                        builder: (context) => FilterDialog(
                          queryCondition: courseProvider.queryCondition,
                          courseProvider: courseProvider,
                        ),
                      );

                      if (result != null) {
                        setState(() {
                          _selectedCampusId = result['campusId'] as String?;
                          _selectedCourseTypeId =
                              result['courseTypeId'] as String?;
                          _selectedCoursePropertyId =
                              result['coursePropertyId'] as String?;
                          _selectedDepartmentId =
                              result['departmentId'] as String?;
                          _selectedMajorId = result['majorId'] as String?;
                          _selectedGrade = result['grade'] as String?;
                          _teacherName = result['teacherName'] as String?;
                          _lessonName = result['lessonName'] as String?;
                          _creditGte = result['creditGte'] as String?;
                          _creditLte = result['creditLte'] as String?;
                          _selectedWeek = result['week'] as String?;
                          _onlyAvailable =
                              (result['onlyAvailable'] as bool?) ?? false;
                          _onlyWithCount =
                              (result['onlyWithCount'] as bool?) ?? false;
                          _sortField =
                              (result['sortField'] as String?) ?? 'lesson';
                          _sortType = (result['sortType'] as String?) ?? 'ASC';
                        });
                        _search();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _search,
                  ),
                ],
              ),
            ),
            Expanded(
              child: courseProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : courseProvider.errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 64, color: Colors.red),
                              const SizedBox(height: 16),
                              Text(
                                courseProvider.errorMessage!,
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  _search();
                                },
                                icon: const Icon(Icons.refresh),
                                label: const Text('重试'),
                              ),
                            ],
                          ),
                        )
                      : courseProvider.courses.isEmpty && !_hasSearchFilters()
                          ? const Center(
                              child: Text('暂无课程，请尝试搜索'),
                            )
                          : courseProvider.courses.isEmpty &&
                                  _hasSearchFilters()
                              ? const Center(
                                  child: Text('未找到匹配的课程，请调整筛选条件'),
                                )
                              : Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      child: Text(
                                        '共找到 ${courseProvider.totalRows} 门课程',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ),
                                    Expanded(
                                      child: ListView.builder(
                                        padding: const EdgeInsets.all(16),
                                        itemCount:
                                            courseProvider.courses.length,
                                        itemBuilder: (context, index) {
                                          final course =
                                              courseProvider.courses[index];
                                          return CourseCard(
                                            course: course,
                                            onTap: () {
                                              _showCourseDetail(course,
                                                  authProvider, courseProvider);
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                    if (courseProvider.totalPages > 1)
                                      Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.chevron_left),
                                              onPressed:
                                                  courseProvider.currentPage > 1
                                                      ? () {
                                                          _search(
                                                              pageNo: courseProvider
                                                                      .currentPage -
                                                                  1);
                                                        }
                                                      : null,
                                            ),
                                            Text(
                                              '${courseProvider.currentPage} / ${courseProvider.totalPages}',
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.chevron_right),
                                              onPressed: courseProvider
                                                          .currentPage <
                                                      courseProvider.totalPages
                                                  ? () {
                                                      _search(
                                                          pageNo: courseProvider
                                                                  .currentPage +
                                                              1);
                                                    }
                                                  : null,
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
            ),
          ],
        );
      },
    );
  }

  void _showCourseDetail(
    Map<String, dynamic> course,
    AuthProvider authProvider,
    CourseProvider courseProvider,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CourseDetailSheet(
        course: course,
        authProvider: authProvider,
        courseProvider: courseProvider,
      ),
    );
  }
}

class CourseDetailSheet extends StatefulWidget {
  final Map<String, dynamic> course;
  final AuthProvider authProvider;
  final CourseProvider courseProvider;

  const CourseDetailSheet({
    super.key,
    required this.course,
    required this.authProvider,
    required this.courseProvider,
  });

  @override
  State<CourseDetailSheet> createState() => _CourseDetailSheetState();
}

class _CourseDetailSheetState extends State<CourseDetailSheet> {
  Map<String, dynamic>? _countInfo;
  bool _isLoadingCount = false;

  @override
  void initState() {
    super.initState();
    _loadCountInfo();
  }

  Future<void> _loadCountInfo() async {
    setState(() {
      _isLoadingCount = true;
    });

    final countInfo =
        await widget.courseProvider.getCountInfo(widget.course['id']);
    setState(() {
      _countInfo = countInfo;
      _isLoadingCount = false;
    });
  }

  Future<void> _addCourse() async {
    if (widget.authProvider.studentID == null ||
        widget.authProvider.currentTurn == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择选课轮次')),
      );
      return;
    }

    final success = await widget.courseProvider.addCourse(
      int.parse(widget.authProvider.studentID!),
      widget.authProvider.currentTurn!['id'],
      widget.course['id'],
      widget.course['virtualCost'] ?? 0,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('选课成功！'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ErrorDialog.showApiError(
          context: context,
          message: widget.courseProvider.errorMessage ?? '选课失败',
          onRetry: () => _addCourse(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final courseInfo = course['course'] as Map<String, dynamic>?;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                course['nameZh'] ?? course['code'] ?? '',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              if (courseInfo != null) ...[
                Text('课程代码: ${courseInfo['code']}'),
                Text('学分: ${courseInfo['credits']}'),
              ],
              const Divider(),
              if (_isLoadingCount)
                const Center(child: CircularProgressIndicator())
              else if (_countInfo != null) ...[
                Text(
                  '名额信息',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text('总名额: ${_countInfo!['limitCount']}'),
                Text('已选: ${_countInfo!['stdCount']}'),
                Text(
                    '剩余: ${(_countInfo!['limitCount'] as int) - (_countInfo!['stdCount'] as int)}'),
                const Divider(),
              ],
              if (course['dateTimePlace'] != null)
                Text('时间地点: ${course['dateTimePlace']['textZh']}'),
              if (course['teachers'] != null) ...[
                const SizedBox(height: 8),
                Text(
                    '教师: ${(course['teachers'] as List).map((t) => t['nameZh']).join(', ')}'),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _addCourse,
                  icon: const Icon(Icons.add),
                  label: const Text('选课'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final result = await showDialog<String>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('选择操作'),
                        content: const Text('您想要将此课程添加到哪个列表？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, 'rob'),
                            child: const Text('抢课列表'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, 'monitor'),
                            child: const Text('监控列表'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('取消'),
                          ),
                        ],
                      ),
                    );

                    if (result == 'rob') {
                      widget.courseProvider.addRobTarget(widget.course);
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已添加到抢课列表')),
                        );
                      }
                    } else if (result == 'monitor') {
                      widget.courseProvider.addMonitorTarget(widget.course);
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已添加到监控列表')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.add_circle),
                  label: const Text('添加到列表'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
