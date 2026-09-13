import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  final ScrollController _scrollController = ScrollController();
  String baseUrl = '';
  String token = '';
  List<Map<String, dynamic>> announcements = [];
  bool isLoading = true;
  bool isFetching = false;
  bool hasMore = true;
  int currentPage = 1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _init();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !isFetching &&
        hasMore) {
      currentPage++;
      _fetchPage(currentPage, reset: false);
    }
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString("typed_url") ?? '';
    token = prefs.getString("token") ?? '';
    await _fetchPage(1, reset: true);
  }

  Future<void> _fetchPage(int page, {required bool reset}) async {
    if (isFetching) return;
    setState(() => isFetching = true);
    try {
      final uri = Uri.parse('$baseUrl/api/base/announcement-view?page=$page');
      final response = await http.get(uri, headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      });
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = (data['results'] as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        setState(() {
          if (reset) {
            currentPage = 1;
            announcements = results;
          } else {
            announcements.addAll(results);
          }
          hasMore = data['next'] != null;
        });
      } else {
        setState(() => hasMore = false);
      }
    } finally {
      if (mounted) {
        setState(() {
          isFetching = false;
          isLoading = false;
        });
      }
    }
  }

  Future<void> _markViewed(Map<String, dynamic> announcement) async {
    if (announcement['has_viewed'] == true) return;
    setState(() => announcement['has_viewed'] = true);
    try {
      final uri = Uri.parse(
          '$baseUrl/api/base/announcements/${announcement['id']}/mark-viewed/');
      await http.post(uri, headers: {"Authorization": "Bearer $token"});
    } catch (_) {
      // Kegagalan menandai-dibaca tidak fatal -- pengumuman tetap sudah
      // terbaca oleh karyawan meski status di server belum terupdate.
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      return DateFormat('d MMM yyyy').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  Widget _shimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 5,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Container(
          height: 80,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengumuman')),
      body: isLoading
          ? _shimmerList()
          : announcements.isEmpty
              ? Center(
                  child: Text(
                    'Belum ada pengumuman.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _fetchPage(1, reset: true),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: announcements.length + (hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= announcements.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final announcement = announcements[index];
                      final isUnread = announcement['has_viewed'] != true;
                      final content =
                          (announcement['content'] as List?) ?? [];
                      return Card(
                        child: ExpansionTile(
                          leading: Icon(
                            isUnread
                                ? Icons.mark_email_unread_outlined
                                : Icons.mark_email_read_outlined,
                            color: isUnread ? Colors.lightBlue : Colors.grey,
                          ),
                          title: Text(
                            announcement['title'] ?? '-',
                            style: TextStyle(
                              fontWeight: isUnread
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            _formatDate(announcement['created_at']),
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          onExpansionChanged: (expanded) {
                            if (expanded) _markViewed(announcement);
                          },
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: content.isEmpty
                                    ? [const Text('(Tidak ada isi)')]
                                    : content.map<Widget>((block) {
                                        final isHeading =
                                            block['type'] == 'heading';
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 8),
                                          child: Text(
                                            block['text'] ?? '',
                                            style: TextStyle(
                                              fontWeight: isHeading
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              fontSize: isHeading ? 16 : 14,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
