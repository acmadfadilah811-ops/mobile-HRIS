// Data diri & pekerjaan (2026-11-15): /api/mobile/profil/; kontak & alamat bisa diubah sendiri lewat
// PUT /api/employee/employees/<id>/ (izin yang sama dengan layar lama). Data pekerjaan & rekening dari HR.
import 'package:flutter/material.dart';

import '../data/api_mobile.dart';
import '../ui/tema.dart';

class DataDiri extends StatefulWidget {
  const DataDiri({super.key});

  @override
  State<DataDiri> createState() => _DataDiriState();
}

class _DataDiriState extends State<DataDiri> with MuatDenganCache {
  @override
  void initState() {
    super.initState();
    muatPath('/api/mobile/profil/');
  }

  Map get _d => (muat.data as Map?) ?? {};

  Future<void> _ubah() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _UbahKontak(id: (_d['profil'] as Map?)?['id'], awal: (_d['pribadi'] as Map?) ?? {})),
    );
    if (ok == true) segarkanPath();
  }

  @override
  Widget build(BuildContext context) {
    final ada = muat.data != null;
    final p = (_d['pribadi'] as Map?) ?? {};
    final k = (_d['pekerjaan'] as Map?) ?? {};
    final r = _d['rekening'] as Map?;
    final atasan = k['atasan'] as Map?;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Diri'),
        actions: [
          if (ada) TextButton(onPressed: _ubah, child: const Text('Ubah kontak', style: TextStyle(color: Warna.ink, fontWeight: FontWeight.w700))),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        color: Warna.navy,
        onRefresh: segarkanPath,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: !ada
              ? const [Kerangka(tinggi: 300, radius: 16)]
              : [
                  if (muat.galat != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('${muat.galat}', style: Teks.kecil)),
                  const JudulBagian('Pribadi'),
                  _grup([
                    _baris('Email', p['email']),
                    _baris('Nomor HP', p['phone']),
                    _baris('Alamat', [p['address'], p['city'], p['state']].where((e) => e != null && '$e'.isNotEmpty).join(', ')),
                    _baris('Tanggal lahir', p['dob'] == null ? null : tglPendek(p['dob'])),
                    _baris('Jenis kelamin', p['gender']),
                    _baris('Status nikah', p['marital_status']),
                    _baris('Pendidikan', p['qualification']),
                  ]),
                  const JudulBagian('Kontak darurat'),
                  _grup([
                    _baris('Nama', p['emergency_contact_name']),
                    _baris('Hubungan', p['emergency_contact_relation']),
                    _baris('Nomor', p['emergency_contact']),
                  ]),
                  const JudulBagian('Pekerjaan'),
                  _grup([
                    _baris('Jabatan', k['jabatan']),
                    _baris('Departemen', k['departemen']),
                    _baris('Atasan', atasan?['nama']),
                    _baris('Shift', k['shift']),
                    _baris('Tipe kerja', k['tipe_kerja']),
                    _baris('Status karyawan', k['tipe_karyawan']),
                    _baris('Lokasi', k['lokasi']),
                    _baris('Bergabung', k['tanggal_bergabung'] == null ? null : tglPendek(k['tanggal_bergabung'])),
                    _baris('Kontrak berakhir', k['kontrak_berakhir'] == null ? null : tglPendek(k['kontrak_berakhir'])),
                  ]),
                  const JudulBagian('Rekening gaji'),
                  _grup(r == null
                      ? [_baris('Rekening', null)]
                      : [_baris('Bank', r['bank']), _baris('Nomor', r['nomor']), _baris('Cabang', r['cabang'])]),
                  const SizedBox(height: 12),
                  const Text('Data pekerjaan dan rekening diubah oleh HR. Hubungi HR bila ada yang keliru.', style: Teks.kecil),
                ],
        ),
      ),
    );
  }

  Widget _grup(List<Widget> isi) => Kartu(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (var i = 0; i < isi.length; i++) ...[isi[i], if (i < isi.length - 1) const Divider(height: 1, color: Warna.garis)],
        ]),
      );

  Widget _baris(String label, dynamic nilai) {
    final kosong = nilai == null || '$nilai'.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120, child: Text(label, style: Teks.label)),
        Expanded(child: Text(kosong ? '-' : '$nilai', style: TextStyle(fontSize: 13, color: kosong ? Warna.faint : Warna.ink))),
      ]),
    );
  }
}

class _UbahKontak extends StatefulWidget {
  final dynamic id;
  final Map awal;

  const _UbahKontak({required this.id, required this.awal});

  @override
  State<_UbahKontak> createState() => _UbahKontakState();
}

class _UbahKontakState extends State<_UbahKontak> {
  static const _isian = [
    ('phone', 'Nomor HP', TextInputType.phone),
    ('address', 'Alamat', TextInputType.streetAddress),
    ('city', 'Kota', TextInputType.text),
    ('state', 'Provinsi', TextInputType.text),
    ('emergency_contact_name', 'Nama kontak darurat', TextInputType.name),
    ('emergency_contact_relation', 'Hubungan kontak darurat', TextInputType.text),
    ('emergency_contact', 'Nomor kontak darurat', TextInputType.phone),
  ];
  late final Map<String, TextEditingController> _c = {
    for (final f in _isian) f.$1: TextEditingController(text: '${widget.awal[f.$1] ?? ''}'),
  };
  bool _kirim = false;
  String? _galat;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _simpan() async {
    if (_c['phone']!.text.trim().isEmpty) {
      setState(() => _galat = 'Nomor HP wajib diisi.');
      return;
    }
    setState(() {
      _kirim = true;
      _galat = null;
    });
    try {
      await ApiMobile.put('/api/employee/employees/${widget.id}/', {
        for (final e in _c.entries) e.key: e.value.text.trim(),
      });
      if (!mounted) return;
      tampilkanPesan(context, 'Data diri disimpan.');
      Navigator.pop(context, true);
    } on ApiGagal catch (e) {
      setState(() => _galat = e.pesan);
    } finally {
      if (mounted) setState(() => _kirim = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ubah Kontak & Alamat')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
        children: [
          for (final f in _isian) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(f.$2, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Warna.ink2)),
            ),
            TextField(
              controller: _c[f.$1],
              keyboardType: f.$3,
              maxLines: f.$1 == 'address' ? 2 : 1,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Warna.garis)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Warna.navy)),
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (_galat != null) Text(_galat!, style: const TextStyle(fontSize: 12.5, color: Warna.tolak, fontWeight: FontWeight.w600)),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(18, 12, 18, 12 + MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Warna.garis))),
        child: TombolUtama('Simpan', ikon: Icons.check_rounded, proses: _kirim, onPressed: _simpan),
      ),
    );
  }
}
