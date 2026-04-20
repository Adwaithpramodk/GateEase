import 'package:flutter/material.dart';
import 'package:gateeaseapp/login.dart';
import 'package:gateeaseapp/api_config.dart';

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
              backgroundColor: Colors.green,
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
      backgroundColor: const Color(0xFFF2F4F8),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F4F8),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text('Complaint', style: TextStyle(color: Colors.black)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ===== Complaint Input =====
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Enter your complaint',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: TextField(
                controller: complaintController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Type your complaint here...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () => registerComplaint(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Send'),
              ),
            ),

            const SizedBox(height: 30),

            // ===== Previous Complaints =====
            const Text(
              'Previous Complaints',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (complaints.isEmpty)
              const Center(
                child: Text(
                  'No complaints submitted yet',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: complaints.length,
                itemBuilder: (context, index) {
                  final item = complaints[index];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.report, color: Colors.black),
                      ),
                      title: Text(
                        item['complaint'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          item['reply'] == null || item['reply'] == ''
                              ? 'Admin Reply: Pending'
                              : 'Admin Reply: ${item['reply']}',
                          style: TextStyle(
                            color: item['reply'] == null || item['reply'] == ''
                                ? Colors.grey
                                : Colors.black87,
                          ),
                        ),
                      ),
                      trailing: Text(
                        item['date'],
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
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
