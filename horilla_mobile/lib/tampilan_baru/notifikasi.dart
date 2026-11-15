// Notifikasi (2026-11-15): /api/notifications/notifications/list/all, ketuk = tandai dibaca,
// geser = hapus, "Tandai semua dibaca" di kanan atas.
import 'package:flutter/material.dart';

import '../data/api_mobile.dart';
import '../ui/tema.dart';

/// Teks notifikasi bawaan Horilla berbahasa Inggris; terjemahkan yang paling sering muncul.
String terjemahkanNotifikasi(String t) {
  const peta = {
    'Your Leave request has been approved': 'Pengajuan cuti Anda disetujui',
    'Your Leave request has been rejected': 'Pengajuan cuti Anda ditolak',
    'Your leave request has been canceled': 'Pengajuan cuti Anda dibatalkan',
    'Your attendance request has been approved': 'Koreksi absensi Anda disetujui',
    'Your attendance request has been rejected': 'Koreksi absensi Anda ditolak',
  };
  for (final e in peta.entries) {
    if (t.toLowerCase().startsWith(e.key.toLowerCase())) return e.value;
  }
  return t;
}

String _waktuLalu(dynamic v) {
  final d = tanggalDari(v)?.toLocal();
  if (d == null) return '';
  final selisih = DateTime.now().difference(d);
  if (selisih.inMinutes < 1) return 'baru saja';
  if (selisih.inMinutes < 60) return '${selisih.inMinutes} menit lalu';
  if (selisih.inHours < 24) return '${selisih.inHours} jam lalu';
  if (selisih.inDays < 7) return '${selisih.inDays} hari lalu';
  return tglPendek(d.toIso8601String());
}

class Notifikasi extends StatefulWidget {
  const Notifikasi({super.key});

  @override
  State<Notifikasi> createState() => _NotifikasiState();
}

class _NotifikasiState extends State<Notifikasi> {
  static const _path = '/api/notifications/notifications/list/all?page=1';
  List<Map> _daftar = [];
  bool _memuat = true;
  String? _galat;
  int _halaman = 1;
  bool _adaLagi = false;
  bool _memuatLagi = false;

  @override
  void initState() {
    super.initState();
    _awal();
  }

  List<Map> _ambil(dynamic d) =>
      ((d is Map ? d['results'] as List? : null) ?? []).cast<Map>().where((n) => n['deleted'] != true).toList();

  Future<void> _awal() async {
    final cache = await ApiMobile.bacaCache(_path);
    if (cache != null && mounted) setState(() => _daftar = _ambil(cache));
    await _segarkan();
  }

  Future<void> _segarkan() async {
    try {
      final d = await ApiMobile.segarkan(_path);
      if (!mounted) return;
      setState(() {
        _daftar = _ambil(d);
        _halaman = 1;
        _adaLagi = d['next'] != null;
        _galat = null;
      });
    } on ApiGagal catch (e) {
      if (mounted) setState(() => _galat = e.pesan);
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  Future<void> _lagi() async {
    if (_memuatLagi || !_adaLagi) return;
    setState(() => _memuatLagi = true);
    try {
      final d = await ApiMobile.get('/api/notifications/notifications/list/all?page=${_halaman + 1}');
      if (!mounted) return;
      setState(() {
        _daftar.addAll(_ambil(d));
        _halaman++;
        _adaLagi = d['next'] != null;
      });
    } on ApiGagal {
      // biarkan; tarik ke bawah untuk mencoba lagi
    } finally {
      if (mounted) setState(() => _memuatLagi = false);
    }
  }

  Future<void> _baca(Map n) async {
    if (n['unread'] != true) return;
    setState(() => n['unread'] = false);
    try {
      await ApiMobile.postJson('/api/notifications/notifications/${n['id']}/', {});
    } on ApiGagal {
      // tidak fatal
    }
  }

  Future<void> _bacaSemua() async {
    setState(() {
      for (final n in _daftar) {
        n['unread'] = false;
      }
    });
    try {
      await ApiMobile.postJson('/api/notifications/notifications/bulk-read/', {});
      if (mounted) tampilkanPesan(context, 'Semua notifikasi ditandai dibaca.');
    } on ApiGagal catch (e) {
      if (mounted) tampilkanPesan(context, e.pesan, gagal: true);
    }
  }

  Future<void> _hapus(Map n) async {
    setState(() => _daftar.remove(n));
    try {
      await ApiMobile.delete('/api/notifications/notifications/${n['id']}/');
    } on ApiGagal catch (e) {
      if (mounted) tampilkanPesan(context, e.pesan, gagal: true);
      _segarkan();
    }
  }

  @override
  Widget build(BuildContext context) {
    final adaBelumDibaca = _daftar.any((n) => n['unread'] == true);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          if (adaBelumDibaca)
            TextButton(
              onPressed: _bacaSemua,
              child: const Text('Tandai dibaca', style: TextStyle(color: Warna.ink, fontWeight: FontWeight.w700)),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        color: Warna.navy,
        onRefresh: _segarkan,
        child: NotificationListener<ScrollNotification>(
          onNotification: (s) {
            if (s.metrics.pixels > s.metrics.maxScrollExtent - 300) _lagi();
            return false;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (_galat != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_galat!, style: Teks.kecil)),
              if (_memuat && _daftar.isEmpty)
                const Kerangka(tinggi: 260, radius: 16)
              else if (_daftar.isEmpty)
                const Kartu(child: PesanKosong(ikon: Icons.notifications_none_rounded, judul: 'Belum ada notifikasi'))
              else ...[
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('Geser ke kiri untuk menghapus.', style: Teks.kecil),
                ),
                Kartu(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    for (var i = 0; i < _daftar.length; i++) _baris(_daftar[i], i == _daftar.length - 1),
                  ]),
                ),
              ],
              if (_memuatLagi)
                const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Warna.muted))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _baris(Map n, bool terakhir) {
    final baru = n['unread'] == true;
    return Dismissible(
      key: ValueKey('notif-${n['id']}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: const Color(0xFFFEF2F2),
        child: const Icon(Icons.delete_outline_rounded, color: Warna.tolak),
      ),
      onDismissed: (_) => _hapus(n),
      child: InkWell(
        onTap: () => _baca(n),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(border: terakhir ? null : const Border(bottom: BorderSide(color: Warna.garis))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: Warna.latar, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.notifications_none_rounded, size: 20, color: Warna.ink2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(terjemahkanNotifikasi('${n['verb'] ?? '-'}'),
                    style: TextStyle(fontSize: 13, fontWeight: baru ? FontWeight.w800 : FontWeight.w600)),
                const SizedBox(height: 2),
                Text(_waktuLalu(n['timestamp']), style: Teks.kecil),
              ]),
            ),
            if (baru)
              Container(
                margin: const EdgeInsets.only(top: 6, left: 8),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: Warna.oranye, shape: BoxShape.circle),
              ),
          ]),
        ),
      ),
    );
  }
}
