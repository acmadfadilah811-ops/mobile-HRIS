import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'sop_pdf_viewer_page.dart';
import 'sop_upload_page.dart';

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

  // Tombol "Unggah SOP" hanya tampil di tab SOP, dan hanya untuk pengguna
  // yang lolos permission-check base.add_companydocument -- endpoint
  // generik yang sudah dipakai fitur lain di app ini (lihat
  // check-user-level di base/forms.py-nya web, base.add_companydocument
  // adalah permission yang sama dipakai form upload dashboard web). Server
  // (POST company-documents/create/) mengecek ulang izin yang sama, jadi
  // ini murni UX, bukan satu-satunya penjaga.
  bool _canUploadSop = false;

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
    // FAB unggah cuma relevan saat tab SOP aktif -- rebuild saat pindah tab.
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
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
    _checkUploadPermission();
  }

  Future<void> _checkUploadPermission() async {
    try {
      final uri = Uri.parse(
        '$baseUrl/api/base/check-user-level?perm=base.add_companydocument',
      );
      final response = await http.get(uri, headers: {
        "Authorization": "Bearer $token",
      });
      if (!mounted) return;
      setState(() => _canUploadSop = response.statusCode == 200);
    } catch (_) {
      // Diam-diam gagal: tombol unggah tetap tersembunyi, tidak ada dampak
      // lain -- melihat/membuka dokumen tetap jalan seperti biasa.
    }
  }

  Future<void> _openUploadPage() async {
    final uploaded = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SopUploadPage(baseUrl: baseUrl, token: token),
      ),
    );
    if (uploaded == true) {
      _loadCategory('sop');
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

  // Dokumen dengan `content` terisi dibaca langsung di app (lihat
  // CompanyDocumentDetailPage) -- tidak ada unduhan sama sekali. `content`
  // diutamakan di atas `file`: kalau HR mengisi keduanya, tetap tampil
  // sebagai teks di app, bukan didownload.
  bool _hasReadableContent(Map<String, dynamic> doc) {
    final content = doc['content'];
    return content is String && content.trim().isNotEmpty;
  }

  Future<void> _openDocument(Map<String, dynamic> doc) async {
    if (_hasReadableContent(doc)) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CompanyDocumentDetailPage(
            title: doc['title'] ?? '-',
            content: doc['content'] as String,
          ),
        ),
      );
      return;
    }

    final path = doc['file'];
    if (path == null) {
      _showError('File dokumen tidak tersedia.');
      return;
    }
    final url = path.toString().startsWith('http') ? path : '$baseUrl$path';
    // Dibuka lewat viewer PDF in-app (flutter_pdfview), bukan lagi
    // diserahkan ke aplikasi PDF eksternal -- lihat SopPdfViewerPage.
    // openingId hanya dipakai sebagai indikator loading singkat di list
    // sebelum halaman viewer terbuka (viewer punya loading state sendiri).
    setState(() => openingId = doc['id']);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SopPdfViewerPage(
          title: doc['title'] ?? '-',
          url: url,
          token: token,
          cacheKey: 'company_document_${doc['id']}',
        ),
      ),
    );
    if (mounted) setState(() => openingId = null);
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

  Widget _emptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ),
    );
  }

  Widget _docCard(Map<String, dynamic> doc) {
    final isOpening = openingId == doc['id'];
    final readable = _hasReadableContent(doc);
    return Card(
      child: ListTile(
        leading: Icon(
          readable ? Icons.menu_book_outlined : Icons.description_outlined,
          color: Colors.lightBlue,
        ),
        title: Text(doc['title'] ?? '-'),
        trailing: isOpening
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(readable ? Icons.chevron_right : Icons.picture_as_pdf_outlined),
        onTap: isOpening ? null : () => _openDocument(doc),
      ),
    );
  }

  // Corporate Guideline & Peraturan Perusahaan: satu dokumen company-wide,
  // daftar datar seperti semula -- tidak berjenjang (lihat CompanyDocument's
  // docstring di backend).
  Widget _categoryTab(String category) {
    if (_isLoading[category] == true) return _shimmerList();
    final docs = _documents[category] ?? [];
    if (docs.isEmpty) return _emptyState('Belum ada dokumen di kategori ini.');
    return RefreshIndicator(
      onRefresh: () => _loadCategory(category),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: docs.length,
        itemBuilder: (context, index) => _docCard(docs[index]),
      ),
    );
  }

  // SOP: berjenjang per divisi (department dari CompanyDocumentSerializer,
  // lihat backend) -- SOP Finance, SOP HR, SOP Kasir, dst masing-masing
  // punya bagiannya sendiri. Dokumen tanpa department (SOP umum, berlaku
  // lintas divisi) dikelompokkan di bagian "Umum" di bagian akhir.
  Widget _sopTab() {
    if (_isLoading['sop'] == true) return _shimmerList();
    final docs = _documents['sop'] ?? [];
    if (docs.isEmpty) return _emptyState('Belum ada dokumen SOP.');

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final doc in docs) {
      final dept = doc['department'];
      final label = (dept is Map && dept['name'] != null)
          ? dept['name'].toString()
          : 'Umum';
      grouped.putIfAbsent(label, () => []).add(doc);
    }
    final namedSections = grouped.keys.where((k) => k != 'Umum').toList()
      ..sort();
    final sections = [...namedSections, if (grouped.containsKey('Umum')) 'Umum'];

    return RefreshIndicator(
      onRefresh: () => _loadCategory('sop'),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
        itemCount: sections.length,
        itemBuilder: (context, sectionIndex) {
          final section = sections[sectionIndex];
          final sectionDocs = grouped[section]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                child: Text(
                  section,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                    color: Colors.black54,
                  ),
                ),
              ),
              ...sectionDocs.map(_docCard),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onSopTab = _tabController.index == 0; // 'sop' is _categories[0]
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
        children: _categories
            .map((c) => c['key'] == 'sop' ? _sopTab() : _categoryTab(c['key']!))
            .toList(),
      ),
      floatingActionButton: (onSopTab && _canUploadSop)
          ? FloatingActionButton.extended(
              onPressed: _openUploadPage,
              backgroundColor: Colors.lightBlue,
              icon: const Icon(Icons.upload_file),
              label: const Text('Unggah SOP'),
            )
          : null,
    );
  }
}

