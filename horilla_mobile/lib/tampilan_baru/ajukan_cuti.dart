// Form pengajuan cuti (2026-11-15): kirim ke POST /api/leave/user-request/ (endpoint yang sama
// dengan layar lama), jenis cuti dari saldo di /api/mobile/cuti/.
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api_mobile.dart';
import '../ui/tema.dart';

class AjukanCuti extends StatefulWidget {
  const AjukanCuti({super.key});

  @override
  State<AjukanCuti> createState() => _AjukanCutiState();
}

class _AjukanCutiState extends State<AjukanCuti> {
  List<Map> _jenis = [];
  bool _memuatJenis = true;
  String? _galatJenis;
  int? _jenisId;
  DateTime? _mulai;
  DateTime? _sampai;
  String _bagianMulai = 'full_day';
  String _bagianSampai = 'full_day';
  final _alasan = TextEditingController();
  PlatformFile? _lampiran;
  bool _kirim = false;
  String? _galat;

  static const _bagian = {'full_day': 'Sehari penuh', 'first_half': 'Paruh pertama', 'second_half': 'Paruh kedua'};

  @override
  void initState() {
    super.initState();
    _muatJenis();
  }

  @override
  void dispose() {
    _alasan.dispose();
    super.dispose();
  }

  Future<void> _muatJenis() async {
    const path = '/api/mobile/cuti/';
    final cache = await ApiMobile.bacaCache(path);
    if (cache != null) _isiJenis(cache);
    try {
      _isiJenis(await ApiMobile.segarkan(path));
      _galatJenis = null;
    } on ApiGagal catch (e) {
      _galatJenis = e.pesan;
    }
    if (mounted) setState(() => _memuatJenis = false);
  }

  void _isiJenis(dynamic data) {
    final saldo = ((data as Map?)?['saldo'] as List?) ?? [];
    if (!mounted) return;
    setState(() {
      _jenis = saldo.cast<Map>();
      if (_jenisId == null && _jenis.isNotEmpty) _jenisId = _jenis.first['leave_type_id'] as int?;
    });
  }

  Map? get _jenisTerpilih => _jenis.where((j) => j['leave_type_id'] == _jenisId).firstOrNull;

  String _iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pilihTanggal(bool mulai) async {
    final kini = DateTime.now();
    final awal = mulai ? (_mulai ?? kini) : (_sampai ?? _mulai ?? kini);
    final hasil = await showDatePicker(
      context: context,
      initialDate: awal,
      firstDate: DateTime(kini.year - 1),
      lastDate: DateTime(kini.year + 2),
      helpText: mulai ? 'Tanggal mulai cuti' : 'Tanggal selesai cuti',
    );
    if (hasil == null) return;
    setState(() {
      if (mulai) {
        _mulai = hasil;
        if (_sampai == null || _sampai!.isBefore(hasil)) _sampai = hasil;
      } else {
        _sampai = hasil;
      }
      _galat = null;
    });
  }

  double? get _perkiraanHari {
    if (_mulai == null || _sampai == null || _sampai!.isBefore(_mulai!)) return null;
    var hari = _sampai!.difference(_mulai!).inDays + 1.0;
    if (_bagianMulai != 'full_day') hari -= .5;
    if (_bagianSampai != 'full_day' && _sampai != _mulai) hari -= .5;
    return hari;
  }

  Future<void> _pilihLampiran() async {
    final hasil = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf']);
    if (hasil != null && hasil.files.single.path != null) setState(() => _lampiran = hasil.files.single);
  }

