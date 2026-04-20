import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:gateeaseapp/api_config.dart';
import 'package:gateeaseapp/login.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final Dio dio = Dio();

  List<dynamic> allPasses = [];
  List<dynamic> filteredPasses = [];
  List<String> classes = [];

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

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> fetchExitReport() async {
    setState(() => isLoading = true);

    try {
      // Build query parameters
      Map<String, String> queryParams = {
        'search': searchQuery,
        'class': selectedClass == 'All' ? '' : selectedClass,
      };

      // Add date filter if selected
      if (selectedDate != null) {
        queryParams['date'] =
            '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}';
      }

      final response = await dio.get(
        '$baseurl/MentorExitReportAPI/$lid',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        setState(() {
          allPasses = data['passes'] ?? [];
          filteredPasses = allPasses;

          // Add 'All' option to classes
          List<String> classList = List<String>.from(data['classes'] ?? []);
          classes = ['All', ...classList];

          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching report: $e');
      setState(() => isLoading = false);
    }
  }

  void _applyFilters() {
    fetchExitReport();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
    }
  }

  void _clearDateFilter() {
    setState(() => selectedDate = null);
  }

  Future<void> _showExportDialog() async {
    // Check if data is loaded
    if (filteredPasses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No exit records found. Please wait for data to load or apply filters to see records.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    DateTime? startDate;
    DateTime? endDate;
    String exportType = 'Day'; // 'Day', 'Month', or 'Custom Range'
    String? selectedExportClass;

    // Use filteredPasses (what's currently displayed) for dropdown options
    // This ensures we only show classes that have data

    List<String> exportClasses = [
      'All',
      ...filteredPasses
          .where(
            (p) =>
                p['class'] != null &&
                p['class'].toString().isNotEmpty &&
                p['class'].toString() != '-',
          )
          .map((p) => p['class'].toString())
          .toSet()
          .toList()
        ..sort(),
    ];

    // Debug: Print available options
    debugPrint('📚 Available Classes: $exportClasses');
    debugPrint('📄 Total filtered passes: ${filteredPasses.length}');
    debugPrint('📄 Total all passes: ${allPasses.length}');

    // Debug: Print first pass if available
    if (filteredPasses.isNotEmpty) {
      debugPrint('📝 Sample pass data: ${filteredPasses.first}');
    }

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Export Exit Report'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select export period:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),

                    // Export Type Selection
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'Day',
                          label: Text('Day'),
                          icon: Icon(Icons.today, size: 16),
                        ),
                        ButtonSegment(
                          value: 'Month',
                          label: Text('Month'),
                          icon: Icon(Icons.calendar_month, size: 16),
                        ),
                        ButtonSegment(
                          value: 'Range',
                          label: Text('Range'),
                          icon: Icon(Icons.date_range, size: 16),
                        ),
                      ],
                      selected: {exportType},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          exportType = newSelection.first;
                          startDate = null;
                          endDate = null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Date Selection based on type
                    if (exportType == 'Day') ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today),
                        title: Text(
                          startDate == null
                              ? 'Select Date'
                              : DateFormat('dd MMM yyyy').format(startDate!),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: startDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => startDate = picked);
                          }
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ],

                    if (exportType == 'Month') ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_month),
                        title: Text(
                          startDate == null
                              ? 'Select Month'
                              : DateFormat('MMMM yyyy').format(startDate!),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () async {
                          final picked = await showMonthPicker(context);
                          if (picked != null) {
                            setState(() => startDate = picked);
                          }
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ],

                    if (exportType == 'Range') ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today),
                        title: Text(
                          startDate == null
                              ? 'Start Date'
                              : DateFormat('dd MMM yyyy').format(startDate!),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: startDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => startDate = picked);
                          }
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today),
                        title: Text(
                          endDate == null
                              ? 'End Date'
                              : DateFormat('dd MMM yyyy').format(endDate!),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: endDate ?? DateTime.now(),
                            firstDate: startDate ?? DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => endDate = picked);
                          }
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ],

                    const Divider(height: 32),

                    // Filter Section
                    const Text(
                      'Filter by Class:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),

                    // Class Filter
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButton<String>(
                        value: selectedExportClass,
                        hint: const Row(
                          children: [
                            Icon(Icons.class_, size: 20),
                            SizedBox(width: 8),
                            Text('Class'),
                          ],
                        ),
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: exportClasses.map((cls) {
                          return DropdownMenuItem(value: cls, child: Text(cls));
                        }).toList(),
                        onChanged: (value) {
                          setState(() => selectedExportClass = value);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // Check if class is selected
                    if (selectedExportClass == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select a Class'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    // Validate date selection
                    if (exportType == 'Day' && startDate != null) {
                      Navigator.pop(context);
                      _exportPDF(
                        startDate,
                        startDate,
                        exportType,
                        selectedExportClass,
                      );
                    } else if (exportType == 'Month' && startDate != null) {
                      Navigator.pop(context);
                      _exportPDF(
                        startDate,
                        startDate,
                        exportType,
                        selectedExportClass,
                      );
                    } else if (exportType == 'Range' &&
                        startDate != null &&
                        endDate != null) {
                      Navigator.pop(context);
                      _exportPDF(
                        startDate,
                        endDate,
                        exportType,
                        selectedExportClass,
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select date(s)')),
                      );
                    }
                  },
                  icon: const Icon(Icons.file_download),
                  label: const Text('Export'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<DateTime?> showMonthPicker(BuildContext context) async {
    DateTime selectedDate = DateTime.now();
    return await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Month'),
          content: SizedBox(
            height: 300,
            width: 300,
            child: YearPicker(
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              selectedDate: selectedDate,
              onChanged: (DateTime dateTime) {
                Navigator.pop(context, dateTime);
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportPDF(
    DateTime? startDate,
    DateTime? endDate,
    String type,
    String? className,
  ) async {
    try {
      // Show loading
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Generating PDF...')));

      // Filter passes based on date range and department/class
      List<dynamic> passesToExport = allPasses;

      // Filter by date
      if (type == 'Day' && startDate != null) {
        passesToExport = passesToExport.where((pass) {
          if (pass['date'] == null) return false;
          try {
            final passDate = DateFormat('dd-MM-yyyy').parse(pass['date']);
            return passDate.year == startDate.year &&
                passDate.month == startDate.month &&
                passDate.day == startDate.day;
          } catch (e) {
            return false;
          }
        }).toList();
      } else if (type == 'Month' && startDate != null) {
        passesToExport = passesToExport.where((pass) {
          if (pass['date'] == null) return false;
          try {
            final passDate = DateFormat('dd-MM-yyyy').parse(pass['date']);
            return passDate.year == startDate.year &&
                passDate.month == startDate.month;
          } catch (e) {
            return false;
          }
        }).toList();
      } else if (type == 'Range' && startDate != null && endDate != null) {
        passesToExport = passesToExport.where((pass) {
          if (pass['date'] == null) return false;
          try {
            final passDate = DateFormat('dd-MM-yyyy').parse(pass['date']);
            return passDate.isAfter(
                  startDate.subtract(const Duration(days: 1)),
                ) &&
                passDate.isBefore(endDate.add(const Duration(days: 1)));
          } catch (e) {
            return false;
          }
        }).toList();
      }

      // Filter by class (optional, not 'All')
      if (className != null && className != 'All') {
        passesToExport = passesToExport.where((pass) {
          return pass['class']?.toString().toLowerCase() ==
              className.toLowerCase();
        }).toList();
      }

      // Generate PDF
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Header
              pw.Header(
                level: 0,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Exit Pass Report',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      type == 'Day'
                          ? 'Date: ${DateFormat('dd MMMM yyyy').format(startDate!)}'
                          : type == 'Month'
                          ? 'Month: ${DateFormat('MMMM yyyy').format(startDate!)}'
                          : 'Period: ${DateFormat('dd MMM yyyy').format(startDate!)} - ${DateFormat('dd MMM yyyy').format(endDate!)}',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                    pw.Text(
                      'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Total Records: ${passesToExport.length}',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1),
                  4: const pw.FlexColumnWidth(2),
                  5: const pw.FlexColumnWidth(1.2),
                  6: const pw.FlexColumnWidth(1.2),
                },
                children: [
                  // Header Row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                    children: [
                      _pdfCell('Student Name', isHeader: true),
                      _pdfCell('Department', isHeader: true),
                      _pdfCell('Date', isHeader: true),
                      _pdfCell('Time', isHeader: true),
                      _pdfCell('Reason', isHeader: true),
                      _pdfCell('Mentor Status', isHeader: true),
                      _pdfCell('Security Status', isHeader: true),
                    ],
                  ),

                  // Data Rows
                  ...passesToExport.map((pass) {
                    return pw.TableRow(
                      children: [
                        _pdfCell(pass['student_name'] ?? '-'),
                        _pdfCell(pass['department'] ?? '-'),
                        _pdfCell(pass['date'] ?? '-'),
                        _pdfCell(pass['time'] ?? '-'),
                        _pdfCell(pass['reason'] ?? '-'),
                        _pdfCell(pass['mentor_status'] ?? '-'),
                        _pdfCell(pass['security_status'] ?? '-'),
                      ],
                    );
                  }),
                ],
              ),
            ];
          },
        ),
      );

      // Show PDF preview/print dialog
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF exported: ${passesToExport.length} records'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error exporting PDF: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  pw.Widget _pdfCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: isHeader ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 223, 223, 224),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 223, 223, 224),
        title: const Text('Exit Report'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.blue, Colors.blueAccent],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _showExportDialog,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.picture_as_pdf,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Export',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Row 1: Search Field (80%) + Date Icon Button
                Row(
                  children: [
                    // Search Bar
                    Expanded(
                      flex: 8,
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Search student...',
                          hintStyle: const TextStyle(fontSize: 14),
                          prefixIcon: const Icon(Icons.search, size: 20),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Colors.blue,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        onChanged: (value) {
                          setState(() => searchQuery = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Date Icon Button
                    IconButton(
                      onPressed: _selectDate,
                      icon: Icon(
                        Icons.calendar_today,
                        color: selectedDate != null
                            ? Colors.blue
                            : Colors.grey.shade600,
                      ),
                      tooltip: selectedDate == null
                          ? 'Select date filter'
                          : 'Date: ${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                      style: IconButton.styleFrom(
                        backgroundColor: selectedDate != null
                            ? Colors.blue.shade50
                            : Colors.grey.shade100,
                        padding: const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Row 2: Class Dropdown (70%) + Clear Button + Search Button
                Row(
                  children: [
                    // Class Filter
                    Expanded(
                      flex: 7,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButton<String>(
                          value: selectedClass,
                          isExpanded: true,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.arrow_drop_down, size: 20),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                          ),
                          items: classes.map((cls) {
                            return DropdownMenuItem(
                              value: cls,
                              child: Text(cls, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => selectedClass = value);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Clear Date Button (if date selected)
                    if (selectedDate != null)
                      IconButton(
                        onPressed: _clearDateFilter,
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Clear date filter',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red.shade50,
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    // Search Button
                    ElevatedButton.icon(
                      onPressed: _applyFilters,
                      icon: const Icon(
                        Icons.search,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Search',
                        style: TextStyle(fontSize: 14, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Results Count
          if (!isLoading)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Total Exits: ${filteredPasses.length}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          // List of Students
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredPasses.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No exit records found',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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

  Widget _buildPassCard(dynamic pass) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  child: Icon(Icons.person, color: Colors.green.shade700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pass['student_name'] ?? '-',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${pass['class']} • ${pass['department']}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    pass['status'] ?? 'Exited',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            Row(
              children: [
                Expanded(
                  child: _buildInfoTile(
                    Icons.calendar_today,
                    'Date',
                    pass['date'] ?? '-',
                  ),
                ),
                Expanded(
                  child: _buildInfoTile(
                    Icons.access_time,
                    'Time',
                    pass['time'] ?? '-',
                  ),
                ),
              ],
            ),

            if (pass['reason'] != null &&
                pass['reason'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoTile(Icons.info_outline, 'Reason', pass['reason']),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }
}
