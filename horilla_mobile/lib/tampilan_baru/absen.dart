// Layar absen baru (2026-11-15). Aturannya sama dengan layar lama (checkin_checkout_form.dart):
// - deteksi wajah aktif  -> FaceScanner (verifikasi wajah lalu kirim absen, membawa lokasi bila geofence)
// - hanya geofence aktif -> POST clock-in/clock-out dengan latitude/longitude
// - keduanya mati        -> POST clock-in/clock-out tanpa isi
// Bedanya: layar langsung tampil dari data di HP (status absen dari cache Beranda, pengaturan
// wajah/geofence dari login), lokasi dicari sejak layar dibuka, dan status server dicek di belakang.
import 'dart:async';

import 'package:permission_handler/permission_handler.dart' show openAppSettings;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../checkin_checkout/checkin_checkout_views/face_detection.dart';
import '../data/api_mobile.dart';
import '../ui/tema.dart';

class Absen extends StatefulWidget {
  const Absen({super.key});

  @override
  State<Absen> createState() => _AbsenState();
}

class _AbsenState extends State<Absen> {
  bool? _sedangMasuk; // null = belum diketahui
  String? _jamMasuk;
  String? _shift;
  bool _wajah = false;
  bool _geofence = false;
  Position? _lokasi;
  String? _galatLokasi;
  bool _cariLokasi = false;
  bool _kirim = false;
  DateTime _kini = DateTime.now();
  Timer? _detik;

