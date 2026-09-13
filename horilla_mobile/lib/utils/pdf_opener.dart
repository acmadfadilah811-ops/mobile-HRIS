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
  final result = await OpenFile.open(file.path);
  if (result.type != ResultType.done) {
    return 'Tidak ada aplikasi PDF di HP ini untuk membuka dokumen (${result.message}).';
  }
  return null;
}

Future<String?> openTemporaryPdf(
  String url,
  String token,
  String cacheKey, {
  Duration maxAge = const Duration(hours: 12),
}) async {
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_sanitizeFileName(cacheKey)}.pdf');
    final prefs = await SharedPreferences.getInstance();
    final cacheKeyPref = 'pdf_cached_at_${_sanitizeFileName(cacheKey)}';
    final cachedAtMillis = prefs.getInt(cacheKeyPref);
    final isFresh = cachedAtMillis != null &&
        DateTime.now()
                .difference(DateTime.fromMillisecondsSinceEpoch(cachedAtMillis)) <
            maxAge;

    if (!file.existsSync() || !isFresh) {
      final error = await _downloadTo(file, url, token);
      if (error != null) return error;
      await prefs.setInt(cacheKeyPref, DateTime.now().millisecondsSinceEpoch);
    }

    return await _openLocalFile(file);
  } catch (e) {
    return 'Gagal membuka dokumen: $e';
  }
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
