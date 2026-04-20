import 'package:flutter/material.dart';
import 'package:gateeaseapp/login.dart';
import 'package:gateeaseapp/api_config.dart';

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

  // Helper to check if all in group are selected
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
        for (var s in students) {
          selectedStudentIds.remove(s['id']);
        }
      } else {
        for (var s in students) {
          selectedStudentIds.add(s['id']);
        }
      }
    });
  }

  Future<void> submitGroupPass() async {
    if (selectedStudentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one student'),
          backgroundColor: Colors.red,
        ),
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

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Group Pass Approved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('Group pass error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to approve group pass'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 223, 223, 224),
      appBar: AppBar(
        title: const Text('Group Pass'),
        backgroundColor: const Color.fromARGB(255, 223, 223, 224),
        elevation: 0,
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: classGroups.length,
                    itemBuilder: (context, index) {
                      final classGroup = classGroups[index];
                      final className = classGroup['class_name'] ?? 'Unknown';
                      final students = classGroup['students'] ?? [];

                      // Check checkbox state for group
                      bool allSelected = isGroupSelected(students);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            leading: Checkbox(
                              value: allSelected,
                              activeColor: Colors.blue,
                              onChanged: (val) {
                                toggleGroup(students);
                              },
                            ),
                            title: Text(
                              className,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                            subtitle: Text('${students.length} students'),
                            children: students.map<Widget>((student) {
                              final isSelected = selectedStudentIds.contains(
                                student['id'],
                              );
                              return CheckboxListTile(
                                value: isSelected,
                                activeColor: Colors.blue,
                                onChanged: (val) =>
                                    toggleSelection(student['id']),
                                title: Text(
                                  student['name'] ?? 'N/A',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                                secondary: CircleAvatar(
                                  backgroundColor: Colors.grey.shade200,
                                  child: Text(
                                    (student['name'] ?? 'U')[0].toUpperCase(),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        offset: const Offset(0, -4),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : submitGroupPass,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'Approve Selected (${selectedStudentIds.length})',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
