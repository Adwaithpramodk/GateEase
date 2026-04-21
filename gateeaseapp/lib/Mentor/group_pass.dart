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
  Set<int> selectedStudentIds = {};
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    fetchStudents();
  }

  Future<void> fetchStudents() async {
    try {
      if (lid == null) {
        final prefs = await SharedPreferences.getInstance();
        lid = prefs.getInt('lid');
      }
      if (lid == null) {
        setState(() => isLoading = false);
        return;
      }
      final response = await dio.get('$baseurl/StudentListAPI/$lid');
      if (response.statusCode == 200) {
        setState(() {
          classGroups = response.data;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Fetch students error: $e');
      setState(() => isLoading = false);
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
    for (var s in students) {
      if (!selectedStudentIds.contains(s['id'])) return false;
    }
    return true;
  }

  void toggleGroup(List<dynamic> students) {
    bool allSelected = isGroupSelected(students);
    setState(() {
      if (allSelected) {
        for (var s in students) { selectedStudentIds.remove(s['id']); }
      } else {
        for (var s in students) { selectedStudentIds.add(s['id']); }
      }
    });
  }

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
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Group Pass',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : Column(
              children: [
                // Selection summary chip
                if (selectedStudentIds.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    color: AppTheme.primaryLight,
                    child: Row(
                      children: [
                        const Icon(Icons.people_rounded,
                            color: AppTheme.primary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '${selectedStudentIds.length} student${selectedStudentIds.length != 1 ? 's' : ''} selected',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: classGroups.length,
                    itemBuilder: (context, index) {
                      final classGroup = classGroups[index];
                      final className =
                          classGroup['class_name'] ?? 'Unknown';
                      final students =
                          (classGroup['students'] as List?) ?? [];
                      final allSelected = isGroupSelected(students);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: AppTheme.cardDecoration,
                        child: Theme(
                          data: Theme.of(context)
                              .copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            collapsedShape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            tilePadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            leading: GestureDetector(
                              onTap: () => toggleGroup(students),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: allSelected
                                      ? AppTheme.primary
                                      : AppTheme.surfaceAlt,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: allSelected
                                        ? AppTheme.primary
                                        : AppTheme.border,
                                    width: 2,
                                  ),
                                ),
                                child: allSelected
                                    ? const Icon(Icons.check_rounded,
                                        color: Colors.white, size: 16)
                                    : null,
                              ),
                            ),
                            title: Text(
                              className,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${students.length} student${students.length != 1 ? 's' : ''}',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12),
                            ),
                            children: [
                              const Divider(height: 1),
                              ...students.map<Widget>((student) {
                                final isSelected = selectedStudentIds
                                    .contains(student['id']);
                                final initials =
                                    (student['name'] ?? 'U')[0].toUpperCase();
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 4),
                                  leading: CircleAvatar(
                                    backgroundColor: isSelected
                                        ? AppTheme.primaryLight
                                        : AppTheme.surfaceAlt,
                                    child: Text(
                                      initials,
                                      style: TextStyle(
                                        color: isSelected
                                            ? AppTheme.primary
                                            : AppTheme.textSecondary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    student['name'] ?? 'N/A',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: GestureDetector(
                                    onTap: () =>
                                        toggleSelection(student['id']),
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppTheme.primary
                                            : AppTheme.surfaceAlt,
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppTheme.primary
                                              : AppTheme.border,
                                          width: 2,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(Icons.check_rounded,
                                              color: Colors.white, size: 16)
                                          : null,
                                    ),
                                  ),
                                  onTap: () =>
                                      toggleSelection(student['id']),
                                );
                              }),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Bottom action bar
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    border: Border(
                        top: BorderSide(color: AppTheme.border)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: isSubmitting ? null : submitGroupPass,
                    child: isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : Text(selectedStudentIds.isEmpty
                            ? 'Select Students to Approve'
                            : 'Approve ${selectedStudentIds.length} Student${selectedStudentIds.length != 1 ? 's' : ''}'),
                  ),
                ),
              ],
            ),
    );
  }
}
