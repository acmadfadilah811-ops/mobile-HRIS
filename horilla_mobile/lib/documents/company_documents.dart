import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import '../utils/pdf_opener.dart';

class CompanyDocuments extends StatefulWidget {
  const CompanyDocuments({super.key});

  @override
  State<CompanyDocuments> createState() => _CompanyDocumentsState();
}

class _CompanyDocumentsState extends State<CompanyDocuments>
    with SingleTickerProviderStateMixin {
  static const _categories = [
    {'key': 'sop', 'label': 'SOP'},
    {'key': 'corporate_guideline', 'label': 'Corporate Guideline'},
    {'key': 'company_regulation', 'label': 'Peraturan Perusahaan'},
  ];

  late TabController _tabController;
  String baseUrl = '';
  String token = '';
  int? openingId;

  final Map<String, bool> _isLoading = {
    for (var c in _categories) c['key']!: true,
  };
  final Map<String, List<Map<String, dynamic>>> _documents = {
    for (var c in _categories) c['key']!: [],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      baseUrl = prefs.getString("typed_url") ?? '';
      token = prefs.getString("token") ?? '';
    });
    for (var c in _categories) {
      _loadCategory(c['key']!);
    }
  }

  Future<void> _loadCategory(String category) async {
    setState(() => _isLoading[category] = true);
    try {
      final uri =
          Uri.parse('$baseUrl/api/base/company-documents/?category=$category');
      final response = await http.get(uri, headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      });
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _documents[category] = (data['results'] as List)
              .map((e) => e as Map<String, dynamic>)
              .toList();
        });
      }
    } finally {
      setState(() => _isLoading[category] = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.lightBlue),
    );
  }

  Future<void> _openDocument(Map<String, dynamic> doc) async {
    setState(() => openingId = doc['id']);
    final path = doc['file'];
    if (path == null) {
      setState(() => openingId = null);
      _showError('File dokumen tidak tersedia.');
      return;
    }
    final url = path.toString().startsWith('http') ? path : '$baseUrl$path';
    final error = await openTemporaryPdf(
      url,
      token,
      'company_document_${doc['id']}',
    );
    setState(() => openingId = null);
    if (error != null) _showError(error);
  }

  Widget _shimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 4,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Container(
          height: 72,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _categoryTab(String category) {
    if (_isLoading[category] == true) return _shimmerList();
    final docs = _documents[category] ?? [];
    if (docs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Belum ada dokumen di kategori ini.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _loadCategory(category),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: docs.length,
        itemBuilder: (context, index) {
          final doc = docs[index];
          final isOpening = openingId == doc['id'];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.description_outlined, color: Colors.lightBlue),
              title: Text(doc['title'] ?? '-'),
              trailing: isOpening
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
              onTap: isOpening ? null : () => _openDocument(doc),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dokumen Perusahaan'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.lightBlue,
          indicatorColor: Colors.lightBlue,
          unselectedLabelColor: Colors.grey,
          tabs: _categories.map((c) => Tab(text: c['label'])).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children:
            _categories.map((c) => _categoryTab(c['key']!)).toList(),
      ),
    );
  }
}
