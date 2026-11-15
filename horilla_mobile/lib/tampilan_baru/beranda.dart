// Beranda baru (2026-11-15): satu permintaan ke /api/mobile/beranda/, tampil dari data di HP dulu.
import 'package:flutter/material.dart';

import '../data/api_mobile.dart';
import '../ui/tema.dart';
import 'ajukan_cuti.dart';
import 'halaman_utama.dart';
import 'persetujuan.dart';

class Beranda extends StatefulWidget {
  final HalamanUtamaState induk;

  const Beranda({super.key, required this.induk});

  @override
  State<Beranda> createState() => BerandaState();
}

class BerandaState extends State<Beranda> with MuatDenganCache {
  @override
  void initState() {
    super.initState();
    muatPath('/api/mobile/beranda/');
  }

  Future<void> segarkan() => segarkanPath();

  Map<String, dynamic> get _d => (muat.data as Map?)?.cast<String, dynamic>() ?? {};

  String _sapaan() {
    final jam = DateTime.now().hour;
    if (jam < 11) return 'Selamat pagi,';
    if (jam < 15) return 'Selamat siang,';
    if (jam < 18) return 'Selamat sore,';
    return 'Selamat malam,';
  }

  @override
  Widget build(BuildContext context) {
    final ada = muat.data != null;
    final profil = (_d['profil'] as Map?) ?? {};
    return RefreshIndicator(
      color: Warna.navy,
      onRefresh: segarkan,
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _kepala(profil, ada),
          Transform.translate(
            offset: const Offset(0, -58),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _kartuAbsen(ada),
                if (muat.galat != null) _pitaGalat(),
                _kartuPersetujuan(),
                JudulBagian('Ringkasan bulan ini', aksi: 'Riwayat absensi', onAksi: () => widget.induk.pindahTab(1)),
                _ringkasan(ada),
                const JudulBagian('Pengajuan'),
                _menuCepat(),
                JudulBagian('Pengumuman', aksi: 'Lihat semua', onAksi: () => Navigator.pushNamed(context, '/announcements')),
                _pengumuman(ada),
                const SizedBox(height: 10),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kepala(Map profil, bool ada) {
    final notif = (_d['notif_belum_dibaca'] as num?)?.toInt() ?? 0;
    return Container(
      color: Warna.navy,
      padding: EdgeInsets.fromLTRB(18, MediaQuery.of(context).padding.top + 10, 18, 82),
      child: Row(children: [
        AvatarInisial(inisial: profil['inisial'] ?? '', foto: profil['foto'], gelap: true),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_sapaan(), style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(.7))),
            const SizedBox(height: 2),
            ada
                ? Text(profil['nama'] ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Colors.white))
                : const Kerangka(tinggi: 16, lebar: 150),
          ]),
        ),
        _tombolKepala(Icons.notifications_none_rounded, titik: notif > 0, onTap: () async {
          await Navigator.pushNamed(context, '/notifications_list');
          segarkan();
        }),
      ]),
    );
  }

  Widget _tombolKepala(IconData ikon, {bool titik = false, required VoidCallback onTap}) {
    return Material(
      color: Colors.white.withOpacity(.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Stack(alignment: Alignment.center, children: [
            Icon(ikon, color: Colors.white, size: 23),
            if (titik)
              Positioned(
                top: 10,
                right: 11,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: Warna.oranye, shape: BoxShape.circle, border: Border.all(color: Warna.navy, width: 1.5)),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _kartuAbsen(bool ada) {
    final h = (_d['hari_ini'] as Map?) ?? {};
    if (!ada) {
      return const Kartu(
        aksen: Warna.indigo,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Kerangka(tinggi: 16, lebar: 180),
          SizedBox(height: 14),
          Row(children: [Expanded(child: Kerangka(tinggi: 58)), SizedBox(width: 10), Expanded(child: Kerangka(tinggi: 58))]),
          SizedBox(height: 14),
          Kerangka(tinggi: 50),
        ]),
      );
    }
    final status = h['status'] ?? 'belum';
    final terlambat = (h['terlambat_menit'] as num?)?.toInt();
    final shift = h['shift'] == null
        ? 'Belum ada shift'
        : '${h['shift']}${h['jam_mulai'] != null ? ' ${h['jam_mulai']} - ${h['jam_selesai'] ?? ''}' : ''}';
    Widget? label;
    if (h['jam_masuk'] != null && terlambat != null) {
      label = terlambat > 0
          ? LabelStatus('Terlambat $terlambat menit', titik: Warna.tunggu)
          : const LabelStatus('Tepat waktu', titik: Warna.ok);
    }
    final tombol = switch (status) {
      'masuk' => ('Absen Pulang', Icons.logout_rounded),
      'pulang' => ('Lihat Absensi Hari Ini', Icons.event_available_rounded),
      _ => ('Absen Masuk', Icons.login_rounded),
    };
    return Kartu(
      aksen: Warna.indigo,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tglPanjang(DateTime.now()), style: Teks.label),
              const SizedBox(height: 2),
              Text(shift, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ]),
          ),
          if (label != null) label,
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _jam('Masuk', h['jam_masuk'])),
          const SizedBox(width: 10),
          Expanded(child: _jam('Pulang', h['jam_pulang'])),
        ]),
        const SizedBox(height: 14),
        TombolUtama(tombol.$1, ikon: tombol.$2, onPressed: () {
          if (status == 'pulang') {
            widget.induk.pindahTab(1);
          } else {
            widget.induk.bukaAbsen();
          }
        }),
      ]),
    );
  }

  /// Hanya untuk atasan/HR (server mengirim null untuk karyawan biasa).
  Widget _kartuPersetujuan() {
    final p = _d['persetujuan'] as Map?;
    if (p == null) return const SizedBox.shrink();
    final total = (p['total'] as num?)?.toInt() ?? 0;
    Widget angka(String label, dynamic n, int tab) => Expanded(
          child: InkWell(
            onTap: () => _bukaPersetujuan(tab),
            child: Column(children: [
              Text('${n ?? 0}', style: Teks.angka),
              Text(label, style: Teks.label),
            ]),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      JudulBagian('Menunggu persetujuan', aksi: total > 0 ? 'Buka' : null, onAksi: () => _bukaPersetujuan(0)),
      Kartu(
        aksen: Warna.oranye,
        onTap: () => _bukaPersetujuan(0),
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: total == 0
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Text('Tidak ada pengajuan bawahan yang menunggu.', style: Teks.isi),
              )
            : Row(children: [
                angka('Cuti', p['cuti'], 0),
                Container(width: 1, height: 34, color: Warna.garis),
                angka('Lembur', p['lembur'], 1),
                Container(width: 1, height: 34, color: Warna.garis),
                angka('Koreksi absen', p['koreksi'], 2),
              ]),
      ),
    ]);
  }

  Future<void> _bukaPersetujuan(int tab) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => Persetujuan(tabAwal: tab)));
    segarkan();
  }

  Widget _jam(String label, dynamic jam) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: Warna.latar, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Teks.label),
        const SizedBox(height: 2),
        Text(jam ?? '--:--',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: jam == null ? Warna.faint : Warna.ink)),
      ]),
    );
  }

  Widget _pitaGalat() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(color: const Color(0xFFEEF0F4), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.cloud_off_rounded, size: 18, color: Warna.ink2),
          const SizedBox(width: 8),
          Expanded(child: Text(muat.galat!, style: Teks.isi)),
          GestureDetector(onTap: segarkan, child: const Text('Coba lagi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
        ]),
      ),
    );
  }

  Widget _kartuAngka({
    required String label,
    required IconData ikon,
    required Color aksen,
    required Widget isi,
    VoidCallback? onTap,
  }) {
    return Kartu(
      aksen: aksen,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: Teks.label)),
          Icon(ikon, size: 19, color: Warna.muted),
        ]),
        const SizedBox(height: 6),
        isi,
      ]),
    );
  }

  Widget _ringkasan(bool ada) {
    if (!ada) {
      return const Column(children: [
        Row(children: [Expanded(child: Kerangka(tinggi: 92, radius: 16)), SizedBox(width: 10), Expanded(child: Kerangka(tinggi: 92, radius: 16))]),
        SizedBox(height: 10),
        Row(children: [Expanded(child: Kerangka(tinggi: 92, radius: 16)), SizedBox(width: 10), Expanded(child: Kerangka(tinggi: 92, radius: 16))]),
      ]);
    }
    final cuti = (_d['cuti'] as Map?) ?? {};
    final bulan = (_d['bulan_ini'] as Map?) ?? {};
    final kpi = (_d['kpi'] as Map?) ?? {};
    final lembur = (_d['lembur'] as Map?) ?? {};
    final sisa = (cuti['sisa'] as num?) ?? 0;
    final total = (cuti['total'] as num?) ?? 0;
    final terlambat = (bulan['terlambat'] as num?)?.toInt() ?? 0;
    final menunggu = (lembur['menunggu'] as num?)?.toInt() ?? 0;

    Widget besar(String angka, String satuan) => Text.rich(TextSpan(children: [
          TextSpan(text: angka, style: Teks.angka),
          TextSpan(text: ' $satuan', style: Teks.kecil),
        ]));

    final kartuKpi = kpi['ada_template'] == true
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            besar(angkaHari(kpi['total']), ''),
            const SizedBox(height: 4),
            LabelStatus(
              '${kpi['grade'] ?? '-'}${kpi['peringkat'] != null ? ' - peringkat ${kpi['peringkat']}' : ''}',
              titik: _warnaHex(kpi['warna_grade']),
            ),
          ])
        : const Text('Belum ada KPI untuk jabatan ini', style: Teks.kecil);

    return Column(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: _kartuAngka(
            label: 'Sisa cuti',
            ikon: Icons.beach_access_outlined,
            aksen: Warna.biru,
            onTap: () => widget.induk.pindahTab(2),
            isi: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              besar(angkaHari(sisa), 'hari'),
              const SizedBox(height: 8),
              BarProgres(nilai: total > 0 ? sisa / total : 0, warna: Warna.biru),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _kartuAngka(
            label: 'Kehadiran',
            ikon: Icons.event_available_outlined,
            aksen: Warna.hijau,
            onTap: () => widget.induk.pindahTab(1),
            isi: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              besar('${bulan['hadir'] ?? 0}', 'hari'),
              const SizedBox(height: 4),
              Text(terlambat > 0 ? '$terlambat kali terlambat' : 'Tidak pernah terlambat', style: Teks.kecil),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 10),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _kartuAngka(label: 'Skor KPI', ikon: Icons.insights_outlined, aksen: Warna.ungu, isi: kartuKpi)),
        const SizedBox(width: 10),
        Expanded(
          child: _kartuAngka(
            label: 'Lembur',
            ikon: Icons.more_time_outlined,
            aksen: Warna.kuning,
            onTap: () async {
              await Navigator.pushNamed(context, '/overtime_request');
              segarkan();
            },
            isi: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              besar(angkaHari(lembur['jam_disetujui'] ?? 0), 'jam'),
              const SizedBox(height: 4),
              Text(menunggu > 0 ? '$menunggu menunggu persetujuan' : 'Disetujui bulan ini', style: Teks.kecil),
            ]),
          ),
        ),
      ]),
    ]);
  }

  Color _warnaHex(dynamic hex) {
    final t = '${hex ?? ''}'.replaceAll('#', '');
    if (t.length != 6) return Warna.slate;
    return Color(int.parse('FF$t', radix: 16));
  }

  Widget _menuCepat() {
    Widget item(IconData ikon, String label, VoidCallback onTap) {
      return InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: Warna.navySoft, borderRadius: BorderRadius.circular(14)),
              child: Icon(ikon, color: Warna.ink2, size: 22),
            ),
            const SizedBox(height: 7),
            Text(label, textAlign: TextAlign.center, maxLines: 2,
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Warna.ink2)),
          ]),
        ),
      );
    }

    final menu = [
      item(Icons.event_busy_outlined, 'Ajukan Cuti', () async {
        final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const AjukanCuti()));
        if (ok == true) {
          segarkan();
          widget.induk.segarkanCuti();
        }
      }),
      item(Icons.more_time_outlined, 'Lembur', () => Navigator.pushNamed(context, '/overtime_request')),
      item(Icons.description_outlined, 'Dokumen Saya', () => Navigator.pushNamed(context, '/my_documents')),
      item(Icons.folder_open_outlined, 'Dokumen Perusahaan', () => Navigator.pushNamed(context, '/company_documents')),
      item(Icons.campaign_outlined, 'Pengumuman', () => Navigator.pushNamed(context, '/announcements')),
      item(Icons.notifications_none_rounded, 'Notifikasi', () => Navigator.pushNamed(context, '/notifications_list')),
      item(Icons.history_rounded, 'Riwayat Absen', () => widget.induk.pindahTab(1)),
      item(Icons.apps_rounded, 'Modul Lain', () => Navigator.pushNamed(context, '/modul')),
    ];
    return Kartu(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: .78,
        children: menu,
      ),
    );
  }

  Widget _pengumuman(bool ada) {
    if (!ada) return const Kerangka(tinggi: 120, radius: 16);
    final daftar = (_d['pengumuman'] as List?) ?? [];
    if (daftar.isEmpty) {
      return const Kartu(child: PesanKosong(ikon: Icons.campaign_outlined, judul: 'Belum ada pengumuman'));
    }
    return Kartu(
      padding: EdgeInsets.zero,
      child: Column(children: [
        for (var i = 0; i < daftar.length; i++)
          InkWell(
            onTap: () async {
              await Navigator.pushNamed(context, '/announcements');
              segarkan();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                border: i == daftar.length - 1 ? null : const Border(bottom: BorderSide(color: Warna.garis)),
              ),
              child: Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: Warna.latar, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.campaign_outlined, size: 20, color: Warna.ink2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(daftar[i]['judul'] ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    Text(tglPendek(daftar[i]['tanggal']), style: Teks.kecil),
                  ]),
                ),
                if (daftar[i]['sudah_dibaca'] != true) const LabelStatus('Baru', titik: Warna.oranye),
              ]),
            ),
          ),
      ]),
    );
  }
}
