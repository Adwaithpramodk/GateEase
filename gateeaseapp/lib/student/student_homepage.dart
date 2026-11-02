import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:gateeaseapp/student/complaint.dart';
import 'package:gateeaseapp/api_config.dart';
import 'package:gateeaseapp/login.dart';
import 'package:gateeaseapp/student/mypass.dart';
import 'package:gateeaseapp/student/new_pass.dart';
import 'package:gateeaseapp/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gateeaseapp/student/announcement_page.dart';
class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key});

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage>
    with TickerProviderStateMixin {
  // Colours matched to the existing student_home.html design.
  static const Color _webPrimary = Color(0xFF6D4AE5);
  static const Color _webPrimaryDark = Color(0xFF5632C9);
  static const Color _webPrimaryLight = Color(0xFFEFEAFE);
  static const Color _webBackground = Color(0xFFF7F6FC);
  static const Color _webTextPrimary = Color(0xFF1B1840);
  static const Color _webTextSecondary = Color(0xFF6C6A86);
  static const Color _webBorder = Color(0xFFE8E6F5);
  List<Map<String, String>> timeline = [];
  bool isLoading = true;
  Map<String, dynamic>? details;
  Map<String, dynamic>? latestPassDetails;

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
      final response = await dio.get('$baseurl/StudentInfo_api/$lid');
      if (response.statusCode == 200) {
        setState(() {
          if (response.data is Map) {
            details = response.data;
          }
        });
        _contentAnim.forward();
      }
    } catch (e) {
      if (e is DioException && e.response != null) {
        final status = e.response!.statusCode;
        final data = e.response!.data;
        String errorMsg = 'Failed to load profile';
        if (status == 401) {
          errorMsg = 'Unauthenticated. Please re-login.';
        } else if (status == 403) {
          errorMsg =
          'Unauthorized: ${data is Map ? data['error'] : 'Check token claims'}';
        } else if (status == 404) {
          errorMsg = 'Profile not found (404).';
        } else {
          errorMsg = 'Error $status';
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: AppTheme.error,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
      debugPrint('Get Details Error: $e');
    }
  }

  Future<void> fetchTimeline() async {
    setState(() => isLoading = true);
    try {
      final response = await dio.get('$baseurl/ExitPassTimelineAPI/$lid/');
      final data = response.data;
      List<Map<String, String>> temp = [];

      Map<String, dynamic>? passDetails;
      if (data is List) {
        temp = List<Map<String, String>>.from(
          data.map((x) => Map<String, String>.from(x)),
        );
        if (data.isNotEmpty && data.first is Map) {
          passDetails = Map<String, dynamic>.from(data.first as Map);
        }
      } else if (data is Map && data.containsKey('id') && data['id'] != -1) {
        passDetails = Map<String, dynamic>.from(data);
        // Process single pass object into timeline
        String formatTime(String? isoString) {
          if (isoString == null || isoString.isEmpty) return 'Pending';
          try {
            final dt = DateTime.parse(isoString).toLocal();
            final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
            final min = dt.minute.toString().padLeft(2, '0');
            final period = dt.hour < 12 ? 'AM' : 'PM';
            return '$hour:$min $period';
          } catch (_) {
            return 'Pending';
          }
        }

        final mentorStatus = data['mentor_status']?.toString() ?? 'pending';
        final securityStatus = data['security_status']?.toString() ?? 'pending';
        final createdAt = data['created_at']?.toString() ?? '';
        final approvedAt = data['approved_at']?.toString() ?? '';
        final scannedAt = data['scanned_at']?.toString() ?? '';

        String mentorStatusDisplay = 'pending';
        if (mentorStatus == 'approved') mentorStatusDisplay = 'completed';
        if (mentorStatus == 'rejected') mentorStatusDisplay = 'rejected';

        String securityStatusDisplay = 'pending';
        if (securityStatus == 'scanned') securityStatusDisplay = 'completed';
        if (securityStatus == 'rejected') securityStatusDisplay = 'rejected';

        temp = [
          {
            'title': 'Pass Requested',
            'time': formatTime(createdAt),
            'status': 'completed',
          },
          {
            'title': 'Mentor Review',
            'time': mentorStatus == 'pending'
                ? 'Pending'
                : formatTime(approvedAt),
            'status': mentorStatusDisplay,
          },
          {
            'title': 'Security Scan',
            'time': securityStatus == 'pending'
                ? 'Pending'
                : formatTime(scannedAt),
            'status': securityStatusDisplay,
          },
        ];
      } else {
        // 'No pass found' or id: -1
        temp = [];
      }

      if (mounted) {
        setState(() {
          timeline = temp;
          latestPassDetails = passDetails;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      debugPrint('Timeline error: $e');
    }
  }

  Future<void> logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clear all session data including tokens
    if (context.mounted) {
      Navigator.pop(context);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
      );
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: AppTheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.error, Color(0xFFFF6B6B)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.error.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sign out?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You will need to sign in again\nto access your account.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: const BorderSide(color: AppTheme.border),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
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
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Sign Out',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
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

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _webBackground,
        drawer: _buildStudentDrawer(),
        drawerEnableOpenDragGesture: true,
        body: RefreshIndicator(
          color: _webPrimary,
          backgroundColor: Colors.white,
          onRefresh: () async {
            await fetchTimeline();
            await getDetails();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _buildHeader(),
              SliverToBoxAdapter(
                child: SlideTransition(
                  position: _contentSlide,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileCard(),
                        const SizedBox(height: 24),
                        _buildRecentActivity(),
                        const SizedBox(height: 16),
                        _buildRecentPassDetails(),
                        const SizedBox(height: 18),
                        _buildDashboardFooter(),
                      ],
                    ),
                  ),
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
      expandedHeight: 224,
      pinned: true,
      floating: false,
      snap: false,
      forceElevated: true,
      elevation: 0,
      scrolledUnderElevation: 5,
      shadowColor: const Color(0x26000000),
      surfaceTintColor: Colors.transparent,
      backgroundColor: _webPrimaryDark,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      automaticallyImplyLeading: false,
      leadingWidth: 58,
      leading: Builder(
        builder: (drawerContext) => IconButton(
          tooltip: 'Open student navigation',
          onPressed: () => Scaffold.of(drawerContext).openDrawer(),
          icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 25),
        ),
      ),
      title: const Text(
        'GateEase',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF7650EA), Color(0xFF6240D8)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -85,
                top: -225,
                child: Container(
                  width: 350,
                  height: 350,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.13),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -35,
                top: -175,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.13),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 28,
                child: FadeTransition(
                  opacity: _headerFade,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'STUDENT PORTAL',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Your campus journey',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Manage your exit passes in one place.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        height: 42,
                        child: ElevatedButton.icon(
                          onPressed: () => _openStudentPage(const ApplyPassPage()),
                          icon: const Icon(Icons.add_rounded, size: 19),
                          label: const Text('New Pass'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _webPrimaryDark,
                            elevation: 2,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentDrawer() {
    final studentName = details?['name']?.toString() ?? 'Student';
    final className = details?['class_name']?.toString() ??
        details?['dept']?.toString() ??
        'No class assigned';
    final photo = details?['Photo']?.toString();

    return Drawer(
      width: 285,
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 27),
              child: Row(
                children: [
                  Expanded(
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                          color: _webTextPrimary,
                        ),
                        children: [
                          TextSpan(text: 'Gate'),
                          TextSpan(
                            text: 'Ease',
                            style: TextStyle(color: _webPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close navigation',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: _webTextSecondary,
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                'STUDENT PORTAL',
                style: TextStyle(
                  color: Color(0xFFA5A3BA),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            _drawerItem(
              icon: Icons.home_rounded,
              title: 'Home',
              selected: true,
              onTap: () => Navigator.pop(context),
            ),
            _drawerItem(
              icon: Icons.add_circle_outline_rounded,
              title: 'Apply for New Pass',
              onTap: () => _openStudentPage(const ApplyPassPage(), closeDrawer: true),
            ),
            _drawerItem(
              icon: Icons.description_outlined,
              title: 'My Passes',
              onTap: () => _openStudentPage(const Mypasses(), closeDrawer: true),
            ),
            _drawerItem(
              icon: Icons.notifications_none_rounded,
              title: 'Announcements',
              onTap: () => _openStudentPage(
                const AnnouncementPage(),
                closeDrawer: true,
              ),
            ),
            _drawerItem(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Complaints & Help',
              onTap: () => _openStudentPage(const ComplaintPage(), closeDrawer: true),
            ),
            const Spacer(),
            const Divider(height: 1, color: _webBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _webPrimaryLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _webPrimaryLight, width: 2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: photo != null && photo.isNotEmpty
                        ? Image.network(
                      photo.startsWith('http') ? photo : '$baseurl$photo',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _studentInitial(studentName),
                    )
                        : _studentInitial(studentName),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          studentName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _webTextPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          className,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFA5A3BA),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _drawerItem(
              icon: Icons.logout_rounded,
              title: 'Logout',
              color: const Color(0xFFD84A4A),
              onTap: () => _showLogoutDialog(context),
            ),
            const SizedBox(height: 12),
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
    Color color = _webTextSecondary,
  }) {
    final itemColor = selected ? _webPrimary : color;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? _webPrimaryLight : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          minTileHeight: 46,
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 13),
          leading: Icon(icon, size: 20, color: itemColor),
          title: Text(
            title,
            style: TextStyle(
              color: itemColor,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          onTap: onTap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _studentInitial(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'S',
        style: const TextStyle(
          color: _webPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  void _openStudentPage(Widget page, {bool closeDrawer = false}) {
    if (closeDrawer) Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _showAnnouncementsNotice() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Connect the Flutter announcements screen to this menu item.'),
      ),
    );
  }

  Widget _buildProfileCard() {
    final studentName = details?['name']?.toString() ?? 'Loading...';
    final className = details?['class_name']?.toString() ??
        details?['dept']?.toString() ??
        'Student';
    final photo = details?['Photo']?.toString();

    return Container(
      constraints: const BoxConstraints(minHeight: 116),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _webBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A5037AA),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: _webPrimaryLight,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: _webPrimaryLight, width: 3),
            ),
            clipBehavior: Clip.antiAlias,
            child: photo != null && photo.isNotEmpty
                ? Image.network(
              photo.startsWith('http') ? photo : '$baseurl$photo',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _studentInitial(studentName),
            )
                : _studentInitial(studentName),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'STUDENT PROFILE',
                  style: TextStyle(
                    color: _webPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  studentName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _webTextPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: _webPrimaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    className,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _webPrimaryDark,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recent Pass Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _webTextPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: _webPrimaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_rounded, size: 13, color: _webPrimary),
                  SizedBox(width: 5),
                  Text(
                    'Latest pass',
                    style: TextStyle(
                      color: _webPrimaryDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (isLoading)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 34),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _webBorder),
            ),
            child: const Center(
              child: SizedBox(
                width: 25,
                height: 25,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: _webPrimary,
                ),
              ),
            ),
          )
        else if (timeline.isEmpty)
          _buildEmptyState()
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(17, 19, 17, 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _webBorder),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D5632C9),
                  blurRadius: 18,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: List.generate(timeline.length, (index) {
                final item = timeline[index];
                final bool isLast = index == timeline.length - 1;
                final status = (item['status'] ?? '').toLowerCase();

                Color statusColor;
                Color statusBackground;
                IconData statusIcon;
                if (status == 'completed' || status == 'approved' || status == 'scanned') {
                  statusColor = const Color(0xFF16865B);
                  statusBackground = const Color(0xFFE5F6EE);
                  statusIcon = Icons.check_rounded;
                } else if (status == 'rejected' || status == 'cancelled') {
                  statusColor = const Color(0xFFD84B5B);
                  statusBackground = const Color(0xFFFFEAED);
                  statusIcon = Icons.close_rounded;
                } else {
                  statusColor = const Color(0xFFB7791F);
                  statusBackground = const Color(0xFFFFF4DA);
                  statusIcon = Icons.schedule_rounded;
                }

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 36,
                        child: Column(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: statusBackground,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: statusColor.withValues(alpha: 0.14),
                                ),
                              ),
                              child: Icon(statusIcon, color: statusColor, size: 18),
                            ),
                            if (!isLast)
                              Expanded(
                                child: Center(
                                  child: Container(
                                    width: 2,
                                    color: _webBorder,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: isLast ? 15 : 19),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 3),
                              Text(
                                item['title'] ?? 'Pass activity',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: _webTextPrimary,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.access_time_rounded,
                                    size: 12,
                                    color: _webTextSecondary,
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      item['time'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: _webTextSecondary,
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
                    ],
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  String _passDetailValue(List<String> keys, {String fallback = 'Not available'}) {
    final pass = latestPassDetails;
    if (pass == null) return fallback;
    for (final key in keys) {
      final value = pass[key];
      if (value != null && value.toString().trim().isNotEmpty && value.toString() != 'null') {
        return value.toString().trim();
      }
    }
    return fallback;
  }

  // Formats the date exactly as DD-MM-YYYY. The date is taken from the
  // server's calendar date without converting it to the device timezone.
  String _formatPassDate(String rawDate) {
    final value = rawDate.trim();
    if (value.isEmpty || value == 'Not available') return value;

    try {
      final parsed = DateTime.parse(value);
      final day = parsed.day.toString().padLeft(2, '0');
      final month = parsed.month.toString().padLeft(2, '0');
      final year = parsed.year.toString().padLeft(4, '0');
      return '$day-$month-$year';
    } catch (_) {
      // If the API already returns a date in DD-MM-YYYY format, retain it.
      final dmy = RegExp(r'^(\d{2})-(\d{2})-(\d{4})$').firstMatch(value);
      if (dmy != null) return value;

      // Also support a server date formatted as YYYY-MM-DD with no timestamp.
      final ymd = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
      if (ymd != null) return '${ymd.group(3)}-${ymd.group(2)}-${ymd.group(1)}';
      return value;
    }
  }

  Widget _buildRecentPassDetails() {
    final reason = _passDetailValue(
      ['reason', 'purpose', 'exit_reason', 'pass_reason', 'description'],
      fallback: 'No recent pass details available',
    );
    final time = _passDetailValue(
      ['time', 'exit_time', 'departure_time', 'from_time', 'pass_time'],
    );
    final rawDate = _passDetailValue(
      ['date', 'pass_date', 'exit_date', 'created_at', 'requested_at'],
    );
    final date = _formatPassDate(rawDate);
    final destination = _passDetailValue(
      ['destination', 'place', 'going_to', 'location'],
    );
    final status = _passDetailValue(
      ['status', 'mentor_status', 'pass_status'],
      fallback: 'Pending',
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _webBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x105037AA),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _webPrimaryLight,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: _webPrimary, size: 19),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text(
                  'Recent Pass Details',
                  style: TextStyle(
                    color: _webTextPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!isLoading && latestPassDetails != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _webPrimaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: const TextStyle(
                      color: _webPrimaryDark,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const LinearProgressIndicator(minHeight: 2, color: _webPrimary)
          else if (latestPassDetails == null)
            const Text(
              'Your latest pass reason and schedule will appear here when you apply for a pass.',
              style: TextStyle(color: _webTextSecondary, fontSize: 12, height: 1.5),
            )
          else ...[
              _passDetailRow(Icons.notes_rounded, 'Reason', reason),
              const SizedBox(height: 13),
              _passDetailRow(Icons.calendar_today_rounded, 'Date', date),
              const SizedBox(height: 13),
              _passDetailRow(Icons.access_time_rounded, 'Time', time),
              if (destination != 'Not available') ...[
                const SizedBox(height: 13),
                _passDetailRow(Icons.place_outlined, 'Destination', destination),
              ],
            ],
        ],
      ),
    );
  }

  Widget _passDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: _webPrimary),
        const SizedBox(width: 10),
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: const TextStyle(
              color: _webTextSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: _webTextPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardFooter() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 34,
            height: 3,
            decoration: BoxDecoration(
              color: _webBorder,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'GateEase  •  Campus Exit Pass Management',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _webTextSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 25, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _webBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D5632C9),
            blurRadius: 18,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: _webPrimaryLight,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 36,
              color: _webPrimary,
            ),
          ),
          const SizedBox(height: 17),
          const Text(
            'No pass activity yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _webTextPrimary,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Your pass requests and their latest updates will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: _webTextSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 17),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: _webPrimary),
                SizedBox(width: 7),
                Text(
                  'New activity will be shown automatically',
                  style: TextStyle(
                    color: _webPrimaryDark,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


}
