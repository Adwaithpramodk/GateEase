import 'package:flutter/material.dart';
import 'package:gateeaseapp/login.dart';
import 'package:gateeaseapp/api_config.dart';

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

  // ================= FETCH STUDENTS =================
  Future<void> fetchStudents() async {
    try {
      if (lid == null) {
        setState(() => isLoading = false);
        return;
      }
      final response = await dio.get('$baseurl/StudentListAPI/$lid');
      debugPrint(response.data.toString());
      if (response.statusCode == 200) {
        setState(() {
          classGroups = (response.data as List).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Fetch students error: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 223, 223, 224),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 223, 223, 224),
        elevation: 0,
        title: const Text('Student Details'),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : classGroups.isEmpty
          ? const Center(child: Text('No students found'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: classGroups.length,
              itemBuilder: (context, index) {
                final classGroup = classGroups[index];
                final className =
                    classGroup['class_name']?.toString() ?? 'Unknown';
                final studentCount = classGroup['student_count'] ?? 0;
                final students = (classGroup['students'] as List?) ?? [];

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
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          studentCount.toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      title: Text(
                        className,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      subtitle: Text(
                        '$studentCount student${studentCount != 1 ? 's' : ''}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      children: [
                        // Student list
                        ...students.map<Widget>((student) {
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: Colors.grey.shade300,
                              child: Text(
                                (student['name']?.toString() ?? '?')[0]
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              student['name']?.toString() ?? 'N/A',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'Admn No: ${student['admn_no']?.toString() ?? 'N/A'}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Phone: ${student['phone']?.toString() ?? 'N/A'}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (student['email'] != null)
                                  Text(
                                    student['email'].toString(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
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
    );
  }
}
