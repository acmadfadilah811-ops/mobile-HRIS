// Akses data layar baru (2026-11-15): data terakhir disimpan di HP sehingga layar langsung
// tampil saat dibuka, lalu data terbaru diambil di belakang dan tampilan diperbarui.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiGagal implements Exception {
  final String pesan;
  final int? kode;
  ApiGagal(this.pesan, [this.kode]);

  @override
  String toString() => pesan;
}

class ApiMobile {
  static const _batasWaktu = Duration(seconds: 20);
  static GlobalKey<NavigatorState>? _navigator;

  /// Dipanggil dari main.dart supaya sesi yang berakhir (401) bisa kembali ke layar login.
  static void pasangNavigator(GlobalKey<NavigatorState> kunci) => _navigator = kunci;

  static Future<(String, String)> _sesi() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final url = prefs.getString('typed_url');
    if (token == null || url == null) throw ApiGagal('Sesi berakhir, silakan masuk lagi.', 401);
    return (url, token);
  }

  static Future<Map<String, String>> _header({bool json = true}) async {
    final (_, token) = await _sesi();
    return {
      if (json) 'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<Uri> uri(String path) async {
    final (url, _) = await _sesi();
    return Uri.parse('$url$path');
  }

  static Future<void> _tanganiSesi(int kode) async {
    if (kode != 401) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    _navigator?.currentState?.pushNamedAndRemoveUntil('/login', (r) => false);
  }

  static dynamic _bacaBody(http.Response r) {
    if (r.body.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      return r.body;
    }
  }

  /// Ambil pesan galat yang enak dibaca dari respons DRF.
  static String pesanGalat(dynamic body, [String cadangan = 'Permintaan gagal, coba lagi.']) {
    if (body is Map) {
      for (final kunci in ['detail', 'error', 'message', 'non_field_errors']) {
        final v = body[kunci];
        if (v is String && v.isNotEmpty) return v;
        if (v is List && v.isNotEmpty) return v.map((e) => '$e').join(', ');
      }
      for (final v in body.values) {
        if (v is List && v.isNotEmpty) return v.map((e) => '$e').join(', ');
        if (v is String && v.isNotEmpty) return v;
      }
    }
    if (body is List && body.isNotEmpty) return body.map((e) => '$e').join(', ');
    return cadangan;
  }

  static Future<dynamic> _kirim(Future<http.Response> Function() aksi) async {
    http.Response r;
    try {
      r = await aksi().timeout(_batasWaktu);
    } on TimeoutException {
      throw ApiGagal('Server tidak menjawab. Periksa koneksi internet.');
    } catch (_) {
      throw ApiGagal('Tidak bisa terhubung ke server. Periksa koneksi internet.');
    }
    final body = _bacaBody(r);
    if (r.statusCode >= 200 && r.statusCode < 300) return body;
    await _tanganiSesi(r.statusCode);
    throw ApiGagal(pesanGalat(body), r.statusCode);
  }

  static Future<dynamic> get(String path) async {
    final u = await uri(path);
    final h = await _header();
    return _kirim(() => http.get(u, headers: h));
  }

  static Future<dynamic> put(String path, [Map<String, dynamic>? data]) async {
    final u = await uri(path);
    final h = await _header();
    return _kirim(() => http.put(u, headers: h, body: data == null ? null : jsonEncode(data)));
  }

  static Future<dynamic> postJson(String path, Map<String, dynamic> data) async {
    final u = await uri(path);
    final h = await _header();
    return _kirim(() => http.post(u, headers: h, body: jsonEncode(data)));
  }

  static Future<dynamic> delete(String path) async {
    final u = await uri(path);
    final h = await _header();
    return _kirim(() => http.delete(u, headers: h));
  }

  /// POST multipart (dipakai pengajuan cuti yang boleh membawa lampiran).
  static Future<dynamic> postMultipart(String path, Map<String, String> isian, {String? fileField, String? filePath}) async {
    final u = await uri(path);
    final h = await _header(json: false);
    final req = http.MultipartRequest('POST', u)
      ..headers.addAll(h)
      ..fields.addAll(isian);
    if (fileField != null && filePath != null) {
      req.files.add(await http.MultipartFile.fromPath(fileField, filePath));
    }
    return _kirim(() async => http.Response.fromStream(await req.send()));
  }

  // ------------------------------------------------------------------ cache di HP

  static Future<String> _kunciCache(String path) async {
    final prefs = await SharedPreferences.getInstance();
    return 'cache_v1:${prefs.getInt('employee_id') ?? 0}:$path';
  }

  static Future<dynamic> bacaCache(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final teks = prefs.getString(await _kunciCache(path));
    if (teks == null) return null;
    try {
      return jsonDecode(teks);
    } catch (_) {
      return null;
    }
  }

  static Future<void> simpanCache(String path, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(await _kunciCache(path), jsonEncode(data));
  }

  /// Ambil dari server lalu simpan ke HP. Galat diteruskan ke pemanggil.
  static Future<dynamic> segarkan(String path) async {
    final data = await get(path);
    await simpanCache(path, data);
    return data;
  }
}

/// Status pemuatan satu layar: `data` dari HP (bisa lama) lalu diganti data server.
class MuatData<T> {
  final T? data;
  final bool memuat;
  final String? galat;

  const MuatData({this.data, this.memuat = false, this.galat});
}

/// Mixin untuk layar: panggil `muatPath(path)` di initState; `muat` berisi data cache dulu,
/// lalu data server begitu tiba. Tarik ke bawah memanggil `segarkanPath`.
mixin MuatDenganCache<W extends StatefulWidget> on State<W> {
  MuatData<dynamic> muat = const MuatData(memuat: true);
  String? _path;

  Future<void> muatPath(String path) async {
    _path = path;
    final lama = await ApiMobile.bacaCache(path);
    if (!mounted || _path != path) return;
    setState(() => muat = MuatData(data: lama, memuat: true));
    await segarkanPath();
  }

  Future<void> segarkanPath() async {
    final path = _path;
    if (path == null) return;
    try {
      final baru = await ApiMobile.segarkan(path);
      if (!mounted || _path != path) return;
      setState(() => muat = MuatData(data: baru));
    } on ApiGagal catch (e) {
      if (!mounted || _path != path) return;
      setState(() => muat = MuatData(data: muat.data, galat: e.pesan));
    }
  }
}

void tampilkanPesan(BuildContext context, String pesan, {bool gagal = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(pesan),
      behavior: SnackBarBehavior.floating,
      backgroundColor: gagal ? const Color(0xFF7F1D1D) : const Color(0xFF1F2A55),
    ));
}
