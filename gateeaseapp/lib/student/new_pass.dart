import 'package:flutter/material.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:dio/dio.dart';
import 'package:gateeaseapp/login.dart';
import 'package:gateeaseapp/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApplyPassPage extends StatefulWidget {
  const ApplyPassPage({super.key});

  @override
  State<ApplyPassPage> createState() => _ApplyPassPageState();
}

class _ApplyPassPageState extends State<ApplyPassPage> {
  // Exact color tokens extracted from student_home.html.
  static const Color _webPrimary = Color(0xFF6D4AE5);
  static const Color _webPrimaryDark = Color(0xFF5632C9);
  static const Color _webPrimaryLight = Color(0xFFEFEAFE);
  static const Color _webPrimaryTint = Color(0xFFF6F3FF);
  static const Color _webBackground = Color(0xFFEEEDF8);
  static const Color _webScreen = Color(0xFFF7F6FC);
  static const Color _webSurface = Color(0xFFFFFFFF);
  static const Color _webTextPrimary = Color(0xFF1B1840);
  static const Color _webTextSecondary = Color(0xFF6C6A86);
  static const Color _webTextMuted = Color(0xFFA5A3BA);
  static const Color _webSuccess = Color(0xFF2EC27E);
  static const Color _webDanger = Color(0xFFF25C5C);
  static const Color _webBorder = Color(0xFFE8E6F5);
  final TextEditingController reasonController = TextEditingController();
  int _hour = 8;
  int _minute = 0;
  String _period = 'AM';
  bool _timeSelected = false;
  bool _isSubmitting = false;

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
    if (_isSubmitting) return;