// --- Rendering teks in-app (SOP / Corporate Guideline / Peraturan
// Perusahaan) -----------------------------------------------------------
//
// Bukan markdown penuh dan sengaja tidak pakai package markdown eksternal
// (tidak ada satu pun renderer rich-text lain di app ini -- lihat
// announcements.dart, isinya juga Text() polos). Markup kecil, cukup untuk
// dokumen kebijakan yang isinya heading + bullet + kadang tabel 2 kolom:
//   "## judul"      -> sub-judul
//   "- poin"        -> item bullet
//   baris "a | b"   -> baris tabel kalau baris berikutnya berbentuk sama
//   baris kosong    -> pemisah paragraf
// Cerminan persis dari CompanyDocument.clean()'s docstring di base/models.py
// (backend) -- ubah bersamaan kalau salah satunya berubah.

enum _BlockType { heading, paragraph, bullets, table }

class _ContentBlock {
  final _BlockType type;
  final String? text;
  final List<String>? items;
  final List<List<String>>? rows;

  const _ContentBlock.heading(this.text)
      : type = _BlockType.heading,
        items = null,
        rows = null;
  const _ContentBlock.paragraph(this.text)
      : type = _BlockType.paragraph,
        items = null,
        rows = null;
  const _ContentBlock.bullets(this.items)
      : type = _BlockType.bullets,
        text = null,
        rows = null;
  const _ContentBlock.table(this.rows)
      : type = _BlockType.table,
        text = null,
        items = null;
}

List<String> _splitCells(String line) {
  return line
      .split('|')
      .map((c) => c.trim())
      .where((c) => c.isNotEmpty)
      .toList();
}

