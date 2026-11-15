// Absensi Saya (2026-11-15): ringkasan + riwayat per bulan dari /api/mobile/absensi/?bulan=YYYY-MM.
import 'package:flutter/material.dart';

import '../data/api_mobile.dart';
import '../ui/tema.dart';

class AbsensiSaya extends StatefulWidget {
  const AbsensiSaya({super.key});

  @override
  State<AbsensiSaya> createState() => AbsensiSayaState();
}

class AbsensiSayaState extends State<AbsensiSaya> with MuatDenganCache {
  DateTime _bulan = DateTime(DateTime.now().year, DateTime.now().month);

  String get _path => '/api/mobile/absensi/?bulan=${_bulan.year}-${_bulan.month.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    muatPath(_path);
  }

  Future<void> segarkan() => segarkanPath();

  void _geser(int n) {
    final baru = DateTime(_bulan.year, _bulan.month + n);
    final kini = DateTime(DateTime.now().year, DateTime.now().month);
    if (baru.isAfter(kini)) return;
    setState(() => _bulan = baru);
    muatPath(_path);
  }

  @override
  Widget build(BuildContext context) {
    final d = (muat.data as Map?) ?? {};
    final ringkasan = (d['ringkasan'] as Map?) ?? {};
    final hari = (d['hari'] as List?) ?? [];
    final ada = muat.data != null;
    final bulanIni = _bulan.year == DateTime.now().year && _bulan.month == DateTime.now().month;

    return Scaffold(
      appBar: AppBar(title: const Text('Absensi Saya'), automaticallyImplyLeading: false),
      body: RefreshIndicator(
        color: Warna.navy,
        onRefresh: segarkan,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Kartu(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(children: [
                IconButton(onPressed: () => _geser(-1), icon: const Icon(Icons.chevron_left_rounded, color: Warna.muted)),
                Expanded(
                  child: Text(namaBulan(_bulan.month, _bulan.year), textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                ),
                IconButton(
                  onPressed: bulanIni ? null : () => _geser(1),
                  icon: Icon(Icons.chevron_right_rounded, color: bulanIni ? Warna.garis : Warna.muted),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              _mini('Hadir', ringkasan['hadir'], Warna.hijau, ada),
              const SizedBox(width: 8),
              _mini('Terlambat', ringkasan['terlambat'], Warna.kuning, ada),
              const SizedBox(width: 8),
              _mini('Pulang cepat', ringkasan['pulang_cepat'], Warna.merah, ada),
              const SizedBox(width: 8),
              _mini('Cuti', ringkasan['cuti'], Warna.biru, ada),
            ]),
            if (muat.galat != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('${muat.galat} Tarik ke bawah untuk mencoba lagi.', style: Teks.kecil),
              ),
            const JudulBagian('Riwayat'),
            if (!ada)
              const Kerangka(tinggi: 260, radius: 16)
            else if (hari.isEmpty)
              const Kartu(child: PesanKosong(ikon: Icons.event_note_outlined, judul: 'Belum ada absensi di bulan ini'))
            else
              Kartu(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (var i = 0; i < hari.length; i++) _baris(hari[i] as Map, i == hari.length - 1),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _mini(String label, dynamic nilai, Color aksen, bool ada) {
    return Expanded(
      child: Kartu(
        aksen: aksen,
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
        child: Column(children: [
          ada ? Text('${nilai ?? 0}', style: Teks.angka) : const Kerangka(tinggi: 22, lebar: 26),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: Teks.label),
        ]),
      ),
    );
  }

  Widget _baris(Map h, bool terakhir) {
    final tgl = tanggalDari(h['tanggal']) ?? DateTime.now();
    late final String atas;
    late final String bawah;
    late final LabelStatus label;
    if (h['jenis'] == 'cuti') {
      atas = 'Cuti';
      bawah = '${h['keterangan'] ?? ''}';
      label = const LabelStatus('Cuti', titik: Warna.info);
    } else {
      final masuk = h['jam_masuk'] ?? '--:--';
      final pulang = h['jam_pulang'];
      atas = pulang == null ? '$masuk - belum pulang' : '$masuk - $pulang';
      final bagian = <String>[
        if (h['shift'] != null) '${h['shift']}',
        if (h['jam_kerja'] != null && h['jam_kerja'] != '00:00') 'kerja ${h['jam_kerja']}',
        if (h['lembur'] != null) 'lembur ${h['lembur']}',
      ];
      bawah = bagian.join(' - ');
      if (h['terlambat'] == true) {
        label = const LabelStatus('Terlambat', titik: Warna.tunggu);
      } else if (h['pulang_cepat'] == true) {
        label = const LabelStatus('Pulang cepat', titik: Warna.tolak);
      } else {
        label = const LabelStatus('Hadir', titik: Warna.ok);
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(border: terakhir ? null : const Border(bottom: BorderSide(color: Warna.garis))),
      child: Row(children: [
        SizedBox(
          width: 42,
          child: Column(children: [
            Text('${tgl.day}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, height: 1.1)),
            Text(hariSingkat(tgl).toUpperCase(),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Warna.muted)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(atas, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            if (bawah.isNotEmpty) Text(bawah, style: Teks.kecil, maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
        const SizedBox(width: 8),
        label,
      ]),
    );
  }
}
