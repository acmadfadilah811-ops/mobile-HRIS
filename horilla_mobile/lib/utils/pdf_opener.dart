import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Unduh (dengan cache) lalu serahkan PDF ke aplikasi PDF bawaan HP lewat
/// [OpenFile.open] -- app ini tidak punya PDF viewer sendiri di dalamnya.
///
/// Dua mode berbeda sesuai jenis dokumennya:
/// - [openTemporaryPdf]: dipakai untuk Kontrak & Dokumen Perusahaan, yang
///   isinya bisa berubah (kontrak baru ditandatangani, SOP direvisi HR).
///   Disimpan di direktori temporary dan kedaluwarsa setelah [maxAge] --
///   setelah itu diunduh ulang alih-alih diam-diam menampilkan versi lama.
/// - [openPersistentPdf]: dipakai untuk Slip Gaji, yang seharusnya tidak
///   pernah berubah setelah diterbitkan. Disimpan permanen di penyimpanan
///   HP sebagai riwayat -- sekali diunduh, bisa dibuka lagi tanpa internet
///   dan tidak pernah diunduh ulang.
///
/// Keduanya mengembalikan `null` kalau berhasil, atau pesan error (untuk
/// ditampilkan lewat SnackBar) kalau gagal.

String _sanitizeFileName(String name) {
  return name.replaceAll(RegExp(r'[^A-Za-z0-9_\-.]'), '_');
}

/// Ekstensi berkas dari alamat unduhan. Kontrak yang diunggah HR bisa berupa
/// gambar (JPG/PNG); dulu SEMUA unduhan disimpan dengan akhiran `.pdf`, jadi
/// gambar tidak bisa dibuka. Alamat tanpa ekstensi (mis. unduhan slip gaji)
/// dianggap PDF.
String _extensionFromUrl(String url) {
  try {
    final segment = Uri.parse(url).pathSegments.last.toLowerCase();
    final dot = segment.lastIndexOf('.');
    if (dot != -1) {
      final ext = segment.substring(dot + 1);
      if (const ['pdf', 'jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
        return ext;
      }
    }
  } catch (_) {}
  return 'pdf';
}

String _mimeFor(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'application/pdf';
}

Future<String?> _downloadTo(File file, String url, String token) async {
  final response = await http.get(
    Uri.parse(url),
    headers: {"Authorization": "Bearer $token"},
  );
  if (response.statusCode != 200) {
    return 'Gagal mengunduh dokumen (${response.statusCode}).';
  }
  await file.writeAsBytes(response.bodyBytes);
  return null;
}

Future<String?> _openLocalFile(File file) async {
  final result = await OpenFile.open(file.path, type: _mimeFor(file.path));
  if (result.type != ResultType.done) {
    return 'Tidak ada aplikasi di HP ini untuk membuka dokumen (${result.message}).';
  }
  return null;
}

/// Cache-then-refresh lookup shared by [openTemporaryPdf] and
/// [getCachedPdfFile]: same local file, same "download again after
/// [maxAge]" rule -- factored out so a caller that wants to render the PDF
/// itself (an in-app viewer) and a caller that just wants to hand it to the
/// device's own PDF app don't duplicate the caching logic.
Future<({File? file, String? error})> _resolveTemporaryPdf(
  String url,
  String token,
  String cacheKey,
  Duration maxAge,
) async {
  try {
    final dir = await getTemporaryDirectory();
    final ext = _extensionFromUrl(url);
    final file = File('${dir.path}/${_sanitizeFileName(cacheKey)}.$ext');
    final prefs = await SharedPreferences.getInstance();
    final cacheKeyPref = 'pdf_cached_at_${_sanitizeFileName(cacheKey)}_$ext';
    final cachedAtMillis = prefs.getInt(cacheKeyPref);
    final isFresh = cachedAtMillis != null &&
        DateTime.now()
                .difference(DateTime.fromMillisecondsSinceEpoch(cachedAtMillis)) <
            maxAge;

    if (!file.existsSync() || !isFresh) {
      final error = await _downloadTo(file, url, token);
      if (error != null) return (file: null, error: error);
      await prefs.setInt(cacheKeyPref, DateTime.now().millisecondsSinceEpoch);
    }
    return (file: file, error: null);
  } catch (e) {
    return (file: null, error: 'Gagal mengunduh dokumen: $e');
  }
}

Future<String?> openTemporaryPdf(
  String url,
  String token,
  String cacheKey, {
  Duration maxAge = const Duration(hours: 12),
}) async {
  final result = await _resolveTemporaryPdf(url, token, cacheKey, maxAge);
  if (result.error != null) return result.error;
  return await _openLocalFile(result.file!);
}

/// Sama seperti [openTemporaryPdf] (cache 12 jam, diunduh ulang setelah
/// kedaluwarsa), tapi mengembalikan file lokalnya langsung alih-alih
/// menyerahkannya ke aplikasi PDF eksternal -- dipakai layar viewer PDF
/// in-app (lihat sop_pdf_viewer_page.dart) yang me-render sendiri lewat
/// flutter_pdfview.
Future<({File? file, String? error})> getCachedPdfFile(
  String url,
  String token,
  String cacheKey, {
  Duration maxAge = const Duration(hours: 12),
}) {
  return _resolveTemporaryPdf(url, token, cacheKey, maxAge);
}

Future<String?> openPersistentPdf(
  String url,
  String token,
  String fileName,
) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${_sanitizeFileName(fileName)}.pdf');

    if (!file.existsSync()) {
      final error = await _downloadTo(file, url, token);
      if (error != null) return error;
    }

    return await _openLocalFile(file);
  } catch (e) {
    return 'Gagal membuka dokumen: $e';
  }
}