List<_ContentBlock> _parseContent(String content) {
  final lines = content.replaceAll('\r\n', '\n').split('\n');
  final blocks = <_ContentBlock>[];
  final paragraphBuffer = <String>[];

  void flushParagraph() {
    if (paragraphBuffer.isNotEmpty) {
      blocks.add(_ContentBlock.paragraph(paragraphBuffer.join(' ')));
      paragraphBuffer.clear();
    }
  }

  var i = 0;
  while (i < lines.length) {
    final trimmed = lines[i].trim();

    if (trimmed.isEmpty) {
      flushParagraph();
      i++;
      continue;
    }

    if (trimmed.startsWith('## ')) {
      flushParagraph();
      blocks.add(_ContentBlock.heading(trimmed.substring(3).trim()));
      i++;
      continue;
    }

    if (trimmed.startsWith('- ')) {
      flushParagraph();
      final items = <String>[];
      while (i < lines.length && lines[i].trim().startsWith('- ')) {
        items.add(lines[i].trim().substring(2).trim());
        i++;
      }
      blocks.add(_ContentBlock.bullets(items));
      continue;
    }

    if (trimmed.contains('|') &&
        i + 1 < lines.length &&
        lines[i + 1].trim().contains('|')) {
      final headerCells = _splitCells(trimmed);
      final nextCells = _splitCells(lines[i + 1]);
      if (headerCells.length >= 2 && headerCells.length == nextCells.length) {
        flushParagraph();
        final rows = <List<String>>[headerCells];
        i++;
        while (i < lines.length && lines[i].trim().contains('|')) {
          final rowCells = _splitCells(lines[i]);
          if (rowCells.length != headerCells.length) break;
          rows.add(rowCells);
          i++;
        }
        blocks.add(_ContentBlock.table(rows));
        continue;
      }
    }

    paragraphBuffer.add(trimmed);
    i++;
  }
  flushParagraph();
  return blocks;
}

class CompanyDocumentDetailPage extends StatelessWidget {
  final String title;
  final String content;

  const CompanyDocumentDetailPage({
    super.key,
    required this.title,
    required this.content,
  });

  Widget _renderBlock(_ContentBlock block) {
    switch (block.type) {
      case _BlockType.heading:
        return Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 10),
          child: Text(
            block.text!,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        );
      case _BlockType.bullets:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: block.items!
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 6, right: 10),
                          child: Icon(Icons.circle,
                              size: 5, color: Colors.black54),
                        ),
                        Expanded(
                          child: Text(
                            item,
                            style: const TextStyle(fontSize: 14, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        );
      case _BlockType.table:
        // Tabel sederhana (mis. tabel cuti, dua kolom) muat lebar layar dan
        // dibungkus rapi seperti biasa. Tabel matriks lebar (mis. tabel
        // pelanggaran & sanksi, bisa 8-10 kolom) akan jadi kolom sempit tak
        // terbaca kalau dipaksa muat -- jadi lebar kolom dibuat tetap dan
        // tabelnya di-scroll ke samping, bukan dipepetkan otomatis oleh
        // Table/Flex bawaan Flutter.
        final colCount = block.rows!.first.length;
        final table = Table(
          border: TableBorder.all(color: Colors.grey.shade300),
          columnWidths: colCount > 3
              ? {
                  for (var c = 0; c < colCount; c++) c: const FixedColumnWidth(150),
                }
              : null,
          children: [
            for (var r = 0; r < block.rows!.length; r++)
              TableRow(
                decoration:
                    r == 0 ? BoxDecoration(color: Colors.grey.shade100) : null,
                children: block.rows![r]
                    .map(
                      (cell) => Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          cell,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            fontWeight:
                                r == 0 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: colCount > 3
                ? Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: table,
                    ),
                  )
                : table,
          ),
        );
      case _BlockType.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            block.text!,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocks = _parseContent(content);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: blocks.map(_renderBlock).toList(),
      ),
    );
  }
}
