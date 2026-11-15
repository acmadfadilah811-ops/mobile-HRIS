// Persetujuan atasan/HR (2026-11-15): antrean cuti, lembur, koreksi absensi dari /api/mobile/persetujuan/.
// Setujui/tolak memakai endpoint yang sudah ada sehingga aturannya sama dengan web HR.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/api_mobile.dart';
import '../ui/tema.dart';

class Persetujuan extends StatefulWidget {
  final int tabAwal;

  const Persetujuan({super.key, this.tabAwal = 0});

  @override
  State<Persetujuan> createState() => _PersetujuanState();
}

class _PersetujuanState extends State<Persetujuan> with MuatDenganCache, SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this, initialIndex: widget.tabAwal);
  final Set<String> _proses = {};
  bool _berubah = false;

  @override
  void initState() {
    super.initState();
    muatPath('/api/mobile/persetujuan/');
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  List _daftar(String jenis) => ((muat.data as Map?)?[jenis] as List?) ?? [];

  Future<String?> _mintaAlasan(String judul, {bool wajib = false}) {
    final isian = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(judul, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: isian,
          maxLines: 3,
          autofocus: true,
          decoration: InputDecoration(hintText: wajib ? 'Alasan penolakan (wajib)' : 'Catatan (opsional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Batal', style: TextStyle(color: Warna.muted))),
          TextButton(
            onPressed: () {
              if (wajib && isian.text.trim().isEmpty) return;
              Navigator.pop(c, isian.text.trim());
            },
            child: const Text('Tolak', style: TextStyle(color: Warna.ink, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<bool> _yakin(String judul, String isi, String tombol) async {
    return await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(judul, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            content: Text(isi),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal', style: TextStyle(color: Warna.muted))),
              TextButton(onPressed: () => Navigator.pop(c, true),
                  child: Text(tombol, style: const TextStyle(color: Warna.ink, fontWeight: FontWeight.w700))),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _putuskan(String jenis, Map item, bool setuju) async {
    final nama = (item['karyawan'] as Map?)?['nama'] ?? '';
    String? alasan;
    if (!setuju) {
      if (jenis == 'lembur') {
        alasan = await _mintaAlasan('Tolak lembur $nama?', wajib: true);
        if (alasan == null) return;
      } else if (!await _yakin('Tolak pengajuan?', 'Pengajuan $jenis $nama akan ditolak.', 'Tolak')) {
        return;
      }
    }
    final kunci = '$jenis-${item['id']}';
    setState(() => _proses.add(kunci));
    try {
      final id = item['id'];
      switch (jenis) {
        case 'cuti':
          await ApiMobile.put(setuju ? '/api/leave/approve/$id/' : '/api/leave/reject/$id/', {});
        case 'lembur':
          await ApiMobile.postJson('/api/attendance/overtime-request/$id/${setuju ? 'approve' : 'reject'}/',
              {'reason': alasan ?? ''});
        case 'koreksi':
          await ApiMobile.put(setuju ? '/api/attendance/attendance-request-approve/$id' : '/api/attendance/attendance-request-cancel/$id');
      }
      _berubah = true;
      if (mounted) tampilkanPesan(context, setuju ? 'Disetujui.' : 'Ditolak.');
      await segarkanPath();
    } on ApiGagal catch (e) {
      if (mounted) tampilkanPesan(context, e.pesan, gagal: true);
    } finally {
      if (mounted) setState(() => _proses.remove(kunci));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ada = muat.data != null;
    final boleh = (muat.data as Map?)?['boleh'] != false;
    Tab tab(String label, String jenis) {
      final n = _daftar(jenis).length;
      return Tab(text: n > 0 ? '$label ($n)' : label);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (sudah, _) {
        if (!sudah) Navigator.pop(context, _berubah);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Persetujuan'),
          bottom: TabBar(
            controller: _tab,
            labelColor: Warna.ink,
            unselectedLabelColor: Warna.muted,
            indicatorColor: Warna.navy,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: [tab('Cuti', 'cuti'), tab('Lembur', 'lembur'), tab('Koreksi absen', 'koreksi')],
          ),
        ),
        body: !ada
            ? const Padding(padding: EdgeInsets.all(18), child: Kerangka(tinggi: 200, radius: 16))
            : !boleh
                ? const PesanKosong(ikon: Icons.lock_outline_rounded, judul: 'Menu ini untuk atasan dan HR')
                : TabBarView(controller: _tab, children: [
                    _isiTab('cuti'),
                    _isiTab('lembur'),
                    _isiTab('koreksi'),
                  ]),
      ),
    );
  }

  Widget _isiTab(String jenis) {
    final daftar = _daftar(jenis);
    return RefreshIndicator(
      color: Warna.navy,
      onRefresh: segarkanPath,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (muat.galat != null)
            Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('${muat.galat}', style: Teks.kecil)),
          if (daftar.isEmpty)
            const Kartu(child: PesanKosong(ikon: Icons.task_alt_rounded, judul: 'Tidak ada yang menunggu', isi: 'Semua pengajuan sudah diputuskan.'))
          else
            for (final item in daftar) ...[_kartu(jenis, item as Map), const SizedBox(height: 10)],
        ],
      ),
    );
  }

  Widget _kartu(String jenis, Map item) {
    final k = (item['karyawan'] as Map?) ?? {};
    final proses = _proses.contains('$jenis-${item['id']}');
    late final String judul;
    late final List<String> detail;
    switch (jenis) {
      case 'cuti':
        final rentang = item['selesai'] == null || item['selesai'] == item['mulai']
            ? tglPendek(item['mulai'])
            : '${tglPendek(item['mulai'])} - ${tglPendek(item['selesai'])}';
        judul = '${item['jenis']} - ${angkaHari(item['hari'])} hari';
        detail = [rentang, if (item['sisa_cuti'] != null) 'Sisa cuti ${angkaHari(item['sisa_cuti'])} hari'];
      case 'lembur':
        judul = 'Lembur ${angkaHari(item['jam'])} jam';
        detail = ['${tglPendek(item['tanggal'])}, ${item['mulai']} - ${item['selesai']}'];
      default:
        judul = 'Koreksi absen ${tglPendek(item['tanggal'])}';
        String rentang(dynamic a, dynamic b) => '${a ?? '--:--'} - ${b ?? '--:--'}';
        detail = [
          'Tercatat ${rentang(item['jam_masuk_lama'], item['jam_pulang_lama'])}',
          'Diminta ${rentang(item['jam_masuk_baru'], item['jam_pulang_baru'])}',
        ];
    }
    return Kartu(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          AvatarInisial(inisial: '${k['inisial'] ?? ''}', foto: k['foto'], ukuran: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${k['nama'] ?? '-'}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              if (k['jabatan'] != null) Text('${k['jabatan']}', style: Teks.kecil),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Text(judul, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        for (final d in detail) Text(d, style: Teks.isi),
        if ((item['alasan'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Warna.latar, borderRadius: BorderRadius.circular(10)),
            child: Text('${item['alasan']}', style: Teks.isi),
          ),
        ],
        if (item['lampiran'] != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => launchUrl(Uri.parse('${item['lampiran']}'), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.attach_file_rounded, size: 18, color: Warna.ink2),
              label: const Text('Lihat lampiran', style: TextStyle(color: Warna.ink2, fontWeight: FontWeight.w700)),
            ),
          ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TombolUtama('Tolak', garis: true, onPressed: proses ? null : () => _putuskan(jenis, item, false))),
          const SizedBox(width: 10),
          Expanded(child: TombolUtama('Setujui', ikon: Icons.check_rounded, proses: proses, onPressed: () => _putuskan(jenis, item, true))),
        ]),
      ]),
    );
  }
}