  @override
  void initState() {
    super.initState();
    _detik = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _kini = DateTime.now()));
    _mulai();
  }

  @override
  void dispose() {
    _detik?.cancel();
    super.dispose();
  }

  Future<void> _mulai() async {
    final prefs = await SharedPreferences.getInstance();
    final beranda = await ApiMobile.bacaCache('/api/mobile/beranda/');
    final hariIni = (beranda as Map?)?['hari_ini'] as Map?;
    if (!mounted) return;
    setState(() {
      _wajah = prefs.getBool('face_detection') ?? false;
      _geofence = prefs.getBool('geo_fencing') ?? false;
      if (hariIni != null) {
        _sedangMasuk = hariIni['status'] == 'masuk';
        _jamMasuk = hariIni['jam_masuk'];
        _shift = hariIni['shift'] == null ? null : '${hariIni['shift']} ${hariIni['jam_mulai'] ?? ''} - ${hariIni['jam_selesai'] ?? ''}';
      }
    });
    if (_geofence) _ambilLokasi();
    _cekStatusServer();
    _cekPengaturanWajah();
  }

  /// Server satu-satunya sumber kebenaran status masuk/pulang.
  Future<void> _cekStatusServer() async {
    try {
      final d = await ApiMobile.get('/api/attendance/checking-in');
      if (!mounted || d is! Map) return;
      setState(() {
        _sedangMasuk = d['status'] == true;
        if (_sedangMasuk == true && d['clock_in_time'] != null && d['clock_in_time'] != '-') {
          _jamMasuk ??= '${d['clock_in_time']}';
        }
      });
    } on ApiGagal {
      // tetap pakai data di HP; tombol kirim akan memberi pesan dari server bila salah
    }
  }

  /// Admin bisa menyalakan/mematikan deteksi wajah kapan saja; perbarui diam-diam.
  Future<void> _cekPengaturanWajah() async {
    try {
      final d = await ApiMobile.get('/api/facedetection/config/');
      if (d is Map && mounted) {
        final aktif = d['start'] == true;
        (await SharedPreferences.getInstance()).setBool('face_detection', aktif);
        setState(() => _wajah = aktif);
      }
    } on ApiGagal {
      // 404 = belum diatur -> biarkan nilai dari login
    }
  }

  Future<void> _ambilLokasi() async {
    setState(() {
      _cariLokasi = true;
      _galatLokasi = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw _LokasiGagal('GPS mati. Nyalakan layanan lokasi.', bukaGps: true);
      }
      var izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied) izin = await Geolocator.requestPermission();
      if (izin == LocationPermission.denied) throw _LokasiGagal('Izin lokasi ditolak.');
      if (izin == LocationPermission.deniedForever) {
        throw _LokasiGagal('Izin lokasi ditolak permanen. Buka pengaturan aplikasi.', bukaPengaturan: true);
      }
      final posisi = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
          .timeout(const Duration(seconds: 25));
      if (mounted) setState(() => _lokasi = posisi);
    } on _LokasiGagal catch (e) {
      if (mounted) setState(() => _galatLokasi = e.pesan);
      if (e.bukaGps) Geolocator.openLocationSettings();
      if (e.bukaPengaturan) openAppSettings();
    } on TimeoutException {
      if (mounted) setState(() => _galatLokasi = 'Lokasi belum didapat. Pindah ke tempat terbuka lalu coba lagi.');
    } catch (_) {
      if (mounted) setState(() => _galatLokasi = 'Gagal mendapatkan lokasi.');
    } finally {
      if (mounted) setState(() => _cariLokasi = false);
    }
  }

  String _jamSekarang() =>
      '${_kini.hour.toString().padLeft(2, '0')}:${_kini.minute.toString().padLeft(2, '0')}';

  Future<void> _absen() async {
    final masuk = _sedangMasuk != true;
    if (_geofence && _lokasi == null) {
      tampilkanPesan(context, 'Lokasi belum didapat. Tunggu sebentar atau tekan "Cari lagi".', gagal: true);
      return;
    }
    setState(() => _kirim = true);
    try {
      if (_wajah) {
        final hasil = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FaceScanner(
              userDetails: const {},
              userLocation: _lokasi,
              attendanceState: masuk ? 'NOT_CHECKED_IN' : 'CHECKED_IN',
            ),
          ),
        );
        final berhasil = hasil is Map && (hasil['checkedIn'] == true || hasil['checkedOut'] == true);
        if (!berhasil) return;
      } else {
        await ApiMobile.postJson(
          masuk ? '/api/attendance/clock-in/' : '/api/attendance/clock-out/',
          _geofence ? {'latitude': _lokasi!.latitude, 'longitude': _lokasi!.longitude} : {},
        );
      }
      await _sukses(masuk);
    } on ApiGagal catch (e) {
      if (mounted) _gagal(e.pesan);
    } finally {
      if (mounted) setState(() => _kirim = false);
    }
  }

  Future<void> _sukses(bool masuk) async {
    final jam = _jamSekarang();
    await (await SharedPreferences.getInstance()).setBool('clockCheckedIn', masuk);
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: Warna.latar, borderRadius: BorderRadius.circular(22)),
              child: const Icon(Icons.done_all_rounded, size: 34, color: Warna.ok),
            ),
            const SizedBox(height: 12),
            Text(masuk ? 'Absen masuk tercatat' : 'Absen pulang tercatat',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(masuk ? 'Pukul $jam. Selamat bekerja.' : 'Pukul $jam. Hati-hati di jalan.', style: Teks.kecil),
            const SizedBox(height: 18),
            TombolUtama('Kembali ke Beranda', onPressed: () => Navigator.pop(c)),
          ]),
        ),
      ),
    );
    if (mounted) Navigator.pop(context, true);
  }

  void _gagal(String pesan) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Absen gagal', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        content: Text(pesan),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK', style: TextStyle(color: Warna.ink)))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final masuk = _sedangMasuk != true;
    final judul = _sedangMasuk == null ? 'Absen' : (masuk ? 'Absen Masuk' : 'Absen Pulang');
    return Scaffold(
      appBar: AppBar(title: Text(judul)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          Container(
            height: 210,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const RadialGradient(colors: [Color(0xFF3A4572), Color(0xFF1B2347)], radius: .9),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(_wajah ? Icons.face_retouching_natural_rounded : Icons.fingerprint_rounded, color: Colors.white, size: 46),
              const SizedBox(height: 10),
              Text(
                _jamSekarang(),
                style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1),
              ),
              Text(tglPanjang(_kini), style: TextStyle(color: Colors.white.withOpacity(.75), fontSize: 12.5)),
            ]),
          ),
          const SizedBox(height: 14),
          Kartu(
            padding: EdgeInsets.zero,
            child: Column(children: [
              _baris(Icons.schedule_rounded, 'Shift', _shift ?? 'Mengikuti jadwal di HR'),
              const Divider(height: 1, color: Warna.garis),
              _baris(Icons.login_rounded, 'Jam masuk hari ini', _jamMasuk ?? (_sedangMasuk == null ? 'Memeriksa...' : 'Belum absen')),
              if (_geofence) ...[
                const Divider(height: 1, color: Warna.garis),
                _baris(
                  _lokasi != null ? Icons.location_on_rounded : Icons.location_searching_rounded,
                  'Lokasi',
                  _lokasi != null
                      ? 'Didapat, akurasi ${_lokasi!.accuracy.round()} m. Area kantor diperiksa server.'
                      : (_galatLokasi ?? 'Mencari lokasi...'),
                  aksi: !_cariLokasi && _lokasi == null ? 'Cari lagi' : null,
                  onAksi: _ambilLokasi,
                  memuat: _cariLokasi,
                ),
              ],
              const Divider(height: 1, color: Warna.garis),
              _baris(Icons.verified_user_outlined, 'Verifikasi',
                  _wajah ? 'Pindai wajah di langkah berikutnya' : 'Tanpa pindai wajah'),
            ]),
          ),
          const SizedBox(height: 18),
          TombolUtama(
            _sedangMasuk == null ? 'Memeriksa status...' : (masuk ? 'Absen Masuk Sekarang' : 'Absen Pulang Sekarang'),
            ikon: masuk ? Icons.login_rounded : Icons.logout_rounded,
            proses: _kirim,
            onPressed: _sedangMasuk == null || (_geofence && _lokasi == null) ? null : _absen,
          ),
        ],
      ),
    );
  }

  Widget _baris(IconData ikon, String label, String isi, {String? aksi, VoidCallback? onAksi, bool memuat = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Icon(ikon, size: 20, color: Warna.ink2),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: Teks.label),
            Text(isi, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Warna.ink)),
          ]),
        ),
        if (memuat) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Warna.muted)),
        if (aksi != null) TextButton(onPressed: onAksi, child: Text(aksi, style: const TextStyle(color: Warna.ink, fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

class _LokasiGagal implements Exception {
  final String pesan;
  final bool bukaGps;
  final bool bukaPengaturan;
  _LokasiGagal(this.pesan, {this.bukaGps = false, this.bukaPengaturan = false});
}
