import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gateeaseapp/login.dart';
import 'package:gateeaseapp/student/complaint.dart';
import 'package:gateeaseapp/student/mypass.dart';
import 'package:gateeaseapp/student/new_pass.dart';
import 'package:gateeaseapp/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gateeaseapp/theme/app_theme.dart';
import 'package:dio/dio.dart';

class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key});

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage>
    with TickerProviderStateMixin {
  List<Map<String, String>> timeline = [];
  bool isLoading = true;
  Map<String, dynamic>? details;

  late AnimationController _headerAnim;
  late AnimationController _contentAnim;
  late Animation<double> _headerFade;
  late Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();
    _headerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _contentAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _headerFade = CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut);
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _contentAnim, curve: Curves.easeOut));
    _headerAnim.forward();
    fetchTimeline();
    getDetails();
  }

  @override
  void dispose() {
    _headerAnim.dispose();
    _contentAnim.dispose();
    super.dispose();
  }

  Future<void> getDetails() async {
    try {
      if (lid == null) {
        final prefs = await SharedPreferences.getInstance();
        lid = prefs.getInt('lid');
      }
      if (lid == null) return;

      final response = await dio.get('$baseurl/StudentInfo_api/$lid');
      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          if (response.data is List && (response.data as List).isNotEmpty) {
            details = response.data[0];
          } else if (response.data is Map) {
            details = response.data;
          }
        });
        _contentAnim.forward();
      }
    } catch (e) {
      debugPrint('Get Details Error: $e');
      if (mounted) {
        String errorMsg = 'Failed to load profile';
        if (e is DioException) {
          final status = e.response?.statusCode;
          final data = e.response?.data;
          if (status == 401) {
            errorMsg = 'Unauthenticated. Please re-login.';
          } else if (status == 403) {
            errorMsg = 'Unauthorized: ${data is Map ? data['error'] : 'Check token claims'}';
          } else if (status == 404) {
            errorMsg = 'Profile not found (404).';
          } else {
            errorMsg = 'Server Error ($status): ${e.message}';
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> fetchTimeline() async {
    try {
      if (lid == null) {
        final prefs = await SharedPreferences.getInstance();
        lid = prefs.getInt('lid');
      }
      if (lid == null) {
        setState(() => isLoading = false);
        return;
      }

      final response = await dio.get('$baseurl/ExitPassTimelineAPI/$lid/');
      if (response.statusCode == 200) {
        final data = response.data;
        List<Map<String, String>> temp = [];

        String formatTime(String? isoString) {
          if (isoString == null || isoString.isEmpty) return 'Pending';
          try {
            final DateTime dt = DateTime.parse(isoString).toLocal();
            int hour = dt.hour;
            int minute = dt.minute;
            String period = hour >= 12 ? 'PM' : 'AM';
            hour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
            String minuteStr = minute.toString().padLeft(2, '0');
            return '$hour:$minuteStr $period';
          } catch (e) {
            return isoString;
          }
        }

        temp.add({
          'title': 'Pass Requested',
          'time': formatTime(data['created_at']),
          'status': 'completed',
        });

        if (data['mentor_status'] == 'approved') {
          temp.add({
            'title': 'Mentor Approved',
            'time': formatTime(data['approved_at']),
            'status': 'completed',
          });
        } else if (data['mentor_status'] == 'rejected') {
          temp.add({
            'title': 'Mentor Rejected',
            'time': data['reject_reason'] ?? 'Rejected',
            'status': 'rejected',
          });
        } else {
          temp.add({
            'title': 'Awaiting Mentor',
            'time': 'Pending',
            'status': 'pending',
          });
        }

        if (data['mentor_status'] != 'rejected') {
          if (data['security_status'] == 'scanned' ||
              data['security_status'] == 'approved') {
            temp.add({
              'title': 'Security Scanned',
              'time': formatTime(data['scanned_at']),
              'status': 'completed',
            });
          } else {
            temp.add({
              'title': 'Awaiting Security',
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
      debugPrint('Fetch Timeline Error: $e');
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load pass history'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () async {
            await fetchTimeline();
            await getDetails();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _buildHeader(),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    SlideTransition(
                      position: _contentSlide,
                      child: Column(
                        children: [
                          _buildQuickActions(),
                          const SizedBox(height: 32),
                          _buildRecentActivity(),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      elevation: 0,
      backgroundColor: AppTheme.headerTop,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: Padding(
        padding: const EdgeInsets.only(left: 20),
        child: Center(
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: AppTheme.surface,
              size: 20,
            ),
          ),
        ),
      ),
      title: const Text(
        'GateEase',
        style: TextStyle(
          color: AppTheme.surface,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
      actions: [
        GestureDetector(
          onTap: () => _showLogoutDialog(context),
          child: Container(
            margin: const EdgeInsets.only(right: 20),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.logout_rounded,
              color: AppTheme.surface,
              size: 18,
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: FadeTransition(
          opacity: _headerFade,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1E1B4B),
                  AppTheme.headerMid,
                  AppTheme.primary,
                ],
              ),
            ),
            child: Stack(
              children: [
                // Decorative circles
                Positioned(
                  right: -30,
                  top: 20,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.surface.withValues(alpha: 0.04),
                    ),
                  ),
                ),
                Positioned(
                  right: 40,
                  top: 60,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.surface.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                // Content
                Positioned(
                  bottom: 24,
                  left: 20,
                  right: 20,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.surface.withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: AppTheme.surface.withValues(alpha: 0.15),
                          backgroundImage: details?['Photo'] != null
                              ? NetworkImage('$baseurl${details!['Photo']}')
                              : null,
                          child: details?['Photo'] == null
                              ? const Icon(
                                  Icons.person_rounded,
                                  size: 36,
                                  color: Colors.white70,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Welcome back,',
                              style: TextStyle(
                                color: AppTheme.surface.withValues(alpha: 0.65),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              details?['name'] ?? 'Loading...',
                              style: const TextStyle(
                                color: AppTheme.surface,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.surface.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                details?['dept'] ?? 'Student',
                                style: const TextStyle(
                                  color: AppTheme.surface,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E1B4B),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _actionCard(
                icon: Icons.add_circle_outline_rounded,
                label: 'New Pass',
                subtitle: 'Apply now',
                gradient: const [Color(0xFF4F46E5), Color(0xFF6366F1)],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ApplyPassPage()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionCard(
                icon: Icons.confirmation_number_outlined,
                label: 'My Passes',
                subtitle: 'View history',
                gradient: const [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const Mypasses()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _actionCard(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Support',
                subtitle: 'Report issue',
                gradient: const [AppTheme.warning, Color(0xFFFBBF24)],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ComplaintPage()),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.surface, size: 26),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.surface,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: AppTheme.surface.withValues(alpha: 0.75),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E1B4B),
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Latest pass',
                style: TextStyle(
                  color: Color(0xFF4F46E5),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
            ),
          )
        else if (timeline.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              children: [
                Icon(Icons.inbox_rounded, size: 48, color: Color(0xFFCBD5E1)),
                SizedBox(height: 12),
                Text(
                  'No active passes',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        else
          ...List.generate(timeline.length, (index) {
            final item = timeline[index];
            final bool isLast = index == timeline.length - 1;
            Color dotColor;
            Color bgColor;
            IconData statusIcon;
            if (item['status'] == 'completed') {
              dotColor = AppTheme.success;
              bgColor = AppTheme.successLight;
              statusIcon = Icons.check_circle_rounded;
            } else if (item['status'] == 'rejected') {
              dotColor = AppTheme.error;
              bgColor = AppTheme.errorLight;
              statusIcon = Icons.cancel_rounded;
            } else {
              dotColor = AppTheme.warning;
              bgColor = AppTheme.warningLight;
              statusIcon = Icons.schedule_rounded;
            }

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 32,
                    child: Column(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: bgColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(statusIcon, color: dotColor, size: 16),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Center(
                              child: Container(
                                width: 1.5,
                                color: AppTheme.border,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item['title']!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              item['time']!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppTheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppTheme.errorLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: AppTheme.error,
                  size: 28,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sign out?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E1B4B),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You will need to sign in again\nto access your account.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: AppTheme.border),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => logout(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error,
                        foregroundColor: AppTheme.surface,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Sign out',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
