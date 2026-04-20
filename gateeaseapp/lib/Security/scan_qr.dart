// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:gateeaseapp/signup.dart';
// import 'package:mobile_scanner/mobile_scanner.dart';
// import 'package:dio/dio.dart';

// class ScanQrPage extends StatefulWidget {
//   const ScanQrPage({super.key});

//   @override
//   State<ScanQrPage> createState() => _ScanQrPageState();
// }

// class _ScanQrPageState extends State<ScanQrPage> {
//   final MobileScannerController controller = MobileScannerController();
//   final Dio dio = Dio();

//   bool scanned = false;

//   // final String baseUrl = "http://YOUR_IP:8000"; // change this

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         backgroundColor: const Color.fromARGB(255, 249, 251, 251),
//         title: const Text('Scan QR Code'),
//       ),
//       body: Stack(
//         children: [
//           MobileScanner(
//             controller: controller,
//             onDetect: (BarcodeCapture capture) async {
//               if (scanned) return;

//               final String? code = capture.barcodes.first.rawValue;
//               if (code == null) return;

//               scanned = true;
//               debugPrint("RAW QR DATA: $code");

//               try {
//                 final Map<String, dynamic> data = jsonDecode(code);

//                 final int passId = data['pass_id'];
//                 final String name = data['name']?.toString() ?? '-';
//                 final String reason = data['reason']?.toString() ?? '-';
//                 final String time = data['time']?.toString() ?? '-';

//                 // FIX class object issue
//                 String studentClass = "-";
//                 if (data['class'] is Map) {
//                   studentClass = data['class']['name']?.toString() ?? "-";
//                 } else {
//                   studentClass = data['class']?.toString() ?? "-";
//                 }

