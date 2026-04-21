import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gateeaseapp/Mentor/pending_pass.dart';
import 'package:gateeaseapp/Mentor/student_details.dart';
import 'package:gateeaseapp/Mentor/group_pass.dart';
import 'package:gateeaseapp/Mentor/report.dart';
import 'package:gateeaseapp/login.dart';
import 'package:gateeaseapp/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gateeaseapp/theme/app_theme.dart';
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
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    try {
      await NotificationService.initialize();
      String? token = await NotificationService.getFCMToken();
      if (token != null && lid != null) {
        String platform = Platform.isAndroid ? 'android' : 'ios';
        bool success = await NotificationApiService.registerDeviceToken(
          loginId: lid!,
          deviceToken: token,
          platform: platform,
        );
        if (success) debugPrint('✅ Push notifications enabled');
      }
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
      debugPrint('❌ Notification error: $e');
    }
  }

  Future<void> _loadAll() async {
    setState(() => isAnalyticsLoading = true);
    await Future.wait([getDetails(), fetchAnalytics()]);
    if (!mounted) return;
    setState(() => isAnalyticsLoading = false);
  }

  Future<void> getDetails() async {
    try {
      if (lid == null) {
        final prefs = await SharedPreferences.getInstance();
        lid = prefs.getInt('lid');
      }
      if (lid == null) return;

      final response = await dio.get('$baseurl/Mentorinfo_api/$lid');
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          if (response.data is List && (response.data as List).isNotEmpty) {
            details = response.data[0];
          } else if (response.data is Map) {
            details = response.data;
          }
        });
      }
    } catch (e) {
      debugPrint('Get Details Error: $e');
    }
  }

  String getStatus(Map<String, dynamic> pass) {
    if (pass['security_status'] == 'scanned') return 'Scanned';
    if (pass['mentor_status'] == 'rejected') return 'Rejected';
    if (pass['mentor_status'] == 'approved') return 'Approved';
    return 'Pending';
  }

  Future<void> logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => LoginPage()), (route) => false);
  }

  Future<void> fetchAnalytics() async {
    try {
      if (lid == null) {
        final prefs = await SharedPreferences.getInstance();
        lid = prefs.getInt('lid');
      }
      if (lid == null) return;

      final response = await dio.get('$baseurl/MentorPassAnalytics/$lid');
      if (!mounted) return;
      if (response.statusCode == 200) {
        passes = List<Map<String, String>>.from(
          response.data.map((e) => {
            'status': getStatus(e),
            'mentor_status': e['mentor_status'].toString(),
            'security_status': e['security_status'].toString(),
            'name': e['name'].toString(),
            'time': e['time'].toString(),
            'reason': e['reason'].toString(),
          }),
        );
      }
    } catch (e) {
      debugPrint('Analytics Error: $e');
    }
  }

  List<Map<String, String>> _byStatus(String status) =>
      passes.where((p) => p['status'] == status).toList();

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: isAnalyticsLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary))
            : RefreshIndicator(
                color: AppTheme.primary,
                onRefresh: _loadAll,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    _buildHeader(),
                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _sectionLabel('Quick Actions'),
                          const SizedBox(height: 16),
                          _actionGrid(),
                          const SizedBox(height: 32),
                          _sectionLabel('Pass Analytics'),
                          const SizedBox(height: 16),
                          _analyticsSection('Approved', AppTheme.success,
                              AppTheme.successLight, Icons.verified_rounded),
                          _analyticsSection('Scanned', AppTheme.accent,
                              AppTheme.accentLight,
                              Icons.qr_code_scanner_rounded),
                          _analyticsSection('Rejected', AppTheme.error,
                              AppTheme.errorLight, Icons.cancel_rounded),
                          const SizedBox(height: 40),
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
    final approved = _byStatus('Approved').length;
    final pending = _byStatus('Pending').length;

    return SliverAppBar(
      expandedHeight: 230,
      pinned: true,
      elevation: 0,
      backgroundColor: AppTheme.headerTop,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      automaticallyImplyLeading: false,
      title: const Text('Mentor Dashboard',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17)),
      actions: [
        GestureDetector(
          onTap: () => _showLogoutDialog(context),
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.logout_rounded,
                color: Colors.white, size: 18),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: 10,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                ),
              ),
              Positioned(
                right: 60,
                top: 70,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.15),
                        backgroundImage: details?['image'] != null
                            ? NetworkImage('$baseurl${details!['image']}')
                            : null,
                        child: details?['image'] == null
                            ? const Icon(Icons.person_rounded,
                                color: Colors.white70, size: 30)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Good day,',
                              style: TextStyle(
                                  color:
                                      Colors.white.withValues(alpha: 0.65),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 3),
                          Text(
                            details?['name'] ?? 'Loading...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              details?['departmentname'] ?? 'Faculty',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Mini stat badges
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _statBadge('$approved', 'Approved',
                            AppTheme.successLight, AppTheme.success),
                        const SizedBox(height: 6),
                        _statBadge(
                            '$pending', 'Pending', AppTheme.warningLight, AppTheme.warning),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statBadge(String count, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(count,
              style: TextStyle(
                  color: fg, fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.3,
            )),
      ],
    );
  }

  Widget _actionGrid() {
    final actions = [
      {
        'icon': Icons.people_alt_rounded,
        'label': 'Students',
        'subtitle': 'View details',
        'gradient': [const Color(0xFF7C3AED), const Color(0xFF5B21B6)],
        'onTap': () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const StudentDetailsPage())),
      },
      {
        'icon': Icons.pending_actions_rounded,
        'label': 'Pending',
        'subtitle': 'Review requests',
        'gradient': [const Color(0xFFD97706), const Color(0xFFB45309)],
        'onTap': () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PendingPassPage())),
      },
      {
        'icon': Icons.group_add_rounded,
        'label': 'Group Pass',
        'subtitle': 'Batch approve',
        'gradient': [const Color(0xFF0D9488), const Color(0xFF0F766E)],
        'onTap': () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const GroupPassPage())),
      },
      {
        'icon': Icons.analytics_rounded,
        'label': 'Reports',
        'subtitle': 'View analytics',
        'gradient': [const Color(0xFF4F46E5), const Color(0xFF4338CA)],
        'onTap': () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ReportPage())),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.35,
      ),
      itemCount: actions.length,
      itemBuilder: (context, i) {
        final a = actions[i];
        return GestureDetector(
          onTap: a['onTap'] as VoidCallback,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: a['gradient'] as List<Color>,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (a['gradient'] as List<Color>)[0]
                      .withValues(alpha: 0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(a['icon'] as IconData,
                        color: Colors.white, size: 20),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a['label'] as String,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
                      Text(a['subtitle'] as String,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 10,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _analyticsSection(
      String status, Color color, Color bgColor, IconData icon) {
    final list = _byStatus(status);
    final isExpanded = expandedStatus == status;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(
                () => expandedStatus = isExpanded ? null : status),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('$status Passes',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        )),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${list.length}',
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('No records',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
              )
            else
              ...list.map((p) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryLight,
                      child: Text(
                        (p['name'] ?? '?')[0].toUpperCase(),
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(p['name'] ?? 'Unknown',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    subtitle: Text(
                        '${p['reason']} · ${p['time']}',
                        style: const TextStyle(fontSize: 12)),
                  )),
          ],
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppTheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                    color: AppTheme.errorLight, shape: BoxShape.circle),
                child: const Icon(Icons.logout_rounded,
                    color: AppTheme.error, size: 28),
              ),
              const SizedBox(height: 20),
              const Text('Sign out?',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              const Text(
                'You will need to sign in again to access the mentor portal.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.border),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => logout(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error,
                        minimumSize: const Size(0, 50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Sign out',
                          style: TextStyle(fontWeight: FontWeight.w700)),
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
