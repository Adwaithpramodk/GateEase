import 'package:flutter/material.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:dio/dio.dart';
import 'package:gateeaseapp/login.dart';
import 'package:gateeaseapp/api_config.dart';
import 'package:gateeaseapp/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApplyPassPage extends StatefulWidget {
  const ApplyPassPage({super.key});

  @override
  State<ApplyPassPage> createState() => _ApplyPassPageState();
}

class _ApplyPassPageState extends State<ApplyPassPage> {
  final TextEditingController reasonController = TextEditingController();
  int _hour = 8;
  int _minute = 0;
  String _period = 'AM';
  bool _timeSelected = false;

  // Use the global dio instance (with JWT interceptor) instead of a bare local one

  Map<String, dynamic>? details;
  late final String todayDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    todayDate = '${now.day}/${now.month}/${now.year}';
    getDetails();
  }

  @override
  void dispose() {
    reasonController.dispose();
    super.dispose();
  }

  Future<void> getDetails() async {
    try {
      if (lid == null) {
        final prefs = await SharedPreferences.getInstance();
        lid = prefs.getInt('lid');
      }
      if (lid == null) return;

      final response = await dio.get('$baseurl/StudentInfo_api/$lid');
      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          details = response.data;
        });
      }
    } catch (e) {
      debugPrint('Get Details Error: $e');
    }
  }

  Future<void> applyPass() async {
    // Validate reason
    if (reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a reason for the pass'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate time
    if (!_timeSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select exit time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final String formattedTime =
        '${_hour.toString().padLeft(2, "0")}:${_minute.toString().padLeft(2, "0")} $_period';
    final Map<String, dynamic> data = {
      'reason': reasonController.text.trim(),
      'time': formattedTime,
    };

    try {
      final response = await dio.post('$baseurl/ApplypassAPI/$lid', data: data);
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pass applied successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Apply Pass Error: $e');
      String errorMsg = 'Failed to apply pass';
      if (e is DioException) {
        if (e.response?.data != null && e.response?.data is Map) {
          errorMsg = e.response?.data['error'] ?? e.response?.data['message'] ?? errorMsg;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
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
        title: const Text('Apply New Pass'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 🔹 Info Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Application Date',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      Text(
                        todayDate,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 24),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white10,
                        backgroundImage: details?['Photo'] != null
                            ? NetworkImage('$baseurl${details!['Photo']}')
                            : null,
                        child: details?['Photo'] == null
                            ? const Icon(Icons.person, color: Colors.white70)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              details?['name'] ?? 'Loading...',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              details?['dept'] ?? '',
                              style: const TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 🔹 Reason Field
            _sectionLabel('Why are you leaving?'),
            TextField(
              controller: reasonController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Enter a valid reason for your exit pass...',
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 60),
                  child: Icon(Icons.edit_note_rounded),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 🔹 Time Field
            _sectionLabel('Exit Time'),
            GestureDetector(
              onTap: _showTimePicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time_filled_rounded,
                      color: _timeSelected ? AppTheme.primary : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _timeSelected
                          ? '${_hour.toString().padLeft(2, "0")}:${_minute.toString().padLeft(2, "0")} $_period'
                          : 'Tap to select time',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: _timeSelected ? FontWeight.w600 : FontWeight.normal,
                        color: _timeSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 48),

            // 🔹 Apply Button
            ElevatedButton(
              onPressed: applyPass,
              child: const Text('Submit Application'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  void _showTimePicker() {
    int tempHour = _hour;
    int tempMinute = _minute;
    String tempPeriod = _period;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (bsCtx, bsSetState) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              const Text('Select Exit Time', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              
              // Pickers
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _timePickerColumn('Hour', 1, 12, tempHour, (val) => bsSetState(() => tempHour = val)),
                  const Padding(
                    padding: EdgeInsets.only(top: 25, left: 8, right: 8),
                    child: Text(':', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  ),
                  _timePickerColumn('Min', 0, 59, tempMinute, (val) => bsSetState(() => tempMinute = val), zeroPad: true),
                  const SizedBox(width: 24),
                  // AM/PM Toggle
                  Column(
                    children: [
                      const Text('Period', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _periodButton('AM', tempPeriod == 'AM', () => bsSetState(() => tempPeriod = 'AM')),
                      const SizedBox(height: 8),
                      _periodButton('PM', tempPeriod == 'PM', () => bsSetState(() => tempPeriod = 'PM')),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 40),
              
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _hour = tempHour;
                      _minute = tempMinute;
                      _period = tempPeriod;
                      _timeSelected = true;
                    });
                    Navigator.pop(bsCtx);
                  },
                  child: const Text('Confirm Time'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timePickerColumn(String label, int min, int max, int value, ValueChanged<int> onChanged, {bool zeroPad = false}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        NumberPicker(
          value: value,
          minValue: min,
          maxValue: max,
          zeroPad: zeroPad,
          itemHeight: 60,
          itemWidth: 80,
          selectedTextStyle: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primary),
          textStyle: const TextStyle(fontSize: 20, color: Colors.grey),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _periodButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppTheme.primary : Colors.grey.shade200),
          boxShadow: isSelected ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
