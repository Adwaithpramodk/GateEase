import 'package:flutter/material.dart';
import 'package:gateeaseapp/login.dart';
import 'package:gateeaseapp/student/complaint.dart';
import 'package:gateeaseapp/student/mypass.dart';
import 'package:gateeaseapp/student/new_pass.dart';
import 'package:gateeaseapp/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key});

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  List<Map<String, String>> timeline = [];
  bool isLoading = true;
  Map<String, dynamic>? details;

  @override
  void initState() {
    super.initState();
    fetchTimeline();
    getDetails();
  }

  Future<void> getDetails() async {
    try {
      final response = await dio.get('$baseurl/StudentInfo_api/$lid');
      debugPrint('===========================>>>>>>>>${response.data}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          details = response.data;
        });
      }
    } catch (e) {
      debugPrint('Get Details Error: $e');
    }
  }

  Future<void> fetchTimeline() async {
    try {
      final response = await dio.get('$baseurl/ExitPassTimelineAPI/$lid/');
      debugPrint('====================>>>>>>${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;

        List<Map<String, String>> temp = [];

        // Helper to format ISO date string to time (e.g., 03:30 PM)
        String formatTime(String? isoString) {
          if (isoString == null || isoString.isEmpty) return 'Pending';
          try {
            final DateTime dt = DateTime.parse(isoString).toLocal();
            // Simple manual formatting to avoid heavy intl dependency if not already added
            // Or use intl if preferred. Let's use TimeOfDay-like formatting manually for simplicity
            int hour = dt.hour;
            int minute = dt.minute;
            String period = hour >= 12 ? 'PM' : 'AM';
            hour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
            String minuteStr = minute.toString().padLeft(2, '0');
            return '$hour:$minuteStr $period';
          } catch (e) {
            return isoString; // Return as is if parsing fails
          }
        }

        // 1️⃣ Pass Requested (always completed)
        temp.add({
          'title': 'Pass Requested',
          'time': formatTime(data['created_at']),
          'status': 'completed',
        });

        // 2️⃣ Mentor Approval / Rejection
        if (data['mentor_status'] == 'approved') {
          temp.add({
            'title': 'Pass Approved (Mentor)',
            'time': formatTime(data['approved_at']),
            'status': 'completed',
          });
        } else if (data['mentor_status'] == 'rejected') {
          temp.add({
            'title': 'Pass Rejected (Mentor)',
            'time': data['reject_reason'] ?? 'Rejected',
            'status': 'rejected',
          });
        } else {
          temp.add({
            'title': 'Pass Approved (Mentor)',
            'time': 'Pending',
            'status': 'pending',
          });
        }

        // 3️⃣ Security Scan (Only if not rejected)
        if (data['mentor_status'] != 'rejected') {
          if (data['security_status'] == 'scanned' ||
              data['security_status'] == 'approved') {
            temp.add({
              'title': 'Pass Scanned (Security)',
              'time': formatTime(data['scanned_at']),
              'status': 'completed',
            });
          } else {
            temp.add({
              'title': 'Pass Scanned (Security)',
              'time': 'Pending',
              'status': 'pending',
            });
          }
        }

        setState(() {
          timeline = temp;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Timeline fetch error: $e');
      isLoading = false;
    }
  }

  Future<void> logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F4F8),
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.home_outlined, color: Colors.black),
            SizedBox(width: 8),
            Text('Home', style: TextStyle(color: Colors.black)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.red),
                  ),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        logout(context);
                      },
                      child: const Text(
                        'Logout',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: () async {
          await fetchTimeline();
          await getDetails();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  // Responsive avatar size based on screen width
                  final avatarRadius = constraints.maxWidth * 0.1;
                  final fontSize = constraints.maxWidth * 0.04;

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: avatarRadius.clamp(35.0, 50.0),
                          backgroundColor: Colors.grey,
                          backgroundImage: details?['Photo'] != null
                              ? NetworkImage('$baseurl${details!['Photo']}')
                              : null,
                          child: details?['Photo'] == null
                              ? Icon(
                                  Icons.person,
                                  size: avatarRadius.clamp(30.0, 45.0),
                                  color: Colors.white,
                                )
                              : null,
                        ),

                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                details?['name'] ?? 'Loading...',
                                style: TextStyle(
                                  fontSize: fontSize.clamp(16.0, 20.0),
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Department: ${details?['dept'] ?? 'Loading...'}',
                                style: TextStyle(
                                  fontSize: fontSize.clamp(12.0, 14.0),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Batch: ${details?['stu_class'] ?? 'Loading...'}',
                                style: TextStyle(
                                  fontSize: fontSize.clamp(12.0, 14.0),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Admission NO: ${details?['admn_no'] ?? 'Loading...'}',
                                style: TextStyle(
                                  fontSize: fontSize.clamp(12.0, 14.0),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),
              const SizedBox(height: 24),

              // ================= ACTION BUTTONS =================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _actionButton(
                    context,
                    icon: Icons.history,
                    label: 'My Passes',
                    page: const Mypasses(),
                  ),
                  _actionButton(
                    context,
                    icon: Icons.add,
                    label: 'New Pass',
                    page: const ApplyPassPage(),
                  ),
                  _actionButton(
                    context,
                    icon: Icons.report_problem_outlined,
                    label: 'Complaint',
                    page: const ComplaintPage(),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Pass Timeline',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 16),

              if (isLoading)
                const CircularProgressIndicator()
              else if (timeline.isEmpty)
                const Text('No pass timeline available')
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: timeline.length,
                  itemBuilder: (context, index) {
                    final item = timeline[index];
                    final bool isLast = index == timeline.length - 1;

                    // // 🔑 COLOR LOGIC ONLY
                    // final bool isPending = item['status'] == 'pending';

                    // final Color iconColor = isPending
                    //     ? Colors.grey
                    //     : Colors.green;
                    // 🔑 COLOR LOGIC
                    Color iconColor;
                    if (item['status'] == 'completed') {
                      iconColor = Colors.green;
                    } else if (item['status'] == 'rejected') {
                      iconColor = Colors.red;
                    } else {
                      iconColor = Colors.grey;
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ===== ICON + LINE =====
                        Column(
                          children: [
                            Icon(
                              item['status'] == 'rejected'
                                  ? Icons.cancel
                                  : Icons.check_circle,
                              color: iconColor,
                              size: 26,
                            ),
                            if (!isLast)
                              Container(width: 2, height: 45, color: iconColor),
                          ],
                        ),

                        const SizedBox(width: 12),

                        // ===== CONTENT CARD (UNCHANGED UI) =====
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['title']!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item['time']!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Widget page,
  }) {
    // Get screen width for responsive sizing
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth = (screenWidth - 64) / 3; // 3 buttons + padding
    final buttonHeight = buttonWidth * 0.83; // Maintain aspect ratio
    final iconSize = buttonWidth * 0.25;
    final fontSize = buttonWidth * 0.12;

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      },
      child: Container(
        width: buttonWidth.clamp(100.0, 150.0),
        height: buttonHeight.clamp(80.0, 125.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: iconSize.clamp(24.0, 32.0)),
            SizedBox(height: buttonHeight * 0.04),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: fontSize.clamp(11.0, 14.0)),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
