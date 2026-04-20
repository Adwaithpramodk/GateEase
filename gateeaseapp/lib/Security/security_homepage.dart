import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:gateeaseapp/Security/scan_qr.dart';
import 'package:gateeaseapp/Security/security_group_pass.dart';
import 'package:gateeaseapp/login.dart';
import 'package:gateeaseapp/api_config.dart';

import 'package:shared_preferences/shared_preferences.dart';

class SecurityHomePage extends StatefulWidget {
  const SecurityHomePage({super.key});

  @override
  State<SecurityHomePage> createState() => _SecurityHomePageState();
}

class _SecurityHomePageState extends State<SecurityHomePage> {
  final Color themeColor = const Color.fromARGB(255, 252, 252, 252);
  final Color textColor = Colors.black;

  List<dynamic> allPasses = [];
  List<dynamic> filteredPasses = [];
  bool isLoading = true;
  Map<String, dynamic>? details;

  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    fetchApprovedPasses();
    getDetails();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginPage()),
      (route) => false,
    );
  }

  Future<void> getDetails() async {
    try {
      final response = await dio.get('$baseurl/Securityinfo_api/$lid');
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          details = response.data;
        });
      }
    } catch (e) {
      debugPrint('Get Details Error: $e');
    }
  }

  Future<void> fetchApprovedPasses() async {
    try {
      final response = await dio.get('$baseurl/SecurityApprovedPassAPI/$lid');
      if (!mounted) return;
      if (response.statusCode == 200) {
        allPasses = response.data;
        _filterByDate();
        setState(() => isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  void _filterByDate() {
    filteredPasses = allPasses.where((pass) {
      final passDate = DateTime.parse(pass['date']);
      return passDate.year == selectedDate.year &&
          passDate.month == selectedDate.month &&
          passDate.day == selectedDate.day;
    }).toList();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(
            context,
          ).copyWith(colorScheme: ColorScheme.light(primary: textColor)),
          child: child!,
        );
      },
    );

    if (!mounted) return;

    if (picked != null) {
      setState(() {
        selectedDate = picked;
        _filterByDate();
      });
    }
  }

  // =============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: themeColor,
      appBar: AppBar(
        backgroundColor: themeColor,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.home_outlined, color: Colors.black),
            SizedBox(width: 8),
            Text('Home', style: TextStyle(color: Colors.black)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.red),
                  ),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        logout();
                      },
                      child: const Text(
                        'Logout',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: textColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _profileCard(),
                  const SizedBox(height: 24),

                  const SizedBox(height: 16),
                  _scanButton(),

                  const SizedBox(height: 24),
                  _dateSelector(),
                  const SizedBox(height: 24),
                  _approvedPassList(),
                ],
              ),
            ),
    );
  }

  Widget _profileCard() {
    return Card(
      color: themeColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: textColor,
          backgroundImage: details?['Photo'] != null
              ? NetworkImage('$baseurl${details!['Photo']}')
              : null,
          child: details?['Photo'] == null
              ? const Icon(Icons.person, color: Colors.white)
              : null,
        ),
        title: Text(
          details?['name'] ?? 'Loading...',
          style: TextStyle(color: textColor),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        subtitle: Text(
          'Phone: ${details?['phone'] ?? ''}',
          style: TextStyle(color: textColor),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _scanButton() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScanQrPage()),
                );
                if (!mounted) return;
                fetchApprovedPasses();
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                foregroundColor: textColor,
                side: BorderSide(color: textColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SecurityGroupPassPage(),
                  ),
                );
              },
              icon: const Icon(Icons.group),
              label: const Text('Group Pass'),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                foregroundColor: textColor,
                side: BorderSide(color: textColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dateSelector() {
    return Card(
      color: themeColor,
      child: ListTile(
        leading: Icon(Icons.calendar_today, color: textColor),
        title: Text(
          "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}",
          style: TextStyle(color: textColor),
        ),
        trailing: Icon(Icons.edit_calendar, color: textColor),
        onTap: _pickDate,
      ),
    );
  }

  Widget _approvedPassList() {
    if (filteredPasses.isEmpty) {
      return Text(
        'No passes for selected date',
        style: TextStyle(color: textColor),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Approved Passes',
          style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
        ),
        const SizedBox(height: 12),
        ...filteredPasses.map(_passCard),
      ],
    );
  }

  Widget _passCard(dynamic pass) {
    return Card(
      color: themeColor,
      child: ListTile(
        title: Text(pass['name'], style: TextStyle(color: textColor)),
        subtitle: Text(
          "Reason: ${pass['reason']}\nTime: ${pass['time']}",
          style: TextStyle(color: textColor),
        ),
        trailing: Text(
          DateFormat(
            'MMM dd, yyyy',
          ).format(DateTime.parse(pass['date']).toLocal()),
          style: TextStyle(color: textColor),
        ),
      ),
    );
  }
}
