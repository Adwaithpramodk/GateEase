import 'package:flutter/material.dart';
import 'package:gateeaseapp/login.dart';
import 'package:gateeaseapp/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ComplaintPage extends StatefulWidget {
  const ComplaintPage({super.key});

  @override
  State<ComplaintPage> createState() => _ComplaintPageState();
}

class _ComplaintPageState extends State<ComplaintPage> {
  // GateEase student-home web theme
  static const Color primary = Color(0xFF6D4AE5);
  static const Color primaryDark = Color(0xFF5632C9);
  static const Color primaryLight = Color(0xFFEFEAFE);
  static const Color primaryTint = Color(0xFFF6F3FF);
  static const Color screenColor = Color(0xFFF7F6FC);
  static const Color pageColor = Color(0xFFEEEDF8);
  static const Color ink = Color(0xFF1B1840);
  static const Color muted = Color(0xFF6C6A86);
  static const Color faint = Color(0xFFA5A3BA);
  static const Color borderColor = Color(0xFFE8E6F5);
  static const Color successColor = Color(0xFF2EC27E);
  static const Color dangerColor = Color(0xFFF25C5C);
  static const Color pendingColor = Color(0xFFFF9A3D);

  final List<dynamic> complaints = [];
  bool isLoading = true;
  bool isSubmitting = false;
  bool hasLoadError = false;
  final TextEditingController complaintController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchComplaints();
  }

  @override
  void dispose() {
    complaintController.dispose();
    super.dispose();
  }

  Future<void> fetchComplaints() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        hasLoadError = false;
      });
    }

    try {
      if (lid == null) {
        final prefs = await SharedPreferences.getInstance();
        lid = prefs.getInt('lid');
      }

      if (lid == null) {
        if (!mounted) return;
        setState(() {
          isLoading = false;
          hasLoadError = true;
        });
        return;
      }

      final response = await dio.get('$baseurl/ViewcomplaintAPI/$lid');

      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          complaints
            ..clear()
            ..addAll(response.data is List ? response.data as List : []);
          isLoading = false;
          hasLoadError = false;
        });
      } else {
        setState(() {
          isLoading = false;
          hasLoadError = true;
        });
      }
    } catch (e) {
      debugPrint('Fetch complaints error: $e');
      if (!mounted) return;
      setState(() {
        isLoading = false;
        hasLoadError = true;
      });
    }
  }

  Future<void> registerComplaint() async {
    final complaintText = complaintController.text.trim();

    if (complaintText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your complaint'),
          backgroundColor: dangerColor,
        ),
      );
      return;
    }

    if (lid == null) {
      final prefs = await SharedPreferences.getInstance();
      lid = prefs.getInt('lid');
    }

    if (lid == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to identify your student account. Please log in again.',
          ),
          backgroundColor: dangerColor,
        ),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final response = await dio.post(
        '$baseurl/ViewcomplaintAPI/$lid',
        data: {'complaint': complaintText},
      );

      if (!mounted) return;

      if (response.statusCode == 201 || response.statusCode == 200) {
        complaintController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Complaint submitted successfully!'),
            backgroundColor: successColor,
          ),
        );
        await fetchComplaints();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to submit complaint. Please try again.'),
            backgroundColor: dangerColor,
          ),
        );
      }
    } catch (e) {
      debugPrint('Complaint error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to submit complaint. Please try again.'),
          backgroundColor: dangerColor,
        ),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  bool _isPending(dynamic item) {
    final reply = item is Map ? item['reply'] : null;
    return reply == null || reply.toString().trim().isEmpty;
  }

  String _safeValue(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final result = value.toString().trim();
    return result.isEmpty ? fallback : result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: primary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 4,
        title: const Text(
          'Support & Complaints',
          style: TextStyle(
            color: ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        iconTheme: const IconThemeData(color: primary),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: primary,
          backgroundColor: Colors.white,
          onRefresh: fetchComplaints,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  color: screenColor,
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 18),
                      _buildFormCard(),
                      const SizedBox(height: 24),
                      _buildHistoryHeader(),
                      const SizedBox(height: 14),
                      _buildComplaintHistory(),
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

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7650EA), Color(0xFF6240D8)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x295032AA),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -38,
            top: -48,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.13),
                  width: 1.3,
                ),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.17),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SUPPORT & COMPLAINTS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.65,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Submit an issue and track its status.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x195037AA),
            blurRadius: 20,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: primaryLight,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.edit_note_rounded, color: primary, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Submit a Complaint',
                      style: TextStyle(
                        color: ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Tell us how we can help.',
                      style: TextStyle(color: muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'YOUR MESSAGE',
            style: TextStyle(
              color: muted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 9),
          TextField(
            controller: complaintController,
            maxLines: 5,
            minLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Describe your issue in detail...',
              hintStyle: const TextStyle(color: faint, fontSize: 13),
              filled: true,
              fillColor: primaryTint,
              alignLabelWithHint: true,
              contentPadding: const EdgeInsets.all(15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: primary, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 17),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7650EA), Color(0xFF6240D8)],
                ),
                borderRadius: BorderRadius.circular(13),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x476D4AE5),
                    blurRadius: 13,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: isSubmitting ? null : registerComplaint,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white70,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: isSubmitting
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.send_rounded, size: 17),
                    SizedBox(width: 9),
                    Text(
                      'Send Report',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Previous Complaints',
                style: TextStyle(
                  color: ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Track replies and resolution status.',
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
        ),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            onTap: fetchComplaints,
            borderRadius: BorderRadius.circular(11),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: borderColor),
              ),
              child: const Icon(Icons.refresh_rounded, color: primary, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComplaintHistory() {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(
          child: CircularProgressIndicator(color: primary, strokeWidth: 2.5),
        ),
      );
    }

    if (hasLoadError) {
      return _buildEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Unable to load complaints',
        message: 'Check your connection and try again.',
        showRetry: true,
      );
    }

    if (complaints.isEmpty) {
      return _buildEmptyState(
        icon: Icons.mark_email_read_rounded,
        title: 'No complaints yet',
        message: 'Your submitted complaints and their replies will appear here.',
      );
    }

    return Column(
      children: List.generate(complaints.length, (index) {
        final item = complaints[index];
        final isPending = _isPending(item);
        final statusColor = isPending ? pendingColor : successColor;
        final complaintText = _safeValue(
          item is Map ? item['complaint'] : null,
          fallback: 'No complaint details available',
        );
        final dateText = _safeValue(item is Map ? item['date'] : null, fallback: 'Date unavailable');
        final replyText = _safeValue(item is Map ? item['reply'] : null);

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 13),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
            boxShadow: const [
              BoxShadow(
                color: Color(0x105037AA),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 13, color: muted),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      dateText,
                      style: const TextStyle(
                        color: muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isPending ? 'Pending' : 'Resolved',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'YOUR COMPLAINT',
                style: TextStyle(
                  color: faint,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                complaintText,
                style: const TextStyle(
                  color: ink,
                  fontSize: 13,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (!isPending) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: primaryTint,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: primaryLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.reply_rounded, size: 15, color: primary),
                          const SizedBox(width: 6),
                          const Text(
                            'ADMIN REPLY',
                            style: TextStyle(
                              color: primaryDark,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        replyText,
                        style: const TextStyle(
                          color: ink,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    bool showRetry = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 27),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: primaryLight,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: primary, size: 28),
          ),
          const SizedBox(height: 13),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: muted,
              fontSize: 11,
              height: 1.5,
            ),
          ),
          if (showRetry) ...[
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: fetchComplaints,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Try again'),
              style: TextButton.styleFrom(foregroundColor: primary),
            ),
          ],
        ],
      ),
    );
  }


}
