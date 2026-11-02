import 'package:flutter/material.dart';
import 'package:gateeaseapp/api_config.dart';

class AnnouncementPage extends StatefulWidget {
  const AnnouncementPage({super.key});

  @override
  State<AnnouncementPage> createState() => _AnnouncementPageState();
}

class _AnnouncementPageState extends State<AnnouncementPage> {
  static const Color primary = Color(0xFF6D4AE5);

  static const Color primaryLight = Color(0xFFEFEAFE);
  static const Color pageColor = Color(0xFFEEEDF8);
  static const Color ink = Color(0xFF1B1840);
  static const Color muted = Color(0xFF6C6A86);
  static const Color borderColor = Color(0xFFE8E6F5);
  static const Color orange = Color(0xFFFF9A3D);

  final List<Map<String, dynamic>> announcements = [];
  bool isLoading = true;
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    fetchAnnouncements();
  }

  Future<void> fetchAnnouncements() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        hasError = false;
      });
    }

    try {
      // This endpoint returns active announcements that have not expired.
      final response = await dio.get('$baseurl/ViewannouncementAPI');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final dynamic body = response.data;
        final dynamic rows = body is List
            ? body
            : (body is Map ? (body['data'] ?? body['announcements'] ?? []) : []);

        setState(() {
          announcements
            ..clear()
            ..addAll(
              rows is List
                  ? rows.whereType<Map>().map(
                      (item) => Map<String, dynamic>.from(item),
                    )
                  : <Map<String, dynamic>>[],
            );
          isLoading = false;
          hasError = false;
        });
      } else {
        setState(() {
          isLoading = false;
          hasError = true;
        });
      }
    } catch (e) {
      debugPrint('Fetch announcements error: $e');
      if (!mounted) return;
      setState(() {
        isLoading = false;
        hasError = true;
      });
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'Date unavailable';
    final parsed = DateTime.tryParse(value.toString())?.toLocal();
    if (parsed == null) return value.toString();

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final day = parsed.day.toString().padLeft(2, '0');
    final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
    final minute = parsed.minute.toString().padLeft(2, '0');
    final period = parsed.hour >= 12 ? 'PM' : 'AM';
    return '$day ${months[parsed.month - 1]} ${parsed.year} • $hour:$minute $period';
  }

  String _value(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: primary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 4,
        title: const Text(
          'Announcements',
          style: TextStyle(
            color: ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        iconTheme: const IconThemeData(color: primary),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: primary,
          backgroundColor: Colors.white,
          onRefresh: fetchAnnouncements,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                  child: _buildHeader(),
                ),
              ),
              if (isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: primary),
                  ),
                )
              else if (hasError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildErrorState(),
                )
              else if (announcements.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _buildAnnouncementCard(announcements[index]),
                      childCount: announcements.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7650EA), Color(0xFF6240D8)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x295032AA),
            blurRadius: 15,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.17),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.campaign_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CAMPUS UPDATES',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Important notices and updates from your college.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> item) {
    final title = _value(item['title'], fallback: 'Announcement');
    final message = _value(item['message'], fallback: 'No details available.');
    final createdAt = item['created_at'];
    final expiresAt = item['expires_at'];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D392A70),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: primaryLight,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF8F1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'NEW',
                  style: TextStyle(
                    color: Color(0xFF218653),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            message,
            style: const TextStyle(
              color: muted,
              fontSize: 13,
              height: 1.55,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 15),
          const Divider(height: 1, color: borderColor),
          const SizedBox(height: 11),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 14, color: muted),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  _formatDate(createdAt),
                  style: const TextStyle(
                    color: muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (expiresAt != null) ...[
                const Icon(Icons.event_busy_rounded, size: 13, color: orange),
                const SizedBox(width: 4),
                Text(
                  'Until ${_formatDate(expiresAt)}',
                  style: const TextStyle(
                    color: muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No announcements yet',
              style: TextStyle(
                color: ink,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'College announcements will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: Color(0xFFF25C5C),
              size: 42,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load announcements',
              style: TextStyle(
                color: ink,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: fetchAnnouncements,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
