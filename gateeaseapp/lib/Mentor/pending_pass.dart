import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:gateeaseapp/login.dart';
import 'package:gateeaseapp/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gateeaseapp/theme/app_theme.dart';

class PendingPassPage extends StatefulWidget {
  const PendingPassPage({super.key});

  @override
  State<PendingPassPage> createState() => _PendingPassPageState();
}

class _PendingPassPageState extends State<PendingPassPage> {
  List<dynamic> pendingPasses = [];
  bool isLoading = true;
  final Set<int> _processingPasses = {};

  @override
  void initState() {
    super.initState();
    getDetails();
  }

  // Original API call and response format preserved.
  Future<void> getDetails() async {
    try {
      if (lid == null) {
        final prefs = await SharedPreferences.getInstance();
        lid = prefs.getInt('lid');
      }
      if (lid == null) return;

      final response = await dio.get('$baseurl/Pendingpass_api/$lid');

      if (response.statusCode == 200 && mounted) {
        setState(() {
          pendingPasses = response.data;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Get Details Error: $e');
      if (mounted) setState(() => isLoading = false);
    } finally {
      if (mounted && isLoading) setState(() => isLoading = false);
    }
  }

  // Original endpoint, payload and success handling preserved.
  Future<void> approvePassApi(int passId) async {
    if (_processingPasses.contains(passId)) return;
    setState(() => _processingPasses.add(passId));
    try {
      final response = await dio.post(
        '$baseurl/approve',
        data: {"pass_id": passId, "role": "mentor", "loginid": lid},
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pass Approved')),
        );
        await getDetails();
      }
    } catch (e) {
      debugPrint("Approve Error: $e");
      if (!mounted) return;
      final message = e is DioException && e.response?.data is Map
          ? (e.response?.data['error']?.toString() ?? 'Unable to approve pass')
          : 'Unable to approve pass';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _processingPasses.remove(passId));
    }
  }

  // Original endpoint, payload and success handling preserved.
  Future<void> rejectPassApi(int passId, String reason) async {
    if (_processingPasses.contains(passId)) return;
    setState(() => _processingPasses.add(passId));
    try {
      final response = await dio.post(
        '$baseurl/reject',
        data: {
          "pass_id": passId,
          "role": "mentor",
          "reason": reason,
          "loginid": lid,
        },
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pass Rejected')),
        );
        await getDetails();
      }
    } catch (e) {
      debugPrint("Reject Error: $e");
      if (!mounted) return;
      final message = e is DioException && e.response?.data is Map
          ? (e.response?.data['error']?.toString() ?? 'Unable to reject pass')
          : 'Unable to reject pass';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _processingPasses.remove(passId));
    }
  }

  Future<void> _showRejectDialog(int passId) async {
    // Keep the input value as a String. This avoids disposing a
    // TextEditingController while the dialog route is still transitioning.
    String rejectionReason = '';

    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF211849).withValues(alpha: 0.14),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 46,
                      width: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEEEE),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.block_rounded,
                        color: AppTheme.error,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 13),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reject pass',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Confirm rejection reason',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () {
                        Navigator.of(
                          dialogContext,
                          rootNavigator: true,
                        ).pop();
                      },
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 19),
                const Text(
                  'Reason for rejection',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 9),
                TextField(
                  autofocus: true,
                  minLines: 3,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (value) => rejectionReason = value,
                  decoration: InputDecoration(
                    hintText: 'Explain why this pass is being rejected...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF9A97AE),
                      fontSize: 12,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8F7FC),
                    contentPadding: const EdgeInsets.all(15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: Color(0xFFE8E6F2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: Color(0xFFE8E6F2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppTheme.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(
                            dialogContext,
                            rootNavigator: true,
                          ).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          side: const BorderSide(
                            color: Color(0xFFE5E2EF),
                          ),
                          minimumSize: const Size(0, 47),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final reason = rejectionReason.trim();
                          if (reason.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please enter a rejection reason',
                                ),
                              ),
                            );
                            return;
                          }

                          Navigator.of(
                            dialogContext,
                            rootNavigator: true,
                          ).pop();
                          rejectPassApi(passId, reason);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.error,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size(0, 47),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        child: const Text(
                          'Reject pass',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppTheme.textPrimary),
        ),
        title: const Text(
          'Pass Requests',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: getDetails,
              child: pendingPasses.isEmpty
                  ? _emptyState()
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                      children: [
                        ...pendingPasses.map(_passCard),
                      ],
                    ),
            ),
    );
  }

  Widget _passCard(dynamic pass) {
    final int? passId = int.tryParse(pass['id']?.toString() ?? '');
    final bool busy =
        passId != null && _processingPasses.contains(passId);
    final String name = pass['name']?.toString().trim().isNotEmpty == true
        ? pass['name'].toString()
        : 'Student Name';
    final String className = pass['classs']?.toString() ?? '';
    final String reason = pass['reason']?.toString() ?? '';
    final String time = pass['time']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFFECEAF5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF28204F).withValues(alpha: 0.045),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 16, 17, 14),
            child: Row(
              children: [
                Container(
                  height: 43,
                  width: 43,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFEAFE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.person_rounded,
                      color: AppTheme.primary, size: 23),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (className.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          className,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E5),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule_rounded,
                          color: Color(0xFFD98724), size: 13),
                      SizedBox(width: 5),
                      Text(
                        'Pending',
                        style: TextStyle(
                          color: Color(0xFFB87519),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0EEF7)),
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 15, 17, 16),
            child: Column(
              children: [
                _detailRow(Icons.notes_rounded, 'REASON',
                    reason.isEmpty ? 'Not provided' : reason),
                const SizedBox(height: 14),
                _detailRow(Icons.access_time_rounded, 'EXPECTED EXIT',
                    time.isEmpty ? 'Not provided' : time),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: busy || passId == null
                            ? null
                            : () => _showRejectDialog(passId),
                        icon: const Icon(Icons.close_rounded, size: 17),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.error,
                          side: const BorderSide(color: Color(0xFFF2CACA)),
                          minimumSize: const Size(0, 45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: busy || passId == null
                            ? null
                            : () => approvePassApi(passId),
                        icon: busy
                            ? const SizedBox(
                                height: 15,
                                width: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_rounded, size: 17),
                        label: Text(busy ? 'Please wait' : 'Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size(0, 45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFF7F6FC),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: AppTheme.primary),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 9,
                  letterSpacing: 0.7,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.13),
        Center(
          child: Container(
            height: 92,
            width: 92,
            decoration: const BoxDecoration(
              color: Color(0xFFEFEAFE),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.task_alt_rounded,
                size: 43, color: AppTheme.primary),
          ),
        ),
        const SizedBox(height: 22),
        const Center(
          child: Text(
            'All caught up',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 42),
          child: Text(
            'There are no pending pass requests to review right now.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: TextButton.icon(
            onPressed: getDetails,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh requests'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
          ),
        ),
      ],
    );
  }
}