    // Validate reason
    if (reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a reason for the pass'),
          backgroundColor: _webDanger,
        ),
      );
      return;
    }

    // Validate time
    if (!_timeSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select exit time'),
          backgroundColor: _webDanger,
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

    setState(() => _isSubmitting = true);
    try {
      final response = await dio.post('$baseurl/ApplypassAPI/$lid', data: data);
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pass applied successfully!'),
            backgroundColor: _webSuccess,
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
            backgroundColor: _webDanger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentName = details?['name']?.toString() ?? 'Loading student details...';
    final department = details?['dept']?.toString() ?? 'Student';

    return Scaffold(
      backgroundColor: _webBackground,
      appBar: AppBar(
        backgroundColor: _webSurface,
        foregroundColor: _webPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 4,
        title: const Text(
          'Apply New Pass',
          style: TextStyle(
            color: _webTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        iconTheme: const IconThemeData(color: _webPrimary),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header card uses the same gradient and purple palette as Student Home.
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF7650EA), Color(0xFF6240D8)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x295032AA),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -48,
                      top: -65,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.exit_to_app_rounded,
                                color: Colors.white,
                                size: 21,
                              ),
                            ),
                            const SizedBox(width: 11),
                            const Expanded(
                              child: Text(
                                'NEW EXIT PASS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.15,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                todayDate,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Apply for an exit pass',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Add your reason and exit time.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: 11,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Divider(
                          color: Colors.white.withValues(alpha: 0.22),
                          height: 1,
                        ),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.17),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: details?['Photo'] != null &&
                                  details!['Photo'].toString().isNotEmpty
                                  ? Image.network(
                                details!['Photo'].toString().startsWith('http')
                                    ? details!['Photo'].toString()
                                    : '$baseurl${details!['Photo']}',
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.person_rounded,
                                  color: Colors.white,
                                ),
                              )
                                  : const Icon(
                                Icons.person_rounded,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    studentName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    department,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.78),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.verified_user_outlined,
                              color: Colors.white70,
                              size: 19,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 23),

              // Form container.
              Container(
                padding: const EdgeInsets.fromLTRB(17, 20, 17, 18),
                decoration: BoxDecoration(
                  color: _webSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _webBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A5037AA),
                      blurRadius: 18,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: _webPrimaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.edit_document,
                            color: _webPrimary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Pass Information',
                            style: TextStyle(
                              color: _webTextPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _webPrimaryLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Required',
                            style: TextStyle(
                              color: _webPrimaryDark,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _sectionLabel('Why are you leaving?'),
                    TextField(
                      controller: reasonController,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(
                        color: _webTextPrimary,
                        fontSize: 14,
                        height: 1.45,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter a valid reason for your exit pass...',
                        hintStyle: const TextStyle(
                          color: _webTextSecondary,
                          fontSize: 13,
                        ),
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: _webPrimaryTint,
                        contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: const BorderSide(color: _webBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: const BorderSide(color: _webBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: const BorderSide(
                            color: _webPrimary,
                            width: 1.4,
                          ),
                        ),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 60),
                          child: Icon(
                            Icons.notes_rounded,
                            color: _webPrimary,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _sectionLabel('Exit Time'),
                    GestureDetector(
                      onTap: _showTimePicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: _webPrimaryTint,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: _timeSelected ? _webPrimary : _webBorder,
                            width: _timeSelected ? 1.3 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _webPrimaryLight,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: const Icon(
                                Icons.schedule_rounded,
                                color: _webPrimary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _timeSelected
                                        ? '${_hour.toString().padLeft(2, "0")}:${_minute.toString().padLeft(2, "0")} $_period'
                                        : 'Select your exit time',
                                    style: TextStyle(
                                      color: _timeSelected
                                          ? _webTextPrimary
                                          : _webTextSecondary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  const Text(
                                    'Select your preferred exit time',
                                    style: TextStyle(
                                      color: _webTextSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: _webPrimary,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 23),
                    SizedBox(
                      height: 52,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_webPrimary, _webPrimaryDark],
                          ),
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x295032AA),
                              blurRadius: 12,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : applyPass,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.send_rounded, size: 17),
                              SizedBox(width: 9),
                              Text(
                                _isSubmitting
                                    ? 'Submitting...'
                                    : 'Submit Application',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 17),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: _webTextSecondary,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Your request will be sent to your mentor for approval.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _webTextSecondary.withValues(alpha: 0.9),
                        fontSize: 11,
                        height: 1.4,
                      ),
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

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: _webTextPrimary,
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
            color: _webScreen,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: _webBorder, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              const Text('Select Exit Time', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _webTextPrimary)),
              const SizedBox(height: 8),
              const Text(
                'Select any valid exit time',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _webPrimary),
              ),
              const SizedBox(height: 32),

              // Pickers
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _timePickerColumn('Hour', 1, 12, tempHour, (val) => bsSetState(() => tempHour = val)),
                  const Padding(
                    padding: EdgeInsets.only(top: 25, left: 8, right: 8),
                    child: Text(':', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: _webPrimary)),
                  ),
                  _timePickerColumn(
                    'Min',
                    0,
                    59,
                    tempMinute,
                    (val) => bsSetState(() => tempMinute = val),
                    zeroPad: true,
                  ),
                  const SizedBox(width: 24),
                  // AM/PM Toggle
                  Column(
                    children: [
                      const Text('Period', style: TextStyle(color: _webTextSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _periodButton(
                        'AM',
                        tempPeriod == 'AM',
                        () => bsSetState(() => tempPeriod = 'AM'),
                      ),
                      const SizedBox(height: 8),
                      _periodButton(
                        'PM',
                        tempPeriod == 'PM',
                        () => bsSetState(() => tempPeriod = 'PM'),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 40),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      // No client-side time-range restriction.
                      // The Django backend remains responsible for validating
                      // the permitted application and exit-time window.
                      setState(() {
                        _hour = tempHour;
                        _minute = tempMinute;
                        _period = tempPeriod;
                        _timeSelected = true;
                      });
                      Navigator.pop(bsCtx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _webPrimary,
                      foregroundColor: _webSurface,
                      disabledBackgroundColor: _webPrimary.withValues(alpha: 0.45),
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: const Text('Confirm Time'),
                  ),
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
        Text(label, style: const TextStyle(color: _webTextSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        NumberPicker(
          value: value,
          minValue: min,
          maxValue: max,
          zeroPad: zeroPad,
          itemHeight: 60,
          itemWidth: 80,
          selectedTextStyle: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _webPrimary),
          textStyle: const TextStyle(fontSize: 20, color: _webTextMuted),
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
          color: isSelected ? _webPrimary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? _webPrimary : _webBorder),
          boxShadow: isSelected ? [BoxShadow(color: _webPrimary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : _webTextSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}