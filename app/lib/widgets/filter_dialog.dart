import 'package:flutter/material.dart';
import '../providers/course_provider.dart';

class FilterDialog extends StatefulWidget {
  final Map<String, dynamic>? queryCondition;
  final CourseProvider courseProvider;

  const FilterDialog({
    super.key,
    this.queryCondition,
    required this.courseProvider,
  });

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  String? _selectedCampusId;
  String? _selectedCourseTypeId;
  String? _selectedCoursePropertyId;
  String? _selectedDepartmentId;
  String? _selectedMajorId;
  String? _selectedGrade;
  double? _creditGte;
  double? _creditLte;
  final TextEditingController _teacherController = TextEditingController();
  final TextEditingController _lessonController = TextEditingController();
  bool _onlyAvailable = false;
  bool _onlyWithCount = false;
  String? _selectedWeek;
  String _sortField = 'lesson';
  String _sortType = 'ASC';

  @override
  void initState() {
    super.initState();
    _loadCachedFilters();
  }

  void _loadCachedFilters() {
    final cached = widget.courseProvider.filterConditions;
    if (cached != null) {
      setState(() {
        _selectedCampusId = cached['campusId'];
        _selectedCourseTypeId = cached['courseTypeId'];
        _selectedCoursePropertyId = cached['coursePropertyId'];
        _selectedDepartmentId = cached['departmentId'];
        _selectedMajorId = cached['majorId'];
        _selectedGrade = cached['grade'];
        _teacherController.text = cached['teacherName'] ?? '';
        _lessonController.text = cached['lessonName'] ?? '';
        _creditGte = cached['creditGte'];
        _creditLte = cached['creditLte'];
        _onlyAvailable = cached['onlyAvailable'] ?? false;
        _onlyWithCount = cached['onlyWithCount'] ?? false;
        _selectedWeek = cached['week'];
        _sortField = cached['sortField'] ?? 'lesson';
        _sortType = cached['sortType'] ?? 'ASC';
      });
    }
  }

