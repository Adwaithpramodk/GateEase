import 'package:flutter/material.dart';
import 'package:gateeaseapp/Mentor/pending_pass.dart';
import 'package:gateeaseapp/Mentor/student_details.dart';
import 'package:gateeaseapp/Mentor/group_pass.dart';
import 'package:gateeaseapp/Mentor/report.dart';
import 'package:gateeaseapp/login.dart';
import 'package:gateeaseapp/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gateeaseapp/services/notification_service.dart';
import 'package:gateeaseapp/services/notification_api_service.dart';
import 'dart:io' show Platform;

class MentorHomePage extends StatefulWidget {
  const MentorHomePage({super.key});

  @override
  State<MentorHomePage> createState() => _MentorHomePageState();
}

class _MentorHomePageState extends State<MentorHomePage> {
  String? expandedStatus;

  List<Map<String, String>> passes = [];
  Map<String, dynamic>? details;

  bool isAnalyticsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _initializeNotifications(); // Initialize push notifications
  }

  // ================= INITIALIZE NOTIFICATIONS =================
  Future<void> _initializeNotifications() async {
    try {
      // Initialize notification service
      await NotificationService.initialize();

      // Get FCM token
      String? token = await NotificationService.getFCMToken();

      if (token != null && lid != null) {
        // Get platform (android or ios)
        String platform = Platform.isAndroid ? 'android' : 'ios';

        // Register token with backend
        bool success = await NotificationApiService.registerDeviceToken(
          loginId: lid!,
          deviceToken: token,
          platform: platform,
        );

        if (success) {
          debugPrint('✅ Push notifications enabled successfully');
        }
      }

      // Listen for token refresh
      NotificationService.listenToTokenRefresh((newToken) async {
        if (lid != null) {
          String platform = Platform.isAndroid ? 'android' : 'ios';
          await NotificationApiService.registerDeviceToken(
            loginId: lid!,
            deviceToken: newToken,
            platform: platform,
          );
        }
      });
    } catch (e) {
      debugPrint('❌ Notification initialization error: $e');
    }
  }

  // ================= LOAD ALL =================
  Future<void> _loadAll() async {
    setState(() => isAnalyticsLoading = true);
    await Future.wait([getDetails(), fetchAnalytics()]);
    if (!mounted) return;
    setState(() => isAnalyticsLoading = false);
  }

  // ================= PROFILE =================
  Future<void> getDetails() async {
    try {
      final response = await dio.get('$baseurl/Mentorinfo_api/$lid');
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() => details = response.data);
      }
    } catch (e) {
      debugPrint('Get Details Error: $e');
    }
  }

  // ================= STATUS LOGIC =================
  String getStatus(Map<String, dynamic> pass) {
    if (pass['security_status'] == 'scanned') return 'Scanned';
    if (pass['mentor_status'] == 'rejected') return 'Rejected';
    if (pass['mentor_status'] == 'approved') return 'Approved';
    return 'Pending';
  }

  // ================= LOGOUT =================
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

  // ================= ANALYTICS =================
  Future<void> fetchAnalytics() async {
    try {
      final response = await dio.get('$baseurl/MentorPassAnalytics/$lid');
      if (!mounted) return;

      if (response.statusCode == 200) {
        passes = List<Map<String, String>>.from(
          response.data.map((e) {
            return {
              "status": getStatus(e),
              "mentor_status": e['mentor_status'].toString(),
              "security_status": e['security_status'].toString(),
              "name": e['name'].toString(),
              "time": e['time'].toString(),
              "reason": e['reason'].toString(),
            };
          }),
        );
      }
    } catch (e) {
      debugPrint("Analytics Error: $e");
    }
  }

  // ================= FILTER =================
  List<Map<String, String>> _byStatus(String status) {
    return passes.where((p) => p['status'] == status).toList();
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 223, 223, 224),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 223, 223, 224),
        elevation: 0,
        centerTitle: true,
        title: const Text('Home', style: TextStyle(color: Colors.black)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.red),
                  ),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => logout(context),
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
      body: isAnalyticsLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _profileCard(),
                    _buttons(),
                    _analyticsSection(
                      'Approved',
                      Colors.blue,
                      Icons.check_circle,
                    ),
                    _analyticsSection(
                      'Scanned',
                      Colors.green,
                      Icons.qr_code_scanner,
                    ),
                    _analyticsSection('Rejected', Colors.red, Icons.cancel),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  // ================= PROFILE CARD =================
  Widget _profileCard() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final avatarRadius = constraints.maxWidth * 0.08;
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
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: details?['image'] != null
                      ? NetworkImage('$baseurl${details!['image']}')
                      : null,
                  child: details?['image'] == null
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
                      // Text(
                      //   'Phone: ${details?['phone'] ?? 'Loading...'}',
                      //   style: TextStyle(fontSize: fontSize.clamp(12.0, 14.0)),
                      //   overflow: TextOverflow.ellipsis,
                      // ),
                      Text(
                        'Department: ${details?['departmentname'] ?? 'Loading...'}',
                        style: TextStyle(fontSize: fontSize.clamp(12.0, 14.0)),
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
    );
  }

  // ================= BUTTONS =================
  Widget _buttons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Wrap(
        spacing: 20,
        runSpacing: 20,
        alignment: WrapAlignment.center,
        children: [
          _squareButton(Icons.school, 'Student\nDetails', () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StudentDetailsPage()),
            );
          }),
          _squareButton(Icons.assignment_outlined, 'Pending\nPass', () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PendingPassPage()),
            );
          }),
          _squareButton(Icons.group_add, 'Group\nPass', () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GroupPassPage()),
            );
          }),
          _squareButton(Icons.assessment, 'Exit\nReport', () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReportPage()),
            );
          }),
        ],
      ),
    );
  }

  // ================= ANALYTICS =================
  Widget _analyticsSection(String status, Color color, IconData icon) {
    final list = _byStatus(status);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
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
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              title: Text(
                '$status Passes',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      list.length.toString(),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    expandedStatus == status
                        ? Icons.expand_less
                        : Icons.expand_more,
                  ),
                ],
              ),
              onTap: () {
                setState(() {
                  expandedStatus = expandedStatus == status ? null : status;
                });
              },
            ),
            if (expandedStatus == status && list.isNotEmpty)
              Column(children: list.map(_passTile).toList()),
            if (expandedStatus == status && list.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No records available',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ================= PASS TILE =================
  Widget _passTile(Map<String, String> p) {
    return ListTile(
      leading: const Icon(Icons.person),
      title: Text(p['name'] ?? 'Unknown'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Time: ${p['time']}"),
          Text("Reason: ${p['reason']}"),
          Text(
            "Mentor: ${p['mentor_status']} | Security: ${p['security_status']}",
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _squareButton(IconData icon, String text, VoidCallback onPressed) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Get screen width for responsive sizing
        final screenWidth = MediaQuery.of(context).size.width;
        final buttonWidth = (screenWidth - 80) / 2; // 2 buttons per row
        final buttonHeight = buttonWidth * 0.55;
        final iconSize = buttonWidth * 0.18;
        final fontSize = buttonWidth * 0.09;

        return GestureDetector(
          onTap: onPressed,
          child: Container(
            width: buttonWidth.clamp(140.0, 200.0),
            height: buttonHeight.clamp(85.0, 110.0),
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
                SizedBox(height: buttonHeight * 0.06),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: fontSize.clamp(12.0, 15.0)),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
