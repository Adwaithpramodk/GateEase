import 'package:flutter/material.dart';
import 'package:gateeaseapp/login.dart';
import 'package:gateeaseapp/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gateeaseapp/theme/app_theme.dart';

class GroupPassPage extends StatefulWidget {
  const GroupPassPage({super.key});

  @override
  State<GroupPassPage> createState() => _GroupPassPageState();
}

class _GroupPassPageState extends State<GroupPassPage> {
  List<dynamic> classGroups = [];
  bool isLoading = true;
  bool isSubmitting = false;
  final Set<int> selectedStudentIds = {};

  @override
  void initState() {
    super.initState();
    fetchStudents();
  }

  // ORIGINAL API PRESERVED:
  // GET '$baseurl/StudentListAPI/$lid'
  Future<void> fetchStudents() async {
    try {
      if (lid == null) {
        final prefs = await SharedPreferences.getInstance();
        lid = prefs.getInt('lid');
      }

      if (lid == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      final response = await dio.get('$baseurl/StudentListAPI/$lid');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final dynamic body = response.data;
        List<dynamic> groups = [];

        // Accept the original API's direct list response and common
        // wrapped-list response formats without changing the endpoint.
        if (body is List) {
          groups = List<dynamic>.from(body);
        } else if (body is Map) {
          final dynamic listData =
              body['data'] ?? body['classes'] ?? body['results'];
          if (listData is List) {
            groups = List<dynamic>.from(listData);
          }
        }

        debugPrint('GroupPass StudentListAPI response: $body');
        debugPrint('GroupPass class groups loaded: ${groups.length}');

        setState(() {
          classGroups = groups;
          isLoading = false;
        });
      } else {
        debugPrint(
          'StudentListAPI returned status: ${response.statusCode}',
        );
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('Fetch students error: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  void toggleSelection(int studentId) {
    setState(() {
      if (selectedStudentIds.contains(studentId)) {
        selectedStudentIds.remove(studentId);
      } else {
        selectedStudentIds.add(studentId);
      }
    });
  }

  bool isGroupSelected(List<dynamic> students) {
    if (students.isEmpty) return false;
    for (final student in students) {
      final id = int.tryParse(student['id'].toString());
      if (id == null || !selectedStudentIds.contains(id)) return false;
    }
    return true;
  }

  void toggleGroup(List<dynamic> students) {
    final allSelected = isGroupSelected(students);
    setState(() {
      for (final student in students) {
        final id = int.tryParse(student['id'].toString());
        if (id == null) continue;
        if (allSelected) {
          selectedStudentIds.remove(id);
        } else {
          selectedStudentIds.add(id);
        }
      }
    });
  }

  // ORIGINAL API PRESERVED:
  // POST '$baseurl/GroupPassAPI/$lid'
  // {'student_ids': selectedStudentIds.toList(), 'reason': 'Group Pass'}
  Future<void> submitGroupPass() async {
    if (selectedStudentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one student')),
      );
      return;
    }

    setState(() => isSubmitting = true);
    try {
      final response = await dio.post(
        '$baseurl/GroupPassAPI/$lid',
        data: {
          'student_ids': selectedStudentIds.toList(),
          'reason': 'Group Pass',
        },
      );

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group Pass approved successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Group pass error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to approve group pass')),
        );
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalStudents = classGroups.fold<int>(
      0,
      (total, group) =>
          total + ((group['students'] as List?)?.length ?? 0),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF7F6FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppTheme.textPrimary,
          ),
        ),
        title: const Text(
          'Group Pass',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : classGroups.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                        children: [
                          _buildInstructionCard(totalStudents),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              const Text(
                                'Select students',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${classGroups.length} classes',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 11),
                          ...classGroups.map(_buildClassCard),
                        ],
                      ),
                    ),
                    _buildBottomBar(),
                  ],
                ),
    );
  }

  Widget _buildInstructionCard(int totalStudents) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFECEAF5)),
      ),
      child: Row(
        children: [
          Container(
            height: 45,
            width: 45,
            decoration: BoxDecoration(
              color: const Color(0xFFEFEAFE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: AppTheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create a group pass',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalStudents students available. Select students individually or select an entire class.',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(dynamic classGroup) {
    final String className =
        classGroup['class_name']?.toString() ?? 'Unknown class';
    final List<dynamic> students =
        (classGroup['students'] as List?)?.cast<dynamic>() ?? [];
    final bool allSelected = isGroupSelected(students);
    final int selectedInGroup = students.where((student) {
      final id = int.tryParse(student['id'].toString());
      return id != null && selectedStudentIds.contains(id);
    }).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: allSelected
              ? AppTheme.primary.withValues(alpha: 0.35)
              : const Color(0xFFECEAF5),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF28204F).withValues(alpha: 0.035),
            blurRadius: 13,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: AppTheme.primary.withValues(alpha: 0.05),
        ),
        child: ExpansionTile(
          key: PageStorageKey<String>('group-$className'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          childrenPadding: const EdgeInsets.fromLTRB(13, 0, 13, 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(19),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(19),
          ),
          leading: InkWell(
            onTap: () => toggleGroup(students),
            borderRadius: BorderRadius.circular(9),
            child: _selectionBox(allSelected),
          ),
          title: Text(
            className,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '$selectedInGroup of ${students.length} selected',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1EFF9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${students.length}',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
          children: [
            const Divider(height: 1, color: Color(0xFFF0EEF7)),
            if (students.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No students in this class.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              )
            else
              ...students.map(_buildStudentTile),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentTile(dynamic student) {
    final int? id = int.tryParse(student['id'].toString());
    final bool selected = id != null && selectedStudentIds.contains(id);
    final String name = student['name']?.toString() ?? 'N/A';
    final String initials = name.trim().isEmpty
        ? 'U'
        : name.trim().substring(0, 1).toUpperCase();

    return InkWell(
      onTap: id == null ? null : () => toggleSelection(id),
      borderRadius: BorderRadius.circular(13),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 9),
        child: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: selected
                  ? const Color(0xFFEFEAFE)
                  : const Color(0xFFF2F1F7),
              child: Text(
                initials,
                style: TextStyle(
                  color: selected
                      ? AppTheme.primary
                      : AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            _selectionBox(selected),
          ],
        ),
      ),
    );
  }

  Widget _selectionBox(bool selected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 25,
      width: 25,
      decoration: BoxDecoration(
        color: selected ? AppTheme.primary : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? AppTheme.primary : const Color(0xFFD9D6E7),
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
          : null,
    );
  }

  Widget _buildBottomBar() {
    final int count = selectedStudentIds.length;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 13, 18, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            top: BorderSide(color: Color(0xFFECEAF5)),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF28204F).withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count selected',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Students for this group pass',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: isSubmitting || count == 0
                      ? null
                      : submitGroupPass,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppTheme.primary.withValues(alpha: 0.35),
                    elevation: 0,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          height: 19,
                          width: 19,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            count == 0 ? 'Select students' : 'Approve $count',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 35),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 86,
              width: 86,
              decoration: const BoxDecoration(
                color: Color(0xFFEFEAFE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.groups_2_outlined,
                color: AppTheme.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No students available',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Students assigned to your classes will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: () {
                setState(() => isLoading = true);
                fetchStudents();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}
