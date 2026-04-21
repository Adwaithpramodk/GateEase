import 'package:flutter/material.dart';
import 'package:gateeaseapp/login.dart';
import 'package:gateeaseapp/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gateeaseapp/theme/app_theme.dart';

class ComplaintPage extends StatefulWidget {
  const ComplaintPage({super.key});

  @override
  State<ComplaintPage> createState() => _ComplaintPageState();
}

class _ComplaintPageState extends State<ComplaintPage> {
  List<dynamic> complaints = [];
  bool isLoading = true;
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
    try {
      if (lid == null) {
        final prefs = await SharedPreferences.getInstance();
        lid = prefs.getInt('lid');
      }
      if (lid == null) {
        setState(() => isLoading = false);
        return;
      }
      final response = await dio.get('$baseurl/ViewcomplaintAPI/$lid');
      debugPrint(response.data.toString());
      if (response.statusCode == 200) {
        setState(() {
          complaints = response.data;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Fetch complaints error: $e');
      isLoading = false;
    }
  }

  Future<void> registerComplaint(BuildContext context) async {
    // Validate complaint is not empty
    if (complaintController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your complaint'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Map<String, dynamic> data = {'complaint': complaintController.text.trim()};

    try {
      final response = await dio.post(
        '$baseurl/ViewcomplaintAPI/$lid',
        data: data,
      );

      if (response.statusCode == 201) {
        complaintController.clear();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Complaint submitted successfully!'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
        fetchComplaints(); // 🔥 refresh list
      }
    } catch (e) {
      debugPrint('Complaint error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit complaint. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support & Complaints'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Input Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 8))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Submit a Complaint', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: complaintController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Describe your issue in detail...',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => registerComplaint(context),
                    child: const Text('Send Report'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // History Section
            const Text('Previous Complaints', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (complaints.isEmpty)
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    Icon(Icons.mark_email_read_rounded, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text('No previous complaints', style: TextStyle(color: Colors.grey.shade500)),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: complaints.length,
                itemBuilder: (context, index) {
                  final item = complaints[index];
                  final bool isPending = item['reply'] == null || item['reply'] == '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(item['date'], style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (isPending ? Colors.orange : AppTheme.accent).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isPending ? 'Pending' : 'Resolved',
                                  style: TextStyle(color: isPending ? Colors.orange : AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(item['complaint'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          if (!isPending) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('ADMIN REPLY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondary, letterSpacing: 0.5)),
                                  const SizedBox(height: 4),
                                  Text(item['reply'], style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