//                 await showDialog(
//                   context: context,
//                   barrierDismissible: false,
//                   builder: (context) {
//                     return AlertDialog(
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       title: const Text(
//                         "Pass Details",
//                         style: TextStyle(fontWeight: FontWeight.bold),
//                       ),
//                       content: Column(
//                         mainAxisSize: MainAxisSize.min,
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           _row("Pass ID", passId.toString()),
//                           _row("Name", name),
//                           _row("Class", studentClass),
//                           _row("Reason", reason),
//                           _row("Time", time),

//                         ],
//                       ),
//                       actions: [
//                         Row(
//                           children: [
//                             Expanded(
//                               child: ElevatedButton(
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: Colors.green,
//                                 ),
//                                 onPressed: () async {
//                                   await dio.post(
//                                     "$baseurl/AcceptPass",
//                                     data: {"pass_id": passId},
//                                   );
//                                   Navigator.pop(context);
//                                   Navigator.pop(context);
//                                 },
//                                 child: const Text("ACCEPT"),
//                               ),
//                             ),
//                             const SizedBox(width: 10),
//                             Expanded(
//                               child: ElevatedButton(
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: Colors.red,
//                                 ),
//                                 onPressed: () async {
//                                   await dio.post(
//                                     "$baseurl/RejectPass",
//                                     data: {"pass_id": passId},
//                                   );
//                                   Navigator.pop(context);
//                                   Navigator.pop(context);
//                                 },
//                                 child: const Text("REJECT"),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     );
//                   },
//                 );
//               } catch (e) {
//                 scanned = false;
//                 debugPrint("QR ERROR: $e");
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(content: Text("Invalid QR Code")),
//                 );
//               }
//             },
//           ),

//           // Scanner frame
//           Center(
//             child: Container(
//               width: 250,
//               height: 250,
//               decoration: BoxDecoration(
//                 border: Border.all(color: Colors.white, width: 3),
//                 borderRadius: BorderRadius.circular(16),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _row(String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4),
//       child: Row(
//         children: [
//           Expanded(
//             flex: 3,
//             child: Text(
//               "$label:",
//               style: const TextStyle(fontWeight: FontWeight.w600),
//             ),
//           ),
//           Expanded(flex: 5, child: Text(value)),
//         ],
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     controller.dispose();
//     super.dispose();
//   }
// }
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gateeaseapp/api_config.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:dio/dio.dart';

class ScanQrPage extends StatefulWidget {
  const ScanQrPage({super.key});

  @override
  State<ScanQrPage> createState() => _ScanQrPageState();
}

class _ScanQrPageState extends State<ScanQrPage> {
  final MobileScannerController controller = MobileScannerController();
  final Dio dio = Dio();

  bool scanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 249, 251, 251),
        title: const Text('Scan QR Code'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (BarcodeCapture capture) async {
              if (scanned) return;

              final String? code = capture.barcodes.first.rawValue;
              if (code == null) return;

              scanned = true;
              debugPrint("RAW QR DATA: $code");

              try {
                final Map<String, dynamic> data = jsonDecode(code);

                final int passId = data['pass_id'];
                final String name = data['name']?.toString() ?? '-';
                final String reason = data['reason']?.toString() ?? '-';
                final String time = data['time']?.toString() ?? '-';

                final String mentor = data['mentor']?.toString() ?? '-';

                // ------------------ CLASS FIX ------------------
                String studentClass = "-";
                if (data['class'] is Map) {
                  studentClass = data['class']['name']?.toString() ?? "-";
                } else {
                  studentClass = data['class']?.toString() ?? "-";
                }

                // ------------------ DATE FIX ------------------
                final String approvedAtRaw =
                    data['approved_at']?.toString() ?? "-";

                String approvedDate = "-";
                if (approvedAtRaw != "-") {
                  final DateTime dt = DateTime.parse(approvedAtRaw).toLocal();
                  approvedDate =
                      "${dt.day.toString().padLeft(2, '0')}-"
                      "${dt.month.toString().padLeft(2, '0')}-"
                      "${dt.year}";
                }

                // ------------------ DUPLICATE SCAN CHECK ------------------
                try {
                  final statusCheck = await dio.post(
                    "$baseurl/CheckPassStatus",
                    data: {"pass_id": passId},
                  );

                  if (!context.mounted) return;

                  if (statusCheck.statusCode == 200) {
                    final statusData = statusCheck.data;
                    if (statusData['security_status'] != 'pending') {
                      // Already Scanned
                      await showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) {
                          return AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            title: const Text(
                              "Already Scanned",
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            content: Text(
                              "This pass was already scanned by security",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  scanned = false; // Allow rescanning
                                },
                                child: const Text("OK"),
                              ),
                            ],
                          );
                        },
                      );
                      return; // STOP execution
                    }
                  }
                } catch (e) {
                  debugPrint("Status check failed: $e");
                  // Optional: handle network error or proceed cautiously
                }

                if (!context.mounted) return;

                await showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) {
                    return AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      title: const Text(
                        "Pass Details",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _row("Pass ID", passId.toString()),
                          _row("Name", name),
                          _row("Class", studentClass),
                          _row("Reason", reason),
                          _row("Time", time),
                          _row("Date", approvedDate),
                          _row(
                            "Status",
                            mentor == "Unknown"
                                ? "Approved by Admin"
                                : "Approved by $mentor",
                          ),
                        ],
                      ),
                      actions: [
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                                onPressed: () async {
                                  await dio.post(
                                    "$baseurl/AcceptPass",
                                    data: {"pass_id": passId},
                                  );
                                  if (!context.mounted) return;
                                  Navigator.pop(context);
                                  Navigator.pop(context);
                                },
                                child: const Text("ACCEPT"),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                onPressed: () async {
                                  await dio.post(
                                    "$baseurl/RejectPass",
                                    data: {"pass_id": passId},
                                  );
                                  if (!context.mounted) return;
                                  Navigator.pop(context);
                                  Navigator.pop(context);
                                },
                                child: const Text("REJECT"),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                );
              } catch (e) {
                scanned = false;
                debugPrint("QR ERROR: $e");
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Invalid QR Code")),
                );
              }
            },
          ),

          // ------------------ SCANNER FRAME ------------------
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(flex: 5, child: Text(value)),
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
