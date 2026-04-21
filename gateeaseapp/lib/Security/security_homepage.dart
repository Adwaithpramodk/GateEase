import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:gateeaseapp/Security/scan_qr.dart';
import 'package:gateeaseapp/Security/security_group_pass.dart';
import 'package:gateeaseapp/login.dart';
import 'package:gateeaseapp/api_config.dart';
import 'package:gateeaseapp/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

class SecurityHomePage extends StatefulWidget {
  const SecurityHomePage({super.key});

  @override
  State<SecurityHomePage> createState() => _SecurityHomePageState();
}

class _SecurityHomePageState extends State<SecurityHomePage> {
  List<dynamic> allPasses = [];
  List<dynamic> filteredPasses = [];
  bool isLoading = true;
  Map<String, dynamic>? details;
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    fetchApprovedPasses();
    getDetails();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => LoginPage()), (route) => false);
  }

  Future<void> getDetails() async {
    try {
      if (lid == null) {
        final prefs = await SharedPreferences.getInstance();
        lid = prefs.getInt('lid');
      }
      if (lid == null) return;

      final response = await dio.get('$baseurl/Securityinfo_api/$lid');
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
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
        String errorMsg = 'Failed to load security profile';
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

  Future<void> fetchApprovedPasses() async {
    try {
      if (lid == null) {
        final prefs = await SharedPreferences.getInstance();
        lid = prefs.getInt('lid');
      }
      if (lid == null) return;

      final response =
          await dio.get('$baseurl/SecurityApprovedPassAPI/$lid');
      if (!mounted) return;
      if (response.statusCode == 200) {
        allPasses = response.data;
        _filterByDate();
        setState(() => isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  void _filterByDate() {
    filteredPasses = allPasses.where((pass) {
      final passDate = DateTime.parse(pass['date']);
      return passDate.year == selectedDate.year &&
          passDate.month == selectedDate.month &&
          passDate.day == selectedDate.day;
    }).toList();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (!mounted || picked == null) return;
    setState(() {
      selectedDate = picked;
      _filterByDate();
    });
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
            await fetchApprovedPasses();
            await getDetails();
          },
          child: CustomScrollView(
            slivers: [
              _buildHeader(),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildSectionLabel('Gate Operations'),
                    const SizedBox(height: 14),
                    _buildOperationsRow(),
                    const SizedBox(height: 32),
                    _buildHistoryHeader(),
                    const SizedBox(height: 14),
                    _buildPassList(),
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
    return SliverAppBar(
      expandedHeight: 200, // Slightly reduced
      pinned: true,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: AppTheme.headerTop,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      automaticallyImplyLeading: false,
      title: const Text('Security Portal',
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
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
          child: Stack(
            children: [
              // Decoration circles
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
                right: 50,
                top: 60,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              // Profile content
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
                        backgroundImage: details?['Photo'] != null
                            ? NetworkImage('$baseurl${details!['Photo']}')
                            : null,
                        child: details?['Photo'] == null
                            ? const Icon(Icons.security_rounded,
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
                          Text('On duty,',
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
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('Main Gate',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                    // Today indicator
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            DateFormat('dd').format(DateTime.now()),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                              height: 1,
                            ),
                          ),
                          Text(
                            DateFormat('MMM').format(DateTime.now()),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
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
    );
  }

  Widget _buildSectionLabel(String label) {
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

  Widget _buildOperationsRow() {
    return Row(
      children: [
        Expanded(
          child: _opCard(
            icon: Icons.qr_code_scanner_rounded,
            label: 'Scan Pass',
            subtitle: 'Verify student',
            gradient: const [AppTheme.primary, AppTheme.primaryDark],
            onTap: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ScanQrPage()));
              fetchApprovedPasses();
            },
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _opCard(
            icon: Icons.groups_rounded,
            label: 'Group Pass',
            subtitle: 'Batch approve',
            gradient: const [AppTheme.accent, AppTheme.primaryDark],
            onTap: () => Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) => const SecurityGroupPassPage())),
          ),
        ),
      ],
    );
  }

  Widget _opCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withValues(alpha: 0.3),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 14),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSectionLabel('Validated Passes'),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_rounded,
                    size: 14, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(
                  DateFormat('MMM d, yyyy').format(selectedDate),
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPassList() {
    if (filteredPasses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Icon(Icons.history_rounded,
                size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            const Text('No passes for this date',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 14)),
          ],
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredPasses.length,
      itemBuilder: (context, i) => _passCard(filteredPasses[i]),
    );
  }

  Widget _passCard(dynamic pass) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.cardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.primaryLight,
              child: Text(
                (pass['name']?.toString() ?? '?')[0].toUpperCase(),
                style: const TextStyle(
                    color: AppTheme.primary, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pass['name'] ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text('${pass['reason']} · ${pass['time']}',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.successLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Scanned',
                  style: TextStyle(
                      color: AppTheme.success,
                      fontWeight: FontWeight.w700,
                      fontSize: 11)),
            ),
          ],
        ),
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
              const Text('End shift?',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              const Text(
                'You will be signed out of the security portal.',
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
                      onPressed: logout,
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
