//

////////////////////////
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:gateeaseapp/login.dart';
import 'package:gateeaseapp/api_config.dart';

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

  final String imageBaseUrl = baseurl; // backend base url

  @override
  void initState() {
    super.initState();
    getDetails();
  }

  // ================= FETCH PASSES =================
  Future<void> getDetails() async {
    try {
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

  // ================= STATUS LOGIC =================
  Map<String, dynamic> getStatus(dynamic pass) {
    if (pass['mentor_status'] == 'rejected' ||
        pass['security_status'] == 'rejected') {
      return {
        'text': 'Rejected',
        'color': Colors.red,
        'icon': Icons.cancel_outlined,
      };
    } else if (pass['security_status'] == 'scanned') {
      return {
        'text': 'Scanned',
        'color': Colors.green,
        'icon': Icons.verified_outlined,
      };
    } else if (pass['mentor_status'] == 'approved') {
      return {'text': 'Approved', 'color': Colors.blue, 'icon': Icons.qr_code};
    } else {
      return {
        'text': 'Pending',
        'color': Colors.orange,
        'icon': Icons.hourglass_bottom,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFFF2F4F8),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text('My Passes', style: TextStyle(color: Colors.black)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : details.isEmpty
          ? const Center(child: Text('No passes found'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: details.length,
              itemBuilder: (context, index) {
                final pass = details[index];
                final status = getStatus(pass);
                final int passId = pass['id'];
                final bool isGroupPass = pass['is_group_pass'] ?? false;

                final bool canShowQr =
                    !isGroupPass &&
                    pass['mentor_status'] == 'approved' &&
                    pass['security_status'] != 'scanned' &&
                    pass['security_status'] != 'rejected';

                // Check if QR exists in pass data or cache
                final String? qrUrl = pass['qrcode'] ?? qrCodeCache[passId];
                final bool hasQr = qrUrl != null && qrUrl.isNotEmpty;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: status['color'].withValues(
                              alpha: 0.15,
                            ),
                            child: Icon(status['icon'], color: status['color']),
                          ),
                          title: Text(
                            pass['reason'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Date: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(pass['created_at']).toLocal())}',
                              ),
                              Text('Time: ${pass['time']}'),

                              if (status['text'] == 'Rejected') ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Reason: ${pass['reject_reason'] ?? 'Not specified'}',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ],

                              if (pass['security_status'] == 'scanned') ...[
                                const SizedBox(height: 4),
                                const Text(
                                  'Pass scanned at gate',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: status['color'].withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status['text'],
                              style: TextStyle(
                                color: status['color'],
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),

                        // Group Pass Indicator
                        if (isGroupPass &&
                            pass['mentor_status'] == 'approved') ...[
                          const Divider(),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.group,
                                  color: Colors.blue.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Group Pass - No QR code needed. Security will approve directly.',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // ================= QR CODE SECTION =================
                        if (canShowQr) ...[
                          const Divider(),
                          const SizedBox(height: 8),

                          if (hasQr) ...[
                            // Show QR code
                            Column(
                              children: [
                                Image.network(
                                  "$imageBaseUrl$qrUrl",
                                  height: 180,
                                  width: 180,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Text(
                                      "QR not available",
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Show this QR at the gate',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            // Show button to generate QR
                            Column(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => generateQRCode(passId),
                                  icon: const Icon(Icons.qr_code_2),
                                  label: const Text('Generate QR Code'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                                if (qrErrorMessages[passId] != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    qrErrorMessages[passId]!,
                                    style: const TextStyle(
                                      color: Colors.orange,
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                                const SizedBox(height: 4),
                                const Text(
                                  'Available 15 min before exit time',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
