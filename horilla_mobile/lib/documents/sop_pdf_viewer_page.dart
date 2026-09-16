import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import '../utils/pdf_opener.dart';

/// Menampilkan PDF langsung di dalam app (SOP dan dokumen ber-file lainnya),
/// bukan lagi menyerahkannya ke aplikasi PDF eksternal lewat OpenFile --
/// pakai flutter_pdfview yang sudah lama jadi dependency tapi belum pernah
/// dipakai di mana pun sebelum ini. Mengunduh dulu (dengan cache yang sama
/// seperti alur lama, lihat pdf_opener.dart) baru me-render dari file lokal
/// -- flutter_pdfview merender dari path file, tidak menerima byte stream.
class SopPdfViewerPage extends StatefulWidget {
  final String title;
  final String url;
  final String token;
  final String cacheKey;

  const SopPdfViewerPage({
    super.key,
    required this.title,
    required this.url,
    required this.token,
    required this.cacheKey,
  });

  @override
  State<SopPdfViewerPage> createState() => _SopPdfViewerPageState();
}

class _SopPdfViewerPageState extends State<SopPdfViewerPage> {
  String? _localPath;
  String? _error;
  int _pageCount = 0;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result =
        await getCachedPdfFile(widget.url, widget.token, widget.cacheKey);
    if (!mounted) return;
    setState(() {
      if (result.file != null) {
        _localPath = result.file!.path;
      } else {
        _error = result.error ?? 'Gagal memuat dokumen.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: _pageCount > 0
            ? PreferredSize(
                preferredSize: const Size.fromHeight(22),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Halaman ${_currentPage + 1} / $_pageCount',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),
              )
            : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  setState(() => _error = null);
                  _load();
                },
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (_localPath == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return PDFView(
      filePath: _localPath!,
      autoSpacing: true,
      pageSnap: true,
      onRender: (pages) {
        if (!mounted) return;
        setState(() => _pageCount = pages ?? 0);
      },
      onPageChanged: (page, total) {
        if (!mounted) return;
        setState(() => _currentPage = page ?? 0);
      },
      onError: (e) {
        if (!mounted) return;
        setState(() => _error = 'Gagal menampilkan PDF: $e');
      },
    );
  }
}
