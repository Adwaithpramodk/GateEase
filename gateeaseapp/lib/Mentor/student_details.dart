import 'package:flutter/material.dart';
import 'package:gateeaseapp/login.dart';
import 'package:gateeaseapp/api_config.dart';
import 'package:gateeaseapp/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudentDetailsPage extends StatefulWidget {
  const StudentDetailsPage({super.key});

  @override
  State<StudentDetailsPage> createState() => _StudentDetailsPageState();
}

class _StudentDetailsPageState extends State<StudentDetailsPage> {
  List<dynamic> classGroups = [];
  bool isLoading = true;

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
          classGroups = (response.data as List).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Fetch students error: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Student Details',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : classGroups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline_rounded,
                          size: 60, color: AppTheme.textMuted),
                      const SizedBox(height: 12),
                      const Text('No students found',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 15)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: fetchStudents,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: classGroups.length,
                    itemBuilder: (context, index) {
                      final classGroup = classGroups[index];
                      final className =
                          classGroup['class_name']?.toString() ?? 'Unknown';
                      final studentCount = classGroup['student_count'] ?? 0;
                      final students =
                          (classGroup['students'] as List?) ?? [];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: AppTheme.cardDecoration,
                        child: Theme(
                          data: Theme.of(context)
                              .copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            collapsedShape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            leading: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryLight,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  studentCount.toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              className,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppTheme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                            subtitle: Text(
                              '$studentCount student${studentCount != 1 ? 's' : ''}',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            children: [
                              const Divider(height: 1),
                              ...students.map<Widget>((student) {
                                final initials =
                                    (student['name']?.toString() ?? '?')[0]
                                        .toUpperCase();
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 4),
                                  leading: CircleAvatar(
                                    backgroundColor: AppTheme.primaryLight,
                                    child: Text(initials,
                                        style: const TextStyle(
                                            color: AppTheme.primary,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  title: Text(
                                    student['name']?.toString() ?? 'N/A',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 2),
                                      Text(
                                          'Admn: ${student['admn_no']?.toString() ?? 'N/A'}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textSecondary)),
                                      Text(
                                          'Phone: ${student['phone']?.toString() ?? 'N/A'}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textSecondary)),
                                      if (student['email'] != null)
                                        Text(
                                          student['email'].toString(),
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.textMuted),
                                        ),
                                    ],
                                  ),
                                  isThreeLine: true,
                                );
                              }),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