  @override
  void dispose() {
    _teacherController.dispose();
    _lessonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final condition = widget.queryCondition;
    if (condition == null) {
      return const AlertDialog(
        content: Text('加载筛选条件中...'),
      );
    }

    final campuses = condition['campuses'] as List? ?? [];
    final courseTypes = condition['courseTypes'] as List? ?? [];
    final courseProperties = condition['courseProperties'] as List? ?? [];
    final departments = condition['departments'] as List? ?? [];
    final majors = condition['majors'] as List? ?? [];
    final grades = condition['grades'] as List? ?? [];

    return AlertDialog(
      title: const Text('筛选条件'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 教师姓名
              const Text('教师姓名:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _teacherController,
                decoration: const InputDecoration(
                  hintText: '输入教师姓名',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 16),

              // 教学班名称
              const Text('教学班名称:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _lessonController,
                decoration: const InputDecoration(
                  hintText: '输入教学班名称或代码',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 16),

              // 年级
              if (grades.isNotEmpty) ...[
                const Text('年级:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: _selectedGrade,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('全部'),
                    ),
                    ...grades.map((grade) {
                      return DropdownMenuItem<String?>(
                        value: grade.toString(),
                        child: Text(grade.toString()),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedGrade = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],

              // 上课星期
              const Text('上课星期:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                initialValue: _selectedWeek,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('全部'),
                  ),
                  const DropdownMenuItem<String?>(
                    value: '1',
                    child: Text('星期一'),
                  ),
                  const DropdownMenuItem<String?>(
                    value: '2',
                    child: Text('星期二'),
                  ),
                  const DropdownMenuItem<String?>(
                    value: '3',
                    child: Text('星期三'),
                  ),
                  const DropdownMenuItem<String?>(
                    value: '4',
                    child: Text('星期四'),
                  ),
                  const DropdownMenuItem<String?>(
                    value: '5',
                    child: Text('星期五'),
                  ),
                  const DropdownMenuItem<String?>(
                    value: '6',
                    child: Text('星期六'),
                  ),
                  const DropdownMenuItem<String?>(
                    value: '7',
                    child: Text('星期日'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedWeek = value;
                  });
                },
              ),
              const SizedBox(height: 16),

              // 校区
              if (campuses.isNotEmpty) ...[
                const Text('校区:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: _selectedCampusId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('全部'),
                    ),
                    ...campuses.map((campus) {
                      final id = campus['id'].toString();
                      return DropdownMenuItem<String?>(
                        value: id,
                        child: Text(campus['nameZh'] ?? ''),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedCampusId = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],

              // 开课部门
              if (departments.isNotEmpty) ...[
                const Text('开课部门:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: _selectedDepartmentId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('全部'),
                    ),
                    ...departments.map((dept) {
                      final id = dept['id'].toString();
                      return DropdownMenuItem<String?>(
                        value: id,
                        child: Text(dept['nameZh'] ?? ''),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedDepartmentId = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],

              // 开课专业
              if (majors.isNotEmpty) ...[
                const Text('开课专业:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: _selectedMajorId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('全部'),
                    ),
                    ...majors.map((major) {
                      final id = major['id'].toString();
                      return DropdownMenuItem<String?>(
                        value: id,
                        child: Text(major['nameZh'] ?? ''),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedMajorId = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],

              // 课程性质
              if (courseTypes.isNotEmpty) ...[
                const Text('课程性质:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: _selectedCourseTypeId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('全部'),
                    ),
                    ...courseTypes.map((type) {
                      final id = type['id'].toString();
                      return DropdownMenuItem<String?>(
                        value: id,
                        child: Text(type['nameZh'] ?? ''),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedCourseTypeId = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],

              // 课程类型
              if (courseProperties.isNotEmpty) ...[
                const Text('课程类型:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: _selectedCoursePropertyId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('全部'),
                    ),
                    ...courseProperties.map((prop) {
                      final id = prop['id'].toString();
                      return DropdownMenuItem<String?>(
                        value: id,
                        child: Text(prop['nameZh'] ?? ''),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedCoursePropertyId = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],

              // 学分范围
              const Text('学分范围:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: '最低学分',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      keyboardType: TextInputType.number,
                      controller:
                          TextEditingController(text: _creditGte?.toString()),
                      onChanged: (value) {
                        _creditGte = double.tryParse(value);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text('至'),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: '最高学分',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      keyboardType: TextInputType.number,
                      controller:
                          TextEditingController(text: _creditLte?.toString()),
                      onChanged: (value) {
                        _creditLte = double.tryParse(value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 其他选项
              const Text('其他选项:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              CheckboxListTile(
                title: const Text('仅显示可选课程'),
                value: _onlyAvailable,
                onChanged: (value) {
                  setState(() {
                    _onlyAvailable = value ?? false;
                  });
                },
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                title: const Text('仅显示有余量课程'),
                value: _onlyWithCount,
                onChanged: (value) {
                  setState(() {
                    _onlyWithCount = value ?? false;
                  });
                },
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 16),

              // 排序选项
              const Text('排序方式:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _sortField,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'lesson',
                          child: Text('按教学班'),
                        ),
                        DropdownMenuItem(
                          value: 'course',
                          child: Text('按课程'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _sortField = value ?? 'lesson';
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _sortType,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'ASC',
                          child: Text('升序'),
                        ),
                        DropdownMenuItem(
                          value: 'DESC',
                          child: Text('降序'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _sortType = value ?? 'ASC';
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await widget.courseProvider.clearFilterConditions();
            setState(() {
              _selectedCampusId = null;
              _selectedCourseTypeId = null;
              _selectedCoursePropertyId = null;
              _selectedDepartmentId = null;
              _selectedMajorId = null;
              _selectedGrade = null;
              _teacherController.clear();
              _lessonController.clear();
              _creditGte = null;
              _creditLte = null;
              _onlyAvailable = false;
              _onlyWithCount = false;
              _selectedWeek = null;
              _sortField = 'lesson';
              _sortType = 'ASC';
            });
          },
          child: const Text('清除'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () async {
            final result = {
              'campusId': _selectedCampusId,
              'courseTypeId': _selectedCourseTypeId,
              'coursePropertyId': _selectedCoursePropertyId,
              'departmentId': _selectedDepartmentId,
              'majorId': _selectedMajorId,
              'grade': _selectedGrade,
              'teacherName': _teacherController.text,
              'lessonName': _lessonController.text,
              'creditGte': _creditGte?.toString(),
              'creditLte': _creditLte?.toString(),
              'onlyAvailable': _onlyAvailable,
              'onlyWithCount': _onlyWithCount,
              'week': _selectedWeek,
              'sortField': _sortField,
              'sortType': _sortType,
            };
            await widget.courseProvider.saveFilterConditions(result);
            if (mounted) {
              Navigator.pop(context, result);
            }
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}
