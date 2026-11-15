// Lembur (2026-11-15): pengajuan lembur milik sendiri + form pengajuan, gaya baru.
// API sama dengan layar lama: GET/POST /api/attendance/overtime-request/, batal lewat /<id>/cancel/.
import 'package:flutter/material.dart';

import '../data/api_mobile.dart';
import '../ui/tema.dart';

const _pathLembur = '/api/attendance/overtime-request/';

LabelStatus _labelLembur(String status) => switch (status) {
      'approved' => const LabelStatus('Disetujui', titik: Warna.ok),
      'rejected' => const LabelStatus('Ditolak', titik: Warna.tolak),
      'cancelled' => const LabelStatus('Dibatalkan', titik: Warna.slate),
      _ => const LabelStatus('Menunggu', titik: Warna.tunggu),
    };

String _jam(dynamic v) => '${v ?? ''}'.length >= 5 ? '$v'.substring(0, 5) : '${v ?? '-'}';

class Lembur extends StatefulWidget {
  const Lembur({super.key});

  @override
  State<Lembur> createState() => _LemburState();
}

class _LemburState extends State<Lembur> with MuatDenganCache {
  String _filter = 'semua';

  @override
  void initState() {
    super.initState();
    muatPath(_pathLembur);
  }

  List get _semua => ((muat.data as Map?)?['results'] as List?) ?? [];

  Future<void> _ajukan() async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const AjukanLembur()));
    if (ok == true) segarkanPath();
  }

  Future<void> _batal(Map p) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Batalkan pengajuan?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        content: Text('Lembur ${tglPendek(p['date'])} ${_jam(p['start_time'])} - ${_jam(p['end_time'])} akan dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Tidak', style: TextStyle(color: Warna.muted))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Batalkan', style: TextStyle(color: Warna.ink, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (yakin != true) return;
    try {
      await ApiMobile.postJson('$_pathLembur${p['id']}/cancel/', {});
      if (mounted) tampilkanPesan(context, 'Pengajuan dibatalkan.');
      segarkanPath();
    } on ApiGagal catch (e) {
      if (mounted) tampilkanPesan(context, e.pesan, gagal: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ada = muat.data != null;
    final kini = DateTime.now();
    final bulanIni = _semua.where((p) {
      final d = tanggalDari(p['date']);
      return d != null && d.year == kini.year && d.month == kini.month;
    }).toList();
    final detikSetuju = bulanIni.where((p) => p['status'] == 'approved').fold<num>(0, (a, p) => a + ((p['requested_second'] as num?) ?? 0));
    final menunggu = _semua.where((p) => p['status'] == 'requested').length;
    final daftar = _filter == 'semua' ? _semua : _semua.where((p) => p['status'] == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lembur'),
        actions: [IconButton(onPressed: _ajukan, icon: const Icon(Icons.add_rounded)), const SizedBox(width: 6)],
      ),
      body: RefreshIndicator(
        color: Warna.navy,
        onRefresh: segarkanPath,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Row(children: [
              Expanded(
                child: Kartu(
                  aksen: Warna.kuning,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Disetujui bulan ini', style: Teks.label),
                    const SizedBox(height: 4),
                    ada ? Text('${angkaHari(detikSetuju / 3600)} jam', style: Teks.angka) : const Kerangka(tinggi: 22, lebar: 60),
                  ]),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Kartu(
                  aksen: Warna.slate,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Menunggu persetujuan', style: Teks.label),
                    const SizedBox(height: 4),
                    ada ? Text('$menunggu', style: Teks.angka) : const Kerangka(tinggi: 22, lebar: 30),
                  ]),
                ),
              ),
            ]),
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
              const Kerangka(tinggi: 200, radius: 16)
            else if (daftar.isEmpty)
              Kartu(
                child: PesanKosong(
                  ikon: Icons.more_time_rounded,
                  judul: _semua.isEmpty ? 'Belum ada pengajuan lembur' : 'Tidak ada pengajuan dengan status ini',
                  aksi: _semua.isEmpty ? 'Ajukan lembur' : null,
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
            TombolUtama('Ajukan Lembur', ikon: Icons.add_rounded, onPressed: _ajukan),
          ],
        ),
      ),
    );
  }

  Widget _baris(Map p, bool terakhir) {
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
            child: const Icon(Icons.more_time_rounded, size: 20, color: Warna.ink2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${tglPendek(p['date'])} - ${p['durasi'] ?? ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              Text('${_jam(p['start_time'])} - ${_jam(p['end_time'])}', style: Teks.kecil),
            ]),
          ),
          _labelLembur('${p['status']}'),
          if (p['bisa_dibatalkan'] == true)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Warna.muted, size: 20),
              onSelected: (_) => _batal(p),
              itemBuilder: (_) => const [PopupMenuItem(value: 'batal', child: Text('Batalkan pengajuan'))],
            )
          else
            const SizedBox(width: 12),
        ]),
      ),
    );
  }

  void _rincian(Map p) {
    Widget info(String l, String v) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 110, child: Text(l, style: Teks.label)),
            Expanded(child: Text(v, style: Teks.isi)),
          ]),
        );
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Text('Lembur', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
              _labelLembur('${p['status']}'),
            ]),
            const SizedBox(height: 14),
            info('Tanggal', tglPendek(p['date'])),
            info('Jam', '${_jam(p['start_time'])} - ${_jam(p['end_time'])} (${p['durasi'] ?? '-'})'),
            info('Pekerjaan', '${p['reason'] ?? '-'}'),
            if ('${p['approver_name'] ?? ''}'.isNotEmpty) info('Diputuskan oleh', '${p['approver_name']}'),
            if ('${p['reject_reason'] ?? ''}'.isNotEmpty) info('Alasan ditolak', '${p['reject_reason']}'),
          ]),
        ),
      ),
    );
  }
}

