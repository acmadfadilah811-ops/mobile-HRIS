// Cuti (2026-11-15): saldo per jenis + pengajuan dari /api/mobile/cuti/, hapus dan batal langsung dari daftar.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/api_mobile.dart';
import '../ui/tema.dart';
import 'ajukan_cuti.dart';

class CutiSaya extends StatefulWidget {
  final VoidCallback? saatBerubah;

  const CutiSaya({super.key, this.saatBerubah});

  @override
  State<CutiSaya> createState() => CutiSayaState();
}

class CutiSayaState extends State<CutiSaya> with MuatDenganCache {
  String _filter = 'semua';

  static const _aksenJenis = [Warna.biru, Warna.merah, Warna.kuning, Warna.ungu, Warna.hijau, Warna.indigo];

  @override
  void initState() {
    super.initState();
    muatPath('/api/mobile/cuti/');
  }

  Future<void> segarkan() => segarkanPath();

  Future<void> _ajukan() async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const AjukanCuti()));
    if (ok == true) {
      await segarkan();
      widget.saatBerubah?.call();
    }
  }

  Future<void> _aksi(Map p, {required bool hapus}) async {
    final judul = hapus ? 'Hapus pengajuan?' : 'Batalkan cuti?';
    final isi = hapus
        ? 'Pengajuan ${p['jenis']} ${tglPendek(p['mulai'])} akan dihapus.'
        : 'Cuti ${p['jenis']} ${tglPendek(p['mulai'])} yang sudah disetujui akan dibatalkan dan saldo dikembalikan.';
    final yakin = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(judul, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        content: Text(isi),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Tidak', style: TextStyle(color: Warna.muted))),
          TextButton(onPressed: () => Navigator.pop(c, true),
              child: Text(hapus ? 'Hapus' : 'Batalkan', style: const TextStyle(color: Warna.ink, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (yakin != true) return;
    try {
      if (hapus) {
        await ApiMobile.delete('/api/leave/user-request/${p['id']}/');
      } else {
        await ApiMobile.put('/api/leave/cancel/${p['id']}/');
      }
      if (!mounted) return;
      tampilkanPesan(context, hapus ? 'Pengajuan dihapus.' : 'Cuti dibatalkan.');
      await segarkan();
      widget.saatBerubah?.call();
    } on ApiGagal catch (e) {
      if (mounted) tampilkanPesan(context, e.pesan, gagal: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = (muat.data as Map?) ?? {};
    final ada = muat.data != null;
    final saldo = (d['saldo'] as List?) ?? [];
    final semua = (d['pengajuan'] as List?) ?? [];
    final daftar = _filter == 'semua' ? semua : semua.where((p) => p['status'] == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuti'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(onPressed: _ajukan, icon: const Icon(Icons.add_rounded), tooltip: 'Ajukan cuti'),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        color: Warna.navy,
        onRefresh: segarkan,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _kartuSaldo(d, ada),
            if (saldo.length > 1) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: saldo.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => SizedBox(
                    width: 112,
                    child: Kartu(
                      aksen: _aksenJenis[i % _aksenJenis.length],
                      padding: const EdgeInsets.fromLTRB(11, 10, 11, 8),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${saldo[i]['nama']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Teks.label),
                        const SizedBox(height: 3),
                        Text(angkaHari(saldo[i]['sisa']), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                        Text('dari ${angkaHari(saldo[i]['total'])} hari', style: Teks.kecil),
                      ]),
                    ),
                  ),
                ),
              ),
            ],
            if (muat.galat != null)
              Padding(padding: const EdgeInsets.only(top: 12), child: Text('${muat.galat} Tarik ke bawah untuk mencoba lagi.', style: Teks.kecil)),
            const JudulBagian('Pengajuan saya'),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final f in const [
                  ('semua', 'Semua'), ('requested', 'Menunggu'), ('approved', 'Disetujui'),
                  ('rejected', 'Ditolak'), ('cancelled', 'Dibatalkan'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(f.$2),
                      selected: _filter == f.$1,
                      onSelected: (_) => setState(() => _filter = f.$1),
                      showCheckmark: false,
                      selectedColor: Warna.navy,
                      backgroundColor: Colors.white,
                      side: BorderSide(color: _filter == f.$1 ? Warna.navy : Warna.garis),
                      labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _filter == f.$1 ? Colors.white : Warna.muted),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 10),
            if (!ada)
              const Kerangka(tinggi: 220, radius: 16)
            else if (daftar.isEmpty)
              Kartu(
                child: PesanKosong(
                  ikon: Icons.event_busy_outlined,
                  judul: semua.isEmpty ? 'Belum ada pengajuan cuti' : 'Tidak ada pengajuan dengan status ini',
                  aksi: semua.isEmpty ? 'Ajukan cuti' : null,
                  onAksi: _ajukan,
                ),
              )
            else
              Kartu(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (var i = 0; i < daftar.length; i++) _baris(daftar[i] as Map, i == daftar.length - 1),
                ]),
              ),
            const SizedBox(height: 14),
            TombolUtama('Ajukan Cuti', ikon: Icons.add_rounded, onPressed: _ajukan),
          ],
        ),
      ),
    );
  }

  Widget _kartuSaldo(Map d, bool ada) {
    final saldo = (d['saldo'] as List?) ?? [];
    final utama = saldo.isNotEmpty ? saldo.first as Map : null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Warna.navy, borderRadius: BorderRadius.circular(16)),
      child: !ada
          ? const SizedBox(height: 70)
          : utama == null
              ? const Text('Belum ada jatah cuti. Hubungi HR untuk pengaturan cuti Anda.',
                  style: TextStyle(color: Colors.white, fontSize: 13))
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Sisa ${utama['nama']}', style: TextStyle(color: Colors.white.withOpacity(.75), fontSize: 11.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(angkaHari(utama['sisa']), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, height: 1)),
                    const SizedBox(width: 6),
                    Text('dari ${angkaHari(utama['total'])} hari', style: TextStyle(color: Colors.white.withOpacity(.75), fontSize: 13)),
                    const Spacer(),
                    if (utama['hangus'] != null)
                      Text('Hangus ${tglPendek(utama['hangus'])}', style: TextStyle(color: Colors.white.withOpacity(.7), fontSize: 11)),
                  ]),
                  const SizedBox(height: 10),
                  BarProgres(
                    nilai: ((utama['total'] as num?) ?? 0) > 0 ? (utama['sisa'] as num) / (utama['total'] as num) : 0,
                    warna: Warna.oranye,
                    latar: Colors.white.withOpacity(.16),
                  ),
                ]),
    );
  }

  Widget _baris(Map p, bool terakhir) {
    final rentang = p['selesai'] == null || p['selesai'] == p['mulai']
        ? tglPendek(p['mulai'])
        : '${tglPendek(p['mulai'])} - ${tglPendek(p['selesai'])}';
    final bisaHapus = p['bisa_hapus'] == true;
    final bisaBatal = p['bisa_batal'] == true;
    return InkWell(
      onTap: () => _rincian(p),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        decoration: BoxDecoration(border: terakhir ? null : const Border(bottom: BorderSide(color: Warna.garis))),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: Warna.latar, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.beach_access_outlined, size: 20, color: Warna.ink2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p['jenis']} - ${angkaHari(p['hari'])} hari', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              Text(rentang, style: Teks.kecil),
            ]),
          ),
          LabelStatus.cuti('${p['status']}'),
          if (bisaHapus || bisaBatal)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Warna.muted, size: 20),
              onSelected: (v) => _aksi(p, hapus: v == 'hapus'),
              itemBuilder: (_) => [
                if (bisaHapus) const PopupMenuItem(value: 'hapus', child: Text('Hapus pengajuan')),
                if (bisaBatal) const PopupMenuItem(value: 'batal', child: Text('Batalkan cuti')),
              ],
            )
          else
            const SizedBox(width: 12),
        ]),
      ),
    );
  }

  void _rincian(Map p) {
    String bagian(dynamic v) => switch ('$v') {
          'first_half' => ' (paruh pertama)',
          'second_half' => ' (paruh kedua)',
          _ => '',
        };
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('${p['jenis']}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
              LabelStatus.cuti('${p['status']}'),
            ]),
            const SizedBox(height: 14),
            _info('Mulai', '${tglPendek(p['mulai'])}${bagian(p['mulai_bagian'])}'),
            _info('Sampai', '${tglPendek(p['selesai'] ?? p['mulai'])}${bagian(p['selesai_bagian'])}'),
            _info('Lama', '${angkaHari(p['hari'])} hari'),
            _info('Alasan', '${p['alasan'] ?? '-'}'),
            if (p['alasan_tolak'] != null) _info('Alasan ditolak', '${p['alasan_tolak']}'),
            if (p['lampiran'] != null)
              TextButton.icon(
                onPressed: () => launchUrl(Uri.parse('${p['lampiran']}'), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.attach_file_rounded, size: 18, color: Warna.ink2),
                label: const Text('Lihat lampiran', style: TextStyle(color: Warna.ink2, fontWeight: FontWeight.w700)),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _info(String label, String isi) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 110, child: Text(label, style: Teks.label)),
        Expanded(child: Text(isi, style: Teks.isi)),
      ]),
    );
  }
}
