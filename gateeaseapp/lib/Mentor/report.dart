import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:gateeaseapp/api_config.dart';
import 'package:gateeaseapp/login.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  List<dynamic> allPasses = [];
  List<dynamic> filteredPasses = [];
  List<String> classes = ['All'];
  
  bool isLoading = true;
  String searchQuery = '';
  String selectedClass = 'All';
  DateTime? selectedDate;
  
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchExitReport();
  }

  Future<void> fetchExitReport() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      // Ensure we have lid
      if (lid == null) {
        final prefs = await SharedPreferences.getInstance();
        lid = prefs.getInt('lid');
      }

      if (lid == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      Map<String, String> queryParams = {
        'search': searchQuery,
        'class': selectedClass == 'All' ? '' : selectedClass,
      };

      if (selectedDate != null) {
        queryParams['date'] = DateFormat('yyyy-MM-dd').format(selectedDate!);
      }

      final response = await dio.get(
        '$baseurl/MentorExitReportAPI/$lid',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (mounted) {
          setState(() {
            allPasses = data['passes'] ?? [];
            filteredPasses = allPasses;
            
            List<String> incomingClasses = List<String>.from(data['classes'] ?? []);
            classes = ['All', ...incomingClasses];
            isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching report: $e');
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load records')),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      searchQuery = searchController.text.trim();
    });
    fetchExitReport();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Exit Report', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            onPressed: _showExportDialog,
            icon: const Icon(Icons.picture_as_pdf, color: Colors.blue),
            tooltip: 'Export PDF',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Search student...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onSubmitted: (_) => _applyFilters(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? DateTime.now(),
                          firstDate: DateTime(2024),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => selectedDate = picked);
                          fetchExitReport();
                        }
                      },
                      icon: Icon(Icons.calendar_today, 
                        color: selectedDate != null ? Colors.blue : Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: classes.contains(selectedClass) ? selectedClass : 'All',
                            isExpanded: true,
                            items: classes.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (newValue) {
                              if (newValue != null) {
                                setState(() => selectedClass = newValue);
                                fetchExitReport();
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        searchController.clear();
                        setState(() {
                          searchQuery = '';
                          selectedClass = 'All';
                          selectedDate = null;
                        });
                        fetchExitReport();
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Data List
          Expanded(
            child: isLoading 
              ? const Center(child: CircularProgressIndicator())
              : filteredPasses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        const Text('No records found', 
                          style: TextStyle(fontSize: 16, color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredPasses.length,
                    itemBuilder: (context, index) {
                      final pass = filteredPasses[index];
                      return _buildPassCard(pass);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassCard(Map<String, dynamic> pass) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  child: const Icon(Icons.person, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pass['student_name'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('${pass['class']} • ${pass['department']}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
                _buildStatusBadge(pass['security_status']),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _infoItem(Icons.calendar_month, pass['date'] ?? '-'),
                _infoItem(Icons.access_time, pass['time'] ?? '-'),
              ],
            ),
            if (pass['reason'] != null && pass['reason'] != '-') ...[
              const SizedBox(height: 8),
              _infoItem(Icons.notes, pass['reason'], isFullWidth: true),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String? status) {
    bool isExited = status == 'scanned' || status == 'approved';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isExited ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isExited ? Colors.green.shade200 : Colors.orange.shade200),
      ),
      child: Text(
        isExited ? 'EXITED' : 'PENDING',
        style: TextStyle(
          color: isExited ? Colors.green.shade700 : Colors.orange.shade800,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _infoItem(IconData icon, String text, {bool isFullWidth = false}) {
    return Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  // --- PDF Export Logic ---
  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Report'),
        content: const Text('Generate a PDF report of all visible records?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _generatePDF();
            },
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePDF() async {
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating PDF...')));
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.MultiPage(
          build: (context) => [
            pw.Header(level: 0, child: pw.Text('GateEase Exit Report')),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              context: context,
              data: [
                ['Student', 'Class', 'Date', 'Time', 'Status'],
                ...filteredPasses.map((p) => [
                  p['student_name'] ?? '-',
                  p['class'] ?? '-',
                  p['date'] ?? '-',
                  p['time'] ?? '-',
                  p['security_status']?.toString().toUpperCase() ?? 'PENDING'
                ])
              ],
            ),
          ],
        ),
      );

      await Printing.layoutPdf(onLayout: (format) => pdf.save());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }
}
