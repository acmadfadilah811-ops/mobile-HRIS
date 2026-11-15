// Pengumuman (2026-11-15): daftar dari /api/base/announcement-view, dibuka -> tandai dibaca.
import 'package:flutter/material.dart';

import '../data/api_mobile.dart';
import '../ui/tema.dart';

class Pengumuman extends StatefulWidget {
  const Pengumuman({super.key});

  @override
  State<Pengumuman> createState() => _PengumumanState();
}

class _PengumumanState extends State<Pengumuman> {
  static const _path = '/api/base/announcement-view?page=1';
  List<Map> _daftar = [];
  bool _memuat = true;
  bool _memuatLagi = false;
  String? _galat;
  int _halaman = 1;
  bool _adaLagi = false;

  @override
  void initState() {
    super.initState();
    _awal();
  }

  Future<void> _awal() async {
    final cache = await ApiMobile.bacaCache(_path);
    if (cache is Map && mounted) setState(() => _daftar = ((cache['results'] as List?) ?? []).cast<Map>());
    await _segarkan();
  }

  Future<void> _segarkan() async {
    try {
      final d = await ApiMobile.segarkan(_path);
      if (!mounted) return;
      setState(() {
        _daftar = ((d['results'] as List?) ?? []).cast<Map>();
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
      final d = await ApiMobile.get('/api/base/announcement-view?page=${_halaman + 1}');
      if (!mounted) return;
      setState(() {
        _daftar.addAll(((d['results'] as List?) ?? []).cast<Map>());
        _halaman++;
        _adaLagi = d['next'] != null;
      });
    } on ApiGagal catch (e) {
      if (mounted) tampilkanPesan(context, e.pesan, gagal: true);
    } finally {
      if (mounted) setState(() => _memuatLagi = false);
    }
  }

  Future<void> _buka(Map a) async {
    if (a['has_viewed'] != true) {
      setState(() => a['has_viewed'] = true);
      ApiMobile.postJson('/api/base/announcements/${a['id']}/mark-viewed/', {}).catchError((_) => null);
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => _IsiPengumuman(data: a)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengumuman')),
      body: RefreshIndicator(
        color: Warna.navy,
        onRefresh: _segarkan,
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) _lagi();
            return false;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (_galat != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_galat!, style: Teks.kecil)),
              if (_memuat && _daftar.isEmpty)
                const Kerangka(tinggi: 220, radius: 16)
              else if (_daftar.isEmpty)
                const Kartu(child: PesanKosong(ikon: Icons.campaign_outlined, judul: 'Belum ada pengumuman'))
              else
                Kartu(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    for (var i = 0; i < _daftar.length; i++) _baris(_daftar[i], i == _daftar.length - 1),
                  ]),
                ),
              if (_memuatLagi)
                const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Warna.muted))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _baris(Map a, bool terakhir) {
    final isi = ((a['content'] as List?) ?? []).map((b) => '${b['text'] ?? ''}').where((t) => t.isNotEmpty).join(' ');
    return InkWell(
      onTap: () => _buka(a),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(border: terakhir ? null : const Border(bottom: BorderSide(color: Warna.garis))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: Warna.latar, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.campaign_outlined, size: 20, color: Warna.ink2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${a['title'] ?? '-'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              if (isi.isNotEmpty) Text(isi, maxLines: 2, overflow: TextOverflow.ellipsis, style: Teks.isi),
              const SizedBox(height: 2),
              Text(tglPendek(a['created_at']), style: Teks.kecil),
            ]),
          ),
          if (a['has_viewed'] != true) ...[const SizedBox(width: 8), const LabelStatus('Baru', titik: Warna.oranye)],
        ]),
      ),
    );
  }
}

class _IsiPengumuman extends StatelessWidget {
  final Map data;

  const _IsiPengumuman({required this.data});

  @override
  Widget build(BuildContext context) {
    final blok = (data['content'] as List?) ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Pengumuman')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        children: [
          Kartu(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${data['title'] ?? '-'}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(tglPendek(data['created_at']), style: Teks.kecil),
              const SizedBox(height: 14),
              if (blok.isEmpty) const Text('Tidak ada isi.', style: Teks.isi),
              for (final b in blok)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    '${b['text'] ?? ''}',
                    style: b['type'] == 'heading'
                        ? const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)
                        : const TextStyle(fontSize: 13.5, height: 1.5, color: Warna.ink2),
                  ),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}