class AjukanLembur extends StatefulWidget {
  const AjukanLembur({super.key});

  @override
  State<AjukanLembur> createState() => _AjukanLemburState();
}

class _AjukanLemburState extends State<AjukanLembur> {
  DateTime _tanggal = DateTime.now();
  TimeOfDay? _mulai;
  TimeOfDay? _selesai;
  final _alasan = TextEditingController();
  bool _kirim = false;
  String? _galat;

  @override
  void dispose() {
    _alasan.dispose();
    super.dispose();
  }

  String _iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String? get _durasi {
    if (_mulai == null || _selesai == null) return null;
    var menit = (_selesai!.hour * 60 + _selesai!.minute) - (_mulai!.hour * 60 + _mulai!.minute);
    if (menit <= 0) menit += 24 * 60; // lewat tengah malam
    return '${menit ~/ 60} jam ${menit % 60} menit';
  }

  Future<void> _pilihJam(bool mulai) async {
    final hasil = await showTimePicker(
      context: context,
      initialTime: (mulai ? _mulai : _selesai) ?? (mulai ? const TimeOfDay(hour: 17, minute: 0) : const TimeOfDay(hour: 19, minute: 0)),
      builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (hasil != null) setState(() => mulai ? _mulai = hasil : _selesai = hasil);
  }

  Future<void> _kirimPengajuan() async {
    if (_mulai == null || _selesai == null || _alasan.text.trim().isEmpty) {
      setState(() => _galat = 'Lengkapi jam mulai, jam selesai, dan pekerjaan yang dikerjakan.');
      return;
    }
    setState(() {
      _kirim = true;
      _galat = null;
    });
    try {
      await ApiMobile.postJson(_pathLembur, {
        'date': _iso(_tanggal),
        'start_time': _hhmm(_mulai!),
        'end_time': _hhmm(_selesai!),
        'reason': _alasan.text.trim(),
      });
      if (!mounted) return;
      tampilkanPesan(context, 'Pengajuan lembur terkirim ke atasan.');
      Navigator.pop(context, true);
    } on ApiGagal catch (e) {
      setState(() => _galat = e.pesan);
    } finally {
      if (mounted) setState(() => _kirim = false);
    }
  }

  Widget _kotak(String label, String nilai, IconData ikon, VoidCallback onTap, {bool kosong = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Warna.ink2))),
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Warna.garis)),
          child: Row(children: [
            Icon(ikon, size: 18, color: Warna.muted),
            const SizedBox(width: 8),
            Text(nilai, style: TextStyle(fontSize: 13.5, color: kosong ? Warna.faint : Warna.ink)),
          ]),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajukan Lembur')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
        children: [
          _kotak('Tanggal', tglPendek(_iso(_tanggal)), Icons.calendar_today_outlined, () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _tanggal,
              firstDate: DateTime.now().subtract(const Duration(days: 60)),
              lastDate: DateTime.now().add(const Duration(days: 60)),
            );
            if (d != null) setState(() => _tanggal = d);
          }),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _kotak('Mulai', _mulai == null ? 'Pilih' : _hhmm(_mulai!), Icons.schedule_rounded, () => _pilihJam(true), kosong: _mulai == null)),
            const SizedBox(width: 10),
            Expanded(child: _kotak('Selesai', _selesai == null ? 'Pilih' : _hhmm(_selesai!), Icons.schedule_rounded, () => _pilihJam(false), kosong: _selesai == null)),
          ]),
          if (_durasi != null) ...[
            const SizedBox(height: 10),
            Text('Durasi $_durasi', style: Teks.kecil),
          ],
          const SizedBox(height: 14),
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text('Pekerjaan yang dikerjakan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Warna.ink2)),
          ),
          TextField(
            controller: _alasan,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Contoh: cetak banner pesanan mendadak',
              hintStyle: const TextStyle(color: Warna.faint, fontSize: 13.5),
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Warna.garis)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Warna.navy)),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFEEF0F4), borderRadius: BorderRadius.circular(12)),
            child: const Text('Lembur dibayar sesuai jam yang disetujui atasan.',
                style: TextStyle(fontSize: 11.5, color: Warna.ink2, fontWeight: FontWeight.w600)),
          ),
          if (_galat != null) ...[
            const SizedBox(height: 12),
            Text(_galat!, style: const TextStyle(fontSize: 12.5, color: Warna.tolak, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(18, 12, 18, 12 + MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Warna.garis))),
        child: TombolUtama('Kirim Pengajuan', ikon: Icons.send_rounded, proses: _kirim, onPressed: _kirimPengajuan),
      ),
    );
  }
}
