import 'package:flutter/material.dart';
import 'package:gateeaseapp/api_config.dart';
import 'package:gateeaseapp/theme/app_theme.dart';

class SecurityGroupPassPage extends StatefulWidget {
  const SecurityGroupPassPage({super.key});

  @override
  State<SecurityGroupPassPage> createState() => _SecurityGroupPassPageState();
}

class _SecurityGroupPassPageState extends State<SecurityGroupPassPage> {
  List<dynamic> groupPasses = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchGroupPasses();
  }

  Future<void> fetchGroupPasses() async {
    try {
      final response =
          await dio.get('$baseurl/SecurityGroupPassListAPI');
      if (response.statusCode == 200 && mounted) {
        setState(() {
          groupPasses = response.data;
          isLoading = false;
        });
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
      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group pass approved successfully')),
        );
        fetchGroupPasses();
      }
    } catch (e) {
      debugPrint('Proceed Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error approving pass')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Group Pass Requests',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : groupPasses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.groups_outlined,
                          size: 60, color: AppTheme.textMuted),
                      const SizedBox(height: 12),
                      const Text('No active group passes',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 15)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: fetchGroupPasses,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: groupPasses.length,
                    itemBuilder: (context, index) {
                      final group = groupPasses[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: AppTheme.cardDecoration,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header row
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryLight,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.groups_rounded,
                                        color: AppTheme.primary, size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          group['mentor_name'] ?? 'Mentor',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            color: AppTheme.textPrimary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          group['class_names'] ?? 'N/A',
                                          style: const TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
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
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textPrimary,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        group['date'] ?? '',
                                        style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              const SizedBox(height: 14),

                              // Students section
                              Row(
                                children: [
                                  const Icon(Icons.person_outline_rounded,
                                      size: 14, color: AppTheme.textSecondary),
                                  const SizedBox(width: 6),
                                  const Text('Students',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                        letterSpacing: 0.5,
                                      )),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                group['student_names'] ?? '',
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  height: 1.5,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Approve button
                              ElevatedButton.icon(
                                onPressed: () =>
                                    proceedPass(group['pass_ids']),
                                icon: const Icon(Icons.check_circle_rounded,
                                    size: 18),
                                label: const Text('Approve Group Pass'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
