import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gateeaseapp/api_config.dart';
import 'package:gateeaseapp/theme/app_theme.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanQrPage extends StatefulWidget {
  const ScanQrPage({super.key});

  @override
  State<ScanQrPage> createState() => _ScanQrPageState();
}

class _ScanQrPageState extends State<ScanQrPage> {
  final MobileScannerController controller = MobileScannerController();
  bool scanned = false;
  bool _torchOn = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera feed
          MobileScanner(
            controller: controller,
            onDetect: (BarcodeCapture capture) async {
              if (scanned) return;
              final String? code = capture.barcodes.first.rawValue;
              if (code == null) return;
              scanned = true;

              try {
                final Map<String, dynamic> data = jsonDecode(code);
                final int passId = data['pass_id'];
                final String name = data['name']?.toString() ?? '-';
                final String reason = data['reason']?.toString() ?? '-';
                final String time = data['time']?.toString() ?? '-';
                final String mentor = data['mentor']?.toString() ?? '-';

                String studentClass = '-';
                if (data['class'] is Map) {
                  studentClass = data['class']['name']?.toString() ?? '-';
                } else {
                  studentClass = data['class']?.toString() ?? '-';
                }

                final String approvedAtRaw =
                    data['approved_at']?.toString() ?? '-';
                String approvedDate = '-';
                if (approvedAtRaw != '-') {
                  final DateTime dt =
                      DateTime.parse(approvedAtRaw).toLocal();
                  approvedDate =
                      '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';
                }

                // Duplicate scan check
                try {
                  final statusCheck = await dio.post(
                    '$baseurl/CheckPassStatus',
                    data: {'pass_id': passId},
                  );
                  if (!context.mounted) return;
                  if (statusCheck.statusCode == 200 &&
                      statusCheck.data['security_status'] != 'pending') {
                    await _showAlreadyScannedDialog();
                    return;
                  }
                } catch (_) {}

                if (!context.mounted) return;
                await _showPassDialog(
                  passId: passId,
                  name: name,
                  reason: reason,
                  time: time,
                  approvedDate: approvedDate,
                  studentClass: studentClass,
                  mentor: mentor,
                );
              } catch (e) {
                scanned = false;
                debugPrint('QR ERROR: $e');
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid QR Code')));
              }
            },
          ),

          // Top bar
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _iconBtn(Icons.arrow_back_ios_new_rounded,
                      () => Navigator.pop(context)),
                  const Text('Scan QR Code',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 17)),
                  _iconBtn(
                    _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                    () {
                      setState(() => _torchOn = !_torchOn);
                      controller.toggleTorch();
                    },
                  ),
                ],
              ),
            ),
          ),

          // Scanner frame
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.8),
                        width: 3),
                  ),
                  child: Stack(
                    children: [
                      // Corner brackets
                      ..._buildCorners(),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: const Text(
                    'Point camera at student QR code',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
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

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  List<Widget> _buildCorners() {
    const double size = 24;
    const double thickness = 4;
    final color = AppTheme.primary;
    return [
      // Top-left
      Positioned(
          top: 0,
          left: 0,
          child: _corner(size, thickness, color,
              top: true, left: true)),
      // Top-right
      Positioned(
          top: 0,
          right: 0,
          child: _corner(size, thickness, color,
              top: true, left: false)),
      // Bottom-left
      Positioned(
          bottom: 0,
          left: 0,
          child: _corner(size, thickness, color,
              top: false, left: true)),
      // Bottom-right
      Positioned(
          bottom: 0,
          right: 0,
          child: _corner(size, thickness, color,
              top: false, left: false)),
    ];
  }

  Widget _corner(double size, double thickness, Color color,
      {required bool top, required bool left}) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CornerPainter(
            color: color,
            thickness: thickness,
            top: top,
            left: left),
      ),
    );
  }

  Future<void> _showAlreadyScannedDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
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
                  color: AppTheme.errorLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_rounded,
                    color: AppTheme.error, size: 30),
              ),
              const SizedBox(height: 16),
              const Text('Already Scanned',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  )),
              const SizedBox(height: 8),
              const Text(
                'This pass has already been scanned by security.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  scanned = false;
                },
                child: const Text('Scan Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPassDialog({
    required int passId,
    required String name,
    required String reason,
    required String time,
    required String approvedDate,
    required String studentClass,
    required String mentor,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppTheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.qr_code_2_rounded,
                        color: AppTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pass Details',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: AppTheme.textPrimary,
                          )),
                      Text('Verify before approving',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),

              _detailRow('Student', name, Icons.person_rounded),
              _detailRow('Class', studentClass, Icons.class_rounded),
              _detailRow('Reason', reason, Icons.info_outline_rounded),
              _detailRow('Time', time, Icons.access_time_rounded),
              _detailRow('Date', approvedDate, Icons.calendar_today_rounded),
              _detailRow(
                  'Approved by',
                  mentor == 'Unknown' ? 'Admin' : mentor,
                  Icons.verified_rounded),

              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        await dio.post('$baseurl/RejectPass',
                            data: {'pass_id': passId});
                        nav.pop();
                        nav.pop();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        side: const BorderSide(color: AppTheme.error),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Reject',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        await dio.post('$baseurl/AcceptPass',
                            data: {'pass_id': passId});
                        nav.pop();
                        nav.pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        minimumSize: const Size(0, 50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Accept',
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

  Widget _detailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.primary),
          const SizedBox(width: 10),
          Text('$label:  ',
              style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                ),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final bool top;
  final bool left;

  _CornerPainter({
    required this.color,
    required this.thickness,
    required this.top,
    required this.left,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (top && left) {
      canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
      canvas.drawLine(Offset.zero, Offset(0, size.height), paint);
    } else if (top && !left) {
      canvas.drawLine(
          Offset(size.width, 0), Offset(0, 0), paint);
      canvas.drawLine(
          Offset(size.width, 0), Offset(size.width, size.height), paint);
    } else if (!top && left) {
      canvas.drawLine(
          Offset(0, size.height), Offset(size.width, size.height), paint);
      canvas.drawLine(
          Offset(0, size.height), Offset(0, 0), paint);
    } else {
      canvas.drawLine(Offset(size.width, size.height),
          Offset(0, size.height), paint);
      canvas.drawLine(Offset(size.width, size.height),
          Offset(size.width, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
