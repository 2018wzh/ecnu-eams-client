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
        _creditGte = cached['creditGte'];
        _creditLte = cached['creditLte'];
      });
    }
  }

  @override
  void dispose() {
    _teacherController.dispose();
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
              _creditGte = null;
              _creditLte = null;
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
              'creditGte': _creditGte?.toString(),
              'creditLte': _creditLte?.toString(),
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
