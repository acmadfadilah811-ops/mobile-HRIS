// Tim Saya (2026-11-15): bawahan (atau semua karyawan untuk HR) dengan status absen hari ini, dari /api/mobile/tim/.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/api_mobile.dart';
import '../ui/tema.dart';

class TimSaya extends StatefulWidget {
  const TimSaya({super.key});

  @override
  State<TimSaya> createState() => _TimSayaState();
}

class _TimSayaState extends State<TimSaya> with MuatDenganCache {
  String _filter = 'semua';
  String _cari = '';

  @override
  void initState() {
    super.initState();
    muatPath('/api/mobile/tim/');
  }

  static LabelStatus _label(Map a) => switch (a['status']) {
        'masuk' => LabelStatus(a['terlambat'] == true ? 'Masuk, terlambat' : 'Sedang masuk', titik: a['terlambat'] == true ? Warna.tunggu : Warna.ok),
        'pulang' => const LabelStatus('Sudah pulang', titik: Warna.slate),
        'cuti' => const LabelStatus('Cuti', titik: Warna.info),
        _ => const LabelStatus('Belum absen', titik: Warna.tolak),
      };

  @override
  Widget build(BuildContext context) {
    final d = (muat.data as Map?) ?? {};
    final ada = muat.data != null;
    final r = (d['ringkasan'] as Map?) ?? {};
    final semua = ((d['anggota'] as List?) ?? []).cast<Map>();
    final daftar = semua.where((a) {
      if (_filter != 'semua' && a['status'] != _filter) return false;
      return _cari.isEmpty || '${a['nama']}'.toLowerCase().contains(_cari) || '${a['jabatan'] ?? ''}'.toLowerCase().contains(_cari);
    }).toList();

    Widget mini(String label, dynamic n, Color aksen, String kunci) => Expanded(
          child: Kartu(
            aksen: aksen,
            onTap: () => setState(() => _filter = _filter == kunci ? 'semua' : kunci),
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
            child: Column(children: [
              Text('${n ?? 0}', style: Teks.angka),
              Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, fontWeight: _filter == kunci ? FontWeight.w800 : FontWeight.w600, color: _filter == kunci ? Warna.ink : Warna.muted)),
            ]),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(d['cakupan'] == 'semua' ? 'Absensi Karyawan' : 'Tim Saya')),
      body: RefreshIndicator(
        color: Warna.navy,
        onRefresh: segarkanPath,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Text('Hari ini, ${tglPanjang(DateTime.now())}', style: Teks.label),
            const SizedBox(height: 10),
            if (!ada)
              const Kerangka(tinggi: 80, radius: 16)
            else
              Row(children: [
                mini('Masuk', r['masuk'], Warna.hijau, 'masuk'),
                const SizedBox(width: 8),
                mini('Pulang', r['pulang'], Warna.slate, 'pulang'),
                const SizedBox(width: 8),
                mini('Cuti', r['cuti'], Warna.biru, 'cuti'),
                const SizedBox(width: 8),
                mini('Belum', r['belum'], Warna.merah, 'belum'),
              ]),
            const SizedBox(height: 12),
            TextField(
              onChanged: (v) => setState(() => _cari = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Cari nama atau jabatan',
                hintStyle: const TextStyle(color: Warna.faint, fontSize: 13.5),
                prefixIcon: const Icon(Icons.search_rounded, color: Warna.muted),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Warna.garis)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Warna.navy)),
              ),
            ),
            if (muat.galat != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text('${muat.galat}', style: Teks.kecil)),
            const SizedBox(height: 12),
            if (!ada)
              const Kerangka(tinggi: 260, radius: 16)
            else if (daftar.isEmpty)
              Kartu(child: PesanKosong(ikon: Icons.groups_outlined, judul: semua.isEmpty ? 'Belum ada anggota tim' : 'Tidak ada yang cocok'))
            else
              Kartu(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (var i = 0; i < daftar.length; i++) _baris(daftar[i], i == daftar.length - 1),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _baris(Map a, bool terakhir) {
    final jam = [
      if (a['jam_masuk'] != null) 'masuk ${a['jam_masuk']}',
      if (a['jam_pulang'] != null) 'pulang ${a['jam_pulang']}',
    ].join(', ');
    return InkWell(
      onTap: '${a['phone'] ?? ''}'.isEmpty ? null : () => _hubungi(a),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(border: terakhir ? null : const Border(bottom: BorderSide(color: Warna.garis))),
        child: Row(children: [
          AvatarInisial(inisial: '${a['inisial'] ?? ''}', foto: a['foto'], ukuran: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${a['nama']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              Text([a['jabatan'], jam].where((e) => e != null && '$e'.isNotEmpty).join(' - '),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: Teks.kecil),
            ]),
          ),
          const SizedBox(width: 8),
          _label(a),
        ]),
      ),
    );
  }

  void _hubungi(Map a) {
    final nomor = '${a['phone']}'.replaceAll(RegExp(r'[^0-9+]'), '');
    final wa = nomor.startsWith('0') ? '62${nomor.substring(1)}' : nomor.replaceAll('+', '');
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: Text('${a['nama']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          ListTile(
            leading: const Icon(Icons.call_outlined, color: Warna.ink2),
            title: Text('Telepon $nomor'),
            onTap: () => launchUrl(Uri.parse('tel:$nomor')),
          ),
          ListTile(
            leading: const Icon(Icons.chat_outlined, color: Warna.ink2),
            title: const Text('Kirim WhatsApp'),
            onTap: () => launchUrl(Uri.parse('https://wa.me/$wa'), mode: LaunchMode.externalApplication),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}
