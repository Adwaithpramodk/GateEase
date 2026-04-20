import 'package:flutter/material.dart';
import 'package:gateeaseapp/api_config.dart';

class SecurityGroupPassPage extends StatefulWidget {
  const SecurityGroupPassPage({super.key});

  @override
  State<SecurityGroupPassPage> createState() => _SecurityGroupPassPageState();
}

class _SecurityGroupPassPageState extends State<SecurityGroupPassPage> {
  List<dynamic> groupPasses = [];
  bool isLoading = true;
  final Color themeColor = const Color.fromARGB(255, 252, 252, 252);

  @override
  void initState() {
    super.initState();
    fetchGroupPasses();
  }

  Future<void> fetchGroupPasses() async {
    try {
      final response = await dio.get('$baseurl/SecurityGroupPassListAPI');
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            groupPasses = response.data;
            isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('Fetch Error: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> proceedPass(List<dynamic> passIds) async {
    try {
      final response = await dio.post(
        '$baseurl/ProceedGroupPassAPI',
        data: {'pass_ids': passIds},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pass Approved successfully')),
          );
        }
        fetchGroupPasses();
      }
    } catch (e) {
      debugPrint('Proceed Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error proceeding pass')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: themeColor,
      appBar: AppBar(
        title: const Text(
          'Group Pass Requests',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: themeColor,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: Colors.black),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : groupPasses.isEmpty
          ? const Center(child: Text('No active group passes'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: groupPasses.length,
              itemBuilder: (context, index) {
                final group = groupPasses[index];
                return Card(
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mentor: ${group['mentor_name']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Class: ${group['class_names'] ?? 'N/A'}',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  group['time'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  group['date'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        const Text(
                          'Students:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          group['student_names'] ?? '',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => proceedPass(group['pass_ids']),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Approve',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
}