  Future<void> _kirimPengajuan() async {
    final kosong = <String>[
      if (_jenisId == null) 'jenis cuti',
      if (_mulai == null) 'tanggal mulai',
      if (_sampai == null) 'tanggal selesai',
      if (_alasan.text.trim().isEmpty) 'alasan',
    ];
    if (kosong.isNotEmpty) {
      setState(() => _galat = 'Lengkapi ${kosong.join(', ')}.');
      return;
    }
    if (_sampai!.isBefore(_mulai!)) {
      setState(() => _galat = 'Tanggal selesai tidak boleh sebelum tanggal mulai.');
      return;
    }
    if (_alasan.text.trim().length > 255) {
      setState(() => _galat = 'Alasan maksimal 255 karakter.');
      return;
    }
    setState(() {
      _kirim = true;
      _galat = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await ApiMobile.postMultipart(
        '/api/leave/user-request/',
        {
          'employee_id': '${prefs.getInt('employee_id') ?? ''}',
          'leave_type_id': '$_jenisId',
          'start_date': _iso(_mulai!),
          'end_date': _iso(_sampai!),
          'start_date_breakdown': _bagianMulai,
          'end_date_breakdown': _sampai == _mulai ? _bagianMulai : _bagianSampai,
          'description': _alasan.text.trim(),
        },
        fileField: _lampiran == null ? null : 'attachment',
        filePath: _lampiran?.path,
      );
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
              const Text('Pengajuan terkirim', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Atasan Anda akan mendapat notifikasi. Status bisa dipantau di menu Cuti.',
                  textAlign: TextAlign.center, style: Teks.kecil),
              const SizedBox(height: 18),
              TombolUtama('Selesai', onPressed: () => Navigator.pop(c)),
            ]),
          ),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiGagal catch (e) {
      setState(() => _galat = _terjemahkan(e.pesan));
    } finally {
      if (mounted) setState(() => _kirim = false);
    }
  }

  String _terjemahkan(String pesan) {
    final p = pesan.toLowerCase();
    if (p.contains('already has a leave request')) return 'Sudah ada pengajuan cuti di tanggal tersebut.';
    if (p.contains('does not have sufficient') || p.contains('not have enough') || p.contains('available')) {
      return 'Sisa cuti tidak cukup untuk tanggal yang dipilih.';
    }
    if (p.contains('attachment')) return 'Jenis cuti ini wajib melampirkan berkas.';
    return pesan;
  }

  @override
  Widget build(BuildContext context) {
    final jenis = _jenisTerpilih;
    final hari = _perkiraanHari;
    return Scaffold(
      appBar: AppBar(title: const Text('Ajukan Cuti')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
        children: [
          _label('Jenis cuti'),
          if (_memuatJenis && _jenis.isEmpty)
            const Kerangka(tinggi: 50, radius: 12)
          else if (_jenis.isEmpty)
            Kartu(
              child: Text(_galatJenis ?? 'Anda belum punya jatah cuti. Hubungi HR untuk pengaturan cuti.', style: Teks.isi),
            )
          else
            _kotak(DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                isExpanded: true,
                value: _jenisId,
                icon: const Icon(Icons.expand_more_rounded, color: Warna.muted),
                items: [
                  for (final j in _jenis)
                    DropdownMenuItem(
                      value: j['leave_type_id'] as int?,
                      child: Text('${j['nama']} (sisa ${angkaHari(j['sisa'])} hari)', style: const TextStyle(fontSize: 13.5)),
                    ),
                ],
                onChanged: (v) => setState(() => _jenisId = v),
              ),
            )),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _tanggal('Mulai', _mulai, () => _pilihTanggal(true))),
            const SizedBox(width: 10),
            Expanded(child: _tanggal('Sampai', _sampai, () => _pilihTanggal(false))),
          ]),
          const SizedBox(height: 14),
          _label(_mulai != null && _sampai == _mulai ? 'Durasi' : 'Durasi hari pertama'),
          _segmen(_bagianMulai, (v) => setState(() => _bagianMulai = v)),
          if (_mulai != null && _sampai != null && _sampai != _mulai) ...[
            const SizedBox(height: 10),
            _label('Durasi hari terakhir'),
            _segmen(_bagianSampai, (v) => setState(() => _bagianSampai = v)),
          ],
          if (hari != null && jenis != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFEEF0F4), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: Warna.ink2),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sekitar ${angkaHari(hari)} hari kalender. Sisa ${jenis['nama']} saat ini ${angkaHari(jenis['sisa'])} hari; '
                    'jumlah pastinya dihitung sistem sesuai hari kerja dan libur.',
                    style: const TextStyle(fontSize: 11.5, color: Warna.ink2, fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 14),
          _label('Alasan'),
          TextField(
            controller: _alasan,
            maxLines: 3,
            maxLength: 255,
            decoration: _dekorasi('Contoh: acara keluarga di luar kota'),
          ),
          const SizedBox(height: 4),
          _label('Lampiran (opsional, wajib untuk jenis cuti tertentu)'),
          InkWell(
            onTap: _pilihLampiran,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Warna.garis),
              ),
              child: Row(children: [
                const Icon(Icons.attach_file_rounded, color: Warna.muted, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_lampiran?.name ?? 'Pilih foto atau PDF', maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.5, color: _lampiran == null ? Warna.faint : Warna.ink)),
                ),
                if (_lampiran != null)
                  GestureDetector(onTap: () => setState(() => _lampiran = null), child: const Icon(Icons.close_rounded, size: 18, color: Warna.muted)),
              ]),
            ),
          ),
          if (_galat != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded, size: 18, color: Warna.tolak),
                const SizedBox(width: 8),
                Expanded(child: Text(_galat!, style: const TextStyle(fontSize: 12.5, color: Warna.ink2, fontWeight: FontWeight.w600))),
              ]),
            ),
          ],
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(18, 12, 18, 12 + MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Warna.garis))),
        child: TombolUtama('Kirim Pengajuan', ikon: Icons.send_rounded, proses: _kirim,
            onPressed: _jenis.isEmpty ? null : _kirimPengajuan),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Warna.ink2)),
      );

  Widget _kotak(Widget child) => Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Warna.garis)),
        child: child,
      );

  InputDecoration _dekorasi(String petunjuk) => InputDecoration(
        hintText: petunjuk,
        hintStyle: const TextStyle(color: Warna.faint, fontSize: 13.5),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(14),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Warna.garis)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Warna.navy)),
      );

  Widget _tanggal(String label, DateTime? nilai, VoidCallback onTap) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(label),
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: _kotak(Row(children: [
          const Icon(Icons.calendar_today_outlined, size: 18, color: Warna.muted),
          const SizedBox(width: 8),
          Text(nilai == null ? 'Pilih' : tglPendek(_iso(nilai)),
              style: TextStyle(fontSize: 13.5, color: nilai == null ? Warna.faint : Warna.ink)),
        ])),
      ),
    ]);
  }

  Widget _segmen(String nilai, ValueChanged<String> ubah) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Warna.garis)),
      child: Row(children: [
        for (final e in _bagian.entries)
          Expanded(
            child: GestureDetector(
              onTap: () => ubah(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(color: nilai == e.key ? Warna.navySoft : Colors.transparent, borderRadius: BorderRadius.circular(9)),
                child: Text(e.value, textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: nilai == e.key ? Warna.ink : Warna.muted)),
              ),
            ),
          ),
      ]),
    );
  }
}
