import 'package:flutter/material.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:dio/dio.dart';
import 'package:gateeaseapp/login.dart';
import 'package:gateeaseapp/api_config.dart';

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

  final Dio dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

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
      if (e is DioException) {
        debugPrint('DioError Type: ${e.type}');
        debugPrint('DioError Message: ${e.message}');
        if (e.response != null) {
          debugPrint('DioError Response: ${e.response?.data}');
          debugPrint('DioError Status: ${e.response?.statusCode}');
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to apply pass. Please checking console for details.',
            ),
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
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F4F8),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Apply New Pass',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 🔹 Student Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Name : ',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Flexible(
                              child: Text(
                                details?['name'] ?? 'Loading...',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text(
                              'Department : ',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Flexible(
                              child: Text(
                                details?['dept'] ?? '',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Date',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          todayDate,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            _label('Reason'),
            _inputField(
              hint: 'Reason for the pass',
              controller: reasonController,
              maxLines: 4,
              icon: Icons.edit_note,
            ),

            const SizedBox(height: 20),

            _label('Exit Time'),
            GestureDetector(
              onTap: _showTimePicker,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.grey),
                    const SizedBox(width: 12),
                    Text(
                      _timeSelected
                          ? '${_hour.toString().padLeft(2, "0")}:${_minute.toString().padLeft(2, "0")} $_period'
                          : 'Select time',
                      style: TextStyle(
                        fontSize: 16,
                        color: _timeSelected
                            ? Colors.black87
                            : Colors.grey[500],
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // 🔹 Apply Button
            Container(
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: applyPass,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Apply Pass',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
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
            color: Color(0xFFF2F4F8),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F4F8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.schedule_rounded,
                        color: Colors.black87,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Exit Time',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Scroll to pick hour & minute',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Pickers row
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Hour
                    Column(
                      children: [
                        const Text(
                          'Hour',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        NumberPicker(
                          value: tempHour,
                          minValue: 1,
                          maxValue: 12,
                          itemHeight: 48,
                          itemWidth: 70,
                          textStyle: const TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                          selectedTextStyle: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: Colors.black.withValues(alpha: 0.12),
                                width: 1.5,
                              ),
                              bottom: BorderSide(
                                color: Colors.black.withValues(alpha: 0.12),
                                width: 1.5,
                              ),
                            ),
                          ),
                          onChanged: (val) => bsSetState(() => tempHour = val),
                        ),
                      ],
                    ),
                    // Colon
                    const Padding(
                      padding: EdgeInsets.only(top: 20, left: 4, right: 4),
                      child: Text(
                        ':',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    // Minute
                    Column(
                      children: [
                        const Text(
                          'Minute',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        NumberPicker(
                          value: tempMinute,
                          minValue: 0,
                          maxValue: 59,
                          itemHeight: 48,
                          itemWidth: 70,
                          zeroPad: true,
                          textStyle: const TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                          selectedTextStyle: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: Colors.black.withValues(alpha: 0.12),
                                width: 1.5,
                              ),
                              bottom: BorderSide(
                                color: Colors.black.withValues(alpha: 0.12),
                                width: 1.5,
                              ),
                            ),
                          ),
                          onChanged: (val) =>
                              bsSetState(() => tempMinute = val),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // AM/PM
                    Column(
                      children: [
                        const Text(
                          'Period',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Column(
                          children: ['AM', 'PM'].map((p) {
                            final selected = tempPeriod == p;
                            return GestureDetector(
                              onTap: () => bsSetState(() => tempPeriod = p),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? Colors.black87
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  p,
                                  style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : Colors.grey,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Confirm button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _hour = tempHour;
                      _minute = tempMinute;
                      _period = tempPeriod;
                      _timeSelected = true;
                    });
                    Navigator.pop(bsCtx);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'Confirm Time',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _inputField({
    required String hint,
    required TextEditingController controller,
    int maxLines = 1,
    IconData? icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: icon != null ? Icon(icon) : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
