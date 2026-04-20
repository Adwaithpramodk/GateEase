import 'package:flutter/material.dart';
import 'package:gateeaseapp/login.dart';
import 'package:gateeaseapp/api_config.dart';

class PendingPassPage extends StatefulWidget {
  const PendingPassPage({super.key});

  @override
  State<PendingPassPage> createState() => _PendingPassPageState();
}

class _PendingPassPageState extends State<PendingPassPage> {
  List<dynamic> pendingPasses = [];

  @override
  void initState() {
    super.initState();
    getDetails();
  }

  // ================= FETCH PENDING PASSES =================
  Future<void> getDetails() async {
    try {
      final response = await dio.get('$baseurl/Pendingpass_api/$lid');

      if (response.statusCode == 200) {
        setState(() {
          pendingPasses = response.data;
        });
      }
    } catch (e) {
      debugPrint('Get Details Error: $e');
    }
  }

  // ================= APPROVE =================
  Future<void> approvePassApi(int passId) async {
    try {
      final response = await dio.post(
        '$baseurl/approve',
        data: {"pass_id": passId, "role": "mentor", "loginid": lid},
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Pass Approved')));
        getDetails(); // refresh list
      }
    } catch (e) {
      debugPrint("Approve Error: $e");
    }
  }

  // ================= REJECT API =================
  Future<void> rejectPassApi(int passId, String reason) async {
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Pass Rejected')));
        getDetails(); // refresh list
      }
    } catch (e) {
      debugPrint("Reject Error: $e");
    }
  }

  // ================= REJECT POPUP =================
  void _showRejectDialog(int passId) {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            'Reject Pass',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter reason for rejection:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                autofocus: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  hintText: 'Type reason here...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final reason = controller.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a reason')),
                  );
                  return;
                }

                Navigator.pop(context);
                rejectPassApi(passId, reason);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 223, 223, 224),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 223, 223, 224),
        elevation: 0,
        title: const Text('Pending Pass Requests'),
        centerTitle: true,
      ),
      body: pendingPasses.isEmpty
          ? const Center(
              child: Text(
                'No pending pass requests',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: pendingPasses.length,
              itemBuilder: (context, index) {
                final pass = pendingPasses[index];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // STUDENT NAME
                        Text(
                          pass['name'] ?? '',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 10),

                        _infoRow(Icons.class_, pass['classs'] ?? ''),
                        _infoRow(Icons.access_time, pass['time'] ?? ''),
                        _infoRow(Icons.description, pass['reason'] ?? ''),

                        const SizedBox(height: 16),

                        // ACTION BUTTONS
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  _showRejectDialog(pass['id']);
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(Icons.cancel, size: 18),
                                label: const Text('Reject'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  approvePassApi(pass['id']);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(Icons.check_circle, size: 18),
                                label: const Text('Approve'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  // ================= INFO ROW =================
  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
