//

////////////////////////
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:gateeaseapp/login.dart';
import 'package:gateeaseapp/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gateeaseapp/theme/app_theme.dart';

class Mypasses extends StatefulWidget {
  const Mypasses({super.key});

  @override
  State<Mypasses> createState() => _MypassesState();
}

class _MypassesState extends State<Mypasses> {
  List<dynamic> details = [];
  bool isLoading = true;
  Map<int, String?> qrCodeCache = {}; // Cache QR codes by pass ID
  Map<int, String?> qrErrorMessages = {}; // Store error messages per pass
  Timer? _expiryTimer;

  final String imageBaseUrl = baseurl; // backend base url

  @override
  void initState() {
    super.initState();
    getDetails();
    _expiryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  // ================= FETCH PASSES =================
  Future<void> getDetails() async {
    try {
      if (lid == null) {
        final prefs = await SharedPreferences.getInstance();
        lid = prefs.getInt('lid');
      }
      if (lid == null) {
        setState(() => isLoading = false);
        return;
      }
      final response = await dio.get('$baseurl/ApplypassAPI/$lid');
      if (response.statusCode == 200) {
        setState(() {
          details = response.data;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Get Details Error: $e');
      setState(() => isLoading = false);
    }
  }

  // ================= GENERATE QR CODE =================
  Future<void> generateQRCode(int passId) async {
    final matchingPasses = details.where((pass) => pass['id'] == passId);
    if (matchingPasses.isNotEmpty && _isPassExpired(matchingPasses.first)) {
      _showMessage(_expiredMessage(matchingPasses.first));
      return;
    }

    try {
      final response = await dio.post(
        '$baseurl/GenerateQRCode',
        data: {'pass_id': passId},
      );

      if (response.statusCode == 200) {
        setState(() {
          qrCodeCache[passId] = response.data['qrcode_url'];
          qrErrorMessages[passId] = null;
        });
        // Refresh the pass list to get updated data
        getDetails();
        _showMessage('QR code generated successfully!');
      }
    } on DioException catch (e) {
      String errorMsg = 'Error generating QR code';

      if (e.response != null) {
        final responseData = e.response!.data;

        if (e.response!.statusCode == 403) {
          // QR not yet available
          if (responseData is Map && responseData.containsKey('message')) {
            errorMsg = responseData['message'];
          } else {
            errorMsg =
                'QR code will be available 15 minutes before your exit time';
          }
        } else if (e.response!.statusCode == 400) {
          if (responseData is Map && responseData.containsKey('error')) {
            errorMsg = responseData['error'];
          } else {
            errorMsg = 'Pass not approved or already processed';
          }
        } else if (e.response!.statusCode == 404) {
          errorMsg = 'Pass not found';
        }
      }

      setState(() {
        qrErrorMessages[passId] = errorMsg;
      });
      _showMessage(errorMsg);
      debugPrint('QR Generation Error: $e');
    } catch (e) {
      setState(() {
        qrErrorMessages[passId] = 'Network error. Please try again.';
      });
      debugPrint('QR Generation Error: $e');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // A pass expires 15 minutes after its requested exit time.
  // The request date is taken from created_at and the requested time from time.
  DateTime? _getPassExpiryTime(dynamic pass) {
    try {
      final createdAtRaw = pass['created_at']?.toString();
      final requestedTimeRaw = pass['time']?.toString();

      if (createdAtRaw == null ||
          createdAtRaw.isEmpty ||
          requestedTimeRaw == null ||
          requestedTimeRaw.isEmpty) {
        return null;
      }

      final createdAt = DateTime.parse(createdAtRaw).toLocal();
      final parsedTime = DateFormat('hh:mm a').parseStrict(requestedTimeRaw);

      final requestedExitDateTime = DateTime(
        createdAt.year,
        createdAt.month,
        createdAt.day,
        parsedTime.hour,
        parsedTime.minute,
        parsedTime.second,
      );
      return requestedExitDateTime.add(const Duration(minutes: 15));
    } catch (e) {
      debugPrint('Pass expiry calculation error: $e');
      return null;
    }
  }

  bool _isPassExpired(dynamic pass) {
    final expiryTime = _getPassExpiryTime(pass);
    return expiryTime != null && !DateTime.now().isBefore(expiryTime);
  }

  String _expiredMessage(dynamic pass) {
    final expiryTime = _getPassExpiryTime(pass);
    if (expiryTime == null) {
      return 'This pass has expired. The QR code is no longer available.';
    }
    return 'This pass expired at ${DateFormat('h:mm a').format(expiryTime)}. '
        'QR code access is no longer available.';
  }

  // ================= STATUS LOGIC =================
  Map<String, dynamic> getStatus(dynamic pass) {
    if (pass['mentor_status'] == 'rejected' ||
        pass['security_status'] == 'rejected') {
      return {
        'text': 'Rejected',
        'color': AppTheme.error,
        'icon': Icons.cancel_rounded,
      };
    } else if (pass['security_status'] == 'scanned') {
      return {
        'text': 'Completed',
        'color': AppTheme.accent,
        'icon': Icons.check_circle_rounded,
      };
    } else if (pass['mentor_status'] == 'approved' && _isPassExpired(pass)) {
      return {
        'text': 'Expired',
        'color': AppTheme.error,
        'icon': Icons.timer_off_rounded,
      };
    } else if (pass['mentor_status'] == 'approved') {
      return {
        'text': 'Approved',
        'color': AppTheme.primary,
        'icon': Icons.qr_code_2_rounded,
      };
    } else {
      return {
        'text': 'Pending',
        'color': Colors.orange,
        'icon': Icons.hourglass_top_rounded,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('My Passes'),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : details.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      size: 64,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No passes found',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You have not applied for any exit passes yet.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: details.length,
              itemBuilder: (context, index) {
                final pass = details[index];
                final status = getStatus(pass);
                final int passId = pass['id'];
                final bool isGroupPass = pass['is_group_pass'] ?? false;

                final bool isExpired =
                    pass['mentor_status'] == 'approved' && _isPassExpired(pass);

                final bool canShowQr =
                    !isGroupPass &&
                    pass['mentor_status'] == 'approved' &&
                    !isExpired &&
                    pass['security_status'] != 'scanned' &&
                    pass['security_status'] != 'rejected';

                // Generate through the encrypted-token API instead of trusting a
                // QR image created by an older app version.
                final String? qrUrl = qrCodeCache[passId];
                final bool hasQr = qrUrl != null && qrUrl.isNotEmpty;

                return Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: AppTheme.cardDecoration,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      children: [
                        // Header part
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: status['color'].withValues(alpha: 0.08),
                            border: Border(
                              bottom: BorderSide(
                                color: AppTheme.border,
                                style: BorderStyle.solid,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: status['color'].withValues(
                                    alpha: 0.15,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  status['icon'],
                                  color: status['color'],
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      pass['reason'] ?? 'No Reason',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        color: AppTheme.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat('EEEE, MMM dd').format(
                                        DateTime.parse(
                                          pass['created_at'],
                                        ).toLocal(),
                                      ),
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: status['color'],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  status['text'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Body part
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _passInfoTile(
                                      'TIME',
                                      pass['time'] ?? '--:--',
                                    ),
                                  ),
                                  Expanded(
                                    child: _passInfoTile(
                                      'TYPE',
                                      isGroupPass ? 'Group' : 'Individual',
                                    ),
                                  ),
                                ],
                              ),

                              if (pass['reject_reason'] != null &&
                                  status['text'] == 'Rejected') ...[
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.errorLight,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.info_rounded,
                                        color: AppTheme.error,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Reason: ${pass['reject_reason']}',
                                          style: const TextStyle(
                                            color: AppTheme.error,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              if (isGroupPass &&
                                  pass['mentor_status'] == 'approved') ...[
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.secondaryLight,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.group_rounded,
                                        color: AppTheme.secondary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Text(
                                          'Group pass approved. No QR code required.',
                                          style: TextStyle(
                                            color: AppTheme.secondary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              if (isExpired) ...[
                                const SizedBox(height: 20),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    color: AppTheme.errorLight,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppTheme.error.withValues(
                                        alpha: 0.18,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.timer_off_rounded,
                                        color: AppTheme.error,
                                        size: 21,
                                      ),
                                      const SizedBox(width: 11),
                                      Expanded(
                                        child: Text(
                                          _expiredMessage(pass),
                                          style: const TextStyle(
                                            color: AppTheme.error,
                                            fontSize: 12,
                                            height: 1.4,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // QR Section
                              if (canShowQr) ...[
                                const SizedBox(height: 28),
                                if (hasQr)
                                  Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                          border: Border.all(
                                            color: AppTheme.border,
                                            width: 2,
                                          ),
                                        ),
                                        child: Image.network(
                                          "$imageBaseUrl$qrUrl",
                                          height: 180,
                                          width: 180,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  const Icon(
                                                    Icons.qr_code_rounded,
                                                    size: 100,
                                                    color: AppTheme.textMuted,
                                                  ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Show this at the security gate',
                                        style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Column(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () => generateQRCode(passId),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.accent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.qr_code_scanner_rounded,
                                        ),
                                        label: const Text('Generate Pass QR'),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Available 15 min before exit',
                                        style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _passInfoTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
