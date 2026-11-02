import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gateeaseapp/Mentor/pending_pass.dart';

import 'package:gateeaseapp/Mentor/group_pass.dart';
import 'package:gateeaseapp/Mentor/report.dart';
import 'package:gateeaseapp/login.dart';
import 'package:gateeaseapp/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gateeaseapp/theme/app_theme.dart';
import 'package:gateeaseapp/services/notification_service.dart';
import 'package:gateeaseapp/services/notification_api_service.dart';
import 'dart:io' show Platform;
import 'package:dio/dio.dart';

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
    _loadAll().then((_) {
      if (mounted) _initializeNotifications();
    });
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
      if (mounted) {
        String errorMsg = 'Failed to load mentor profile';
        if (e is DioException) {
          final status = e.response?.statusCode;
          if (status == 403) {
            errorMsg = 'Session expired. Please re-login.';
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  String getStatus(Map<String, dynamic> pass) {
    final securityStatus =
    (pass['security_status'] ?? '').toString().toLowerCase();
    final mentorStatus =
    (pass['mentor_status'] ?? '').toString().toLowerCase();

    if (securityStatus == 'scanned') return 'Scanned';
    if (mentorStatus == 'rejected') return 'Rejected';
    if (mentorStatus == 'approved') return 'Approved';
    return 'Pending';
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
          response.data.map(
                (e) => {
              'status': getStatus(e),
              'mentor_status': e['mentor_status'].toString(),
              'security_status': e['security_status'].toString(),
              'name': e['name'].toString(),
              'time': e['time'].toString(),
              'reason': (e['reason'] ?? '').toString(),
              'created_at': (e['created_at'] ?? '').toString(),
              'is_group_pass': (e['is_group_pass'] ?? false).toString(),
            },
          ),
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
        drawer: _buildDrawer(),
        body: isAnalyticsLoading
            ? const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        )
            : RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: _loadAll,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 34),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildWelcomeStrip(),
                    const SizedBox(height: 22),
                    _sectionHeading(
                      'Quick actions',
                      'Open the tools you use most',
                    ),
                    const SizedBox(height: 12),
                    _quickActions(),
                    const SizedBox(height: 25),
                    _buildPendingRequests(),
                    const SizedBox(height: 25),
                    _sectionHeading(
                      'Pass activity',
                      'A summary of processed requests',
                    ),
                    const SizedBox(height: 11),
                    _analyticsSection(
                      'Approved',
                      AppTheme.success,
                      AppTheme.successLight,
                      Icons.verified_rounded,
                    ),
                    _analyticsSection(
                      'Scanned',
                      AppTheme.accent,
                      AppTheme.accentLight,
                      Icons.qr_code_scanner_rounded,
                    ),
                    _analyticsSection(
                      'Rejected',
                      AppTheme.error,
                      AppTheme.errorLight,
                      Icons.cancel_rounded,
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

  Widget _buildWelcomeStrip() {
    final pendingCount = _byStatus('Pending').length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.inbox_rounded,
              color: AppTheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your pass requests',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  pendingCount == 0
                      ? 'You are all caught up'
                      : '$pendingCount request${pendingCount == 1 ? '' : 's'} waiting for review',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: pendingCount > 0
                  ? AppTheme.accentLight
                  : AppTheme.successLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$pendingCount pending',
              style: TextStyle(
                color: pendingCount > 0
                    ? AppTheme.accent
                    : AppTheme.success,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, String>> _latestPendingPasses() {
    final pending = _byStatus('Pending').toList();
    pending.sort((a, b) {
      final dateA = DateTime.tryParse(a['created_at'] ?? '');
      final dateB = DateTime.tryParse(b['created_at'] ?? '');
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });
    return pending.take(5).toList();
  }

  Widget _quickActions() {
    final actions = [

      {
        'title': 'Pending passes',
        'subtitle': 'Review new requests',
        'icon': Icons.pending_actions_rounded,
        'color': AppTheme.accent,
        'background': AppTheme.accentLight,
        'page': const PendingPassPage(),
      },
      {
        'title': 'Group pass',
        'subtitle': 'Manage group requests',
        'icon': Icons.group_add_rounded,
        'color': AppTheme.success,
        'background': AppTheme.successLight,
        'page': const GroupPassPage(),
      },
      {
        'title': 'Reports',
        'subtitle': 'View pass reports',
        'icon': Icons.analytics_rounded,
        'color': AppTheme.error,
        'background': AppTheme.errorLight,
        'page': const ReportPage(),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 11,
        mainAxisSpacing: 11,
        mainAxisExtent: 112,
      ),
      itemBuilder: (context, index) {
        final action = actions[index];
        final color = action['color'] as Color;
        final background = action['background'] as Color;
        return Material(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(17),
          child: InkWell(
            onTap: () => _openMentorPage(action['page'] as Widget),
            borderRadius: BorderRadius.circular(17),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: background,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          action['icon'] as IconData,
                          color: color,
                          size: 18,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_outward_rounded,
                        color: AppTheme.textSecondary.withValues(alpha: 0.7),
                        size: 15,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    action['title'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    action['subtitle'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatRequestDate(String rawDate) {
    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) return 'Recently requested';
    final local = parsed.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${local.day} ${months[local.month - 1]} • '
        '${local.hour % 12 == 0 ? 12 : local.hour % 12}:'
        '${local.minute.toString().padLeft(2, '0')} '
        '${local.hour >= 12 ? 'PM' : 'AM'}';
  }

  Widget _buildPendingRequests() {
    final recent = _latestPendingPasses();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _sectionHeading(
                'Latest pending requests',
                'The 5 most recent requests assigned to you',
              ),
            ),
            TextButton(
              onPressed: () => _openMentorPage(const PendingPassPage()),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text(
                'View all',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: AppTheme.border),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.035),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: recent.isEmpty
              ? Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 28,
            ),
            child: Center(
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: AppTheme.successLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: AppTheme.success,
                      size: 25,
                    ),
                  ),
                  const SizedBox(height: 11),
                  const Text(
                    'No pending requests',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'New requests will appear here.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          )
              : Column(
            children: [
              for (int i = 0; i < recent.length; i++) ...[
                _pendingRequestTile(recent[i]),
                if (i != recent.length - 1)
                  Divider(
                    height: 1,
                    indent: 66,
                    endIndent: 15,
                    color: AppTheme.border,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _pendingRequestTile(Map<String, String> pass) {
    final studentName = (pass['name'] ?? 'Unknown student').trim();
    final reason = (pass['reason'] ?? 'No reason provided').trim();
    final isGroup = pass['is_group_pass'] == 'true';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Center(
              child: Text(
                studentName.isEmpty ? '?' : studentName[0].toUpperCase(),
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        studentName.isEmpty ? 'Unknown student' : studentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (isGroup)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Text(
                          'GROUP',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  reason.isEmpty ? 'No reason provided' : reason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 12,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      pass['time'] ?? '--',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 11),
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 11,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _formatRequestDate(pass['created_at'] ?? ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.accentLight,
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Text(
              'PENDING',
              style: TextStyle(
                color: AppTheme.accent,
                fontSize: 8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppTheme.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 13, 20, 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'GATEEASE  /  MENTOR',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.3,
                      ),
                    ),
                  ),
                  Builder(
                    builder: (headerContext) => Material(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(13),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(13),
                        onTap: () => Scaffold.of(headerContext).openDrawer(),
                        child: const SizedBox(
                          width: 43,
                          height: 43,
                          child: Icon(
                            Icons.menu_rounded,
                            color: Colors.white,
                            size: 23,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              const Text(
                'Mentor Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Welcome back, ${details?['name'] ?? 'Mentor'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 19),
              Row(
                children: [
                  _headerMetric(
                    'PENDING',
                    _byStatus('Pending').length.toString(),
                    Icons.hourglass_top_rounded,
                  ),
                  const SizedBox(width: 10),
                  _headerMetric(
                    'APPROVED',
                    _byStatus('Approved').length.toString(),
                    Icons.verified_rounded,
                  ),
                  const SizedBox(width: 10),
                  _headerMetric(
                    'SCANNED',
                    _byStatus('Scanned').length.toString(),
                    Icons.qr_code_scanner_rounded,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerMetric(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 15),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.76),
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    final mentorName = details?['name']?.toString() ?? 'Mentor';
    final department = details?['departmentname']?.toString() ?? 'Faculty';
    final image = details?['image'];

    return Drawer(
      width: 300,
      backgroundColor: AppTheme.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
              child: Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  gradient: AppTheme.headerGradient,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.20),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.65),
                              width: 1.5,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 27,
                            backgroundColor: Colors.white.withValues(alpha: 0.18),
                            backgroundImage: image != null
                                ? NetworkImage('$baseurl$image')
                                : null,
                            child: image == null
                                ? const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 27,
                            )
                                : null,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'MENTOR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Text(
                      mentorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.school_outlined,
                          size: 13,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            department,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.82),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'WORKSPACE',
                style: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.85),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 9),
            _drawerItem(
              icon: Icons.dashboard_rounded,
              title: 'Dashboard',
              selected: true,
              onTap: () => Navigator.pop(context),
            ),

            _drawerItem(
              icon: Icons.pending_actions_rounded,
              title: 'Pending Passes',
              onTap: () => _openMentorPage(const PendingPassPage()),
            ),
            _drawerItem(
              icon: Icons.group_add_rounded,
              title: 'Group Pass',
              onTap: () => _openMentorPage(const GroupPassPage()),
            ),
            _drawerItem(
              icon: Icons.analytics_rounded,
              title: 'Reports',
              onTap: () => _openMentorPage(const ReportPage()),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: AppTheme.border),
                ),
                child: _drawerItem(
                  icon: Icons.logout_rounded,
                  title: 'Logout',
                  danger: true,
                  onTap: () {
                    Navigator.pop(context);
                    _showLogoutDialog(context);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool selected = false,
    bool danger = false,
  }) {
    final itemColor = danger
        ? AppTheme.error
        : selected
        ? AppTheme.primary
        : AppTheme.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? AppTheme.primaryLight : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(icon, size: 20, color: itemColor),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: itemColor,
                      fontSize: 13,
                      fontWeight: selected || danger
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppTheme.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openMentorPage(Widget page) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }



  Widget _sectionHeading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.25,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }


  Widget _analyticsSection(
      String status,
      Color color,
      Color bgColor,
      IconData icon,
      ) {
    final list = _byStatus(status);
    final isExpanded = expandedStatus == status;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () =>
                setState(() => expandedStatus = isExpanded ? null : status),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: color, size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$status Passes',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${list.length} ${list.length == 1 ? 'record' : 'records'}',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '${list.length}',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.textSecondary,
                    size: 21,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            Divider(height: 1, color: AppTheme.border),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'No records available',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              )
            else
              ...list.map(
                    (pass) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: AppTheme.primaryLight,
                        child: Text(
                          (pass['name'] ?? '?').isNotEmpty
                              ? pass['name']![0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pass['name'] ?? 'Unknown',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${pass['reason']} · ${pass['time']}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
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
                decoration: const BoxDecoration(
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
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You will need to sign in again to access the mentor portal.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
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