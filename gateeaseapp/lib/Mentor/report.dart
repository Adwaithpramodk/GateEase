import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:gateeaseapp/api_config.dart';
import 'package:gateeaseapp/login.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:gateeaseapp/theme/app_theme.dart';

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
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppTheme.textPrimary),
        ),
        title: const Text(
          'Exit Report',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Material(
                color: const Color(0xFFEFEAFE),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _showExportDialog,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.picture_as_pdf_rounded,
                            color: AppTheme.primary, size: 18),
                        SizedBox(width: 7),
                        Text(
                          'Export PDF',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
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
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Find report records',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _applyFilters(),
                  decoration: InputDecoration(
                    hintText: 'Search by student name...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF9996AC),
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppTheme.primary,
                    ),
                    suffixIcon: searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search text',
                            onPressed: () {
                              searchController.clear();
                              _applyFilters();
                            },
                            icon: const Icon(Icons.close_rounded, size: 19),
                          ),
                    filled: true,
                    fillColor: const Color(0xFFF7F6FC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: Color(0xFFE8E6F2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: Color(0xFFE8E6F2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppTheme.primary,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(
                      child: _buildClassDropdown(),
                    ),
                    const SizedBox(width: 9),
                    _buildDateButton(),
                  ],
                ),
                if (selectedDate != null || selectedClass != 'All' ||
                    searchQuery.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        searchController.clear();
                        setState(() {
                          searchQuery = '';
                          selectedClass = 'All';
                          selectedDate = null;
                        });
                        fetchExitReport();
                      },
                      icon: const Icon(Icons.filter_alt_off_rounded, size: 17),
                      label: const Text('Clear all filters'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primary,
                    ),
                  )
                : filteredPasses.isEmpty
                    ? _buildEmptyReportState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(18, 17, 18, 24),
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

  Widget _buildClassDropdown() {
    return Container(
      height: 49,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F6FC),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE8E6F2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: classes.contains(selectedClass) ? selectedClass : 'All',
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppTheme.primary,
          ),
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          items: classes.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value, overflow: TextOverflow.ellipsis),
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
    );
  }

  Widget _buildDateButton() {
    return Material(
      color: selectedDate == null
          ? const Color(0xFFF7F6FC)
          : const Color(0xFFEFEAFE),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: selectedDate ?? DateTime.now(),
            firstDate: DateTime(2024),
            lastDate: DateTime.now(),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AppTheme.primary,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: AppTheme.textPrimary,
                  ),
                ),
                child: child!,
              );
            },
          );
          if (picked != null) {
            setState(() => selectedDate = picked);
            fetchExitReport();
          }
        },
        child: Container(
          height: 49,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selectedDate == null
                  ? const Color(0xFFE8E6F2)
                  : AppTheme.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 18,
                color: selectedDate == null
                    ? AppTheme.textSecondary
                    : AppTheme.primary,
              ),
              const SizedBox(width: 7),
              Text(
                selectedDate == null
                    ? 'Date'
                    : DateFormat('dd MMM').format(selectedDate!),
                style: TextStyle(
                  color: selectedDate == null
                      ? AppTheme.textSecondary
                      : AppTheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (selectedDate != null) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: () {
                    setState(() => selectedDate = null);
                    fetchExitReport();
                  },
                  child: const Icon(
                    Icons.close_rounded,
                    size: 15,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyReportState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.13),
        const Icon(
          Icons.manage_search_rounded,
          size: 62,
          color: Color(0xFFC7C3D8),
        ),
        const SizedBox(height: 14),
        const Center(
          child: Text(
            'No records found',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text(
            'Try changing your search or filters.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPassCard(Map<String, dynamic> pass) {
    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFECEAF5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF28204F).withValues(alpha: 0.035),
            blurRadius: 13,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
        color: isExited ? AppTheme.successLight : AppTheme.warningLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isExited ? AppTheme.success.withValues(alpha: 0.3) : AppTheme.warning.withValues(alpha: 0.3)),
      ),
      child: Text(
        isExited ? 'EXITED' : 'PENDING',
        style: TextStyle(
          color: isExited ? AppTheme.success : AppTheme.warning,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
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
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(23),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 58,
                width: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFEAFE),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: AppTheme.primary,
                  size: 29,
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'Export report',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Generate a PDF containing ${filteredPasses.length} currently visible ${filteredPasses.length == 1 ? 'record' : 'records'}?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 21),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.of(dialogContext).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        minimumSize: const Size(0, 46),
                        side: const BorderSide(color: Color(0xFFE5E2EF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        _generatePDF();
                      },
                      icon: const Icon(Icons.download_rounded, size: 17),
                      label: const Text('Export PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(0, 46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
