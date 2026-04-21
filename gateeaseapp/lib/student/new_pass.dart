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
            backgroundColor: AppTheme.success,
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
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Apply New Pass'),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 🔹 Info Header Card (Deep Indigo Gradient)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.primary, AppTheme.headerBottom],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
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
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          todayDate,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Divider(color: Colors.white24, height: 1),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          backgroundImage: details?['Photo'] != null
                              ? NetworkImage('$baseurl${details!['Photo']}')
                              : null,
                          child: details?['Photo'] == null
                              ? const Icon(Icons.person_rounded, color: Colors.white, size: 32)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              details?['name'] ?? 'Loading...',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              details?['dept'] ?? '',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 36),

            // 🔹 Reason Field
            _sectionLabel('Why are you leaving?'),
            TextField(
              controller: reasonController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Enter a valid reason for your exit pass...',
                alignLabelWithHint: true,
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
                  borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                ),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 60),
                  child: Icon(Icons.edit_note_rounded),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // 🔹 Time Field
            _sectionLabel('Exit Time'),
            GestureDetector(
              onTap: _showTimePicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: AppTheme.primary.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _timeSelected ? AppTheme.primaryLight : AppTheme.surfaceAlt,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.access_time_filled_rounded,
                        color: _timeSelected ? AppTheme.primary : AppTheme.textMuted,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      _timeSelected
                          ? '${_hour.toString().padLeft(2, "0")}:${_minute.toString().padLeft(2, "0")} $_period'
                          : 'Tap to select time',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: _timeSelected ? FontWeight.w700 : FontWeight.w500,
                        color: _timeSelected ? AppTheme.textPrimary : AppTheme.textMuted,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 48),

            // 🔹 Apply Button
            ElevatedButton(
              onPressed: applyPass,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Submit Application'),
            ),
            const SizedBox(height: 32),
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
              const Text('Select Exit Time', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              const Text(
                'Permitted: 10:00 AM - 03:40 PM',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary),
              ),
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
                  _timePickerColumn(
                    'Min', 
                    0, 
                    (tempPeriod == 'PM' && tempHour == 3) ? 40 : 59, 
                    tempMinute > ((tempPeriod == 'PM' && tempHour == 3) ? 40 : 59) ? ((tempPeriod == 'PM' && tempHour == 3) ? 40 : 59) : tempMinute, 
                    (val) => bsSetState(() => tempMinute = val), 
                    zeroPad: true
                  ),
                  const SizedBox(width: 24),
                  // AM/PM Toggle
                  Column(
                    children: [
                      const Text('Period', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _periodButton('AM', tempPeriod == 'AM', () => bsSetState(() {
                        tempPeriod = 'AM';
                        if (tempHour < 10) tempHour = 10;
                        if (tempHour > 11) tempHour = 10;
                      })),
                      const SizedBox(height: 8),
                      _periodButton('PM', tempPeriod == 'PM', () => bsSetState(() {
                        tempPeriod = 'PM';
                        if (tempHour > 3 && tempHour != 12) tempHour = 12;
                      })),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 40),
              
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                child: ElevatedButton(
                  onPressed: () {
                    // Time Restriction: 10:00 AM to 3:40 PM
                    int hour24 = tempHour;
                    if (tempPeriod == 'PM' && tempHour != 12) hour24 += 12;
                    if (tempPeriod == 'AM' && tempHour == 12) hour24 = 0;

                    final totalMinutes = hour24 * 60 + tempMinute;
                    const startMinutes = 10 * 60; // 10:00 AM
                    const endMinutes = 15 * 60 + 40; // 3:40 PM

                    if (totalMinutes < startMinutes || totalMinutes > endMinutes) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Exit time must be between 10:00 AM and 03:40 PM'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

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
