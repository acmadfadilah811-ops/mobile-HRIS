// Profil (2026-11-15): data diri dari /api/mobile/beranda/ (berbagi cache dengan Beranda),
// menu menuju layar yang sudah ada, dan keluar akun.
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api_mobile.dart';
import '../ui/tema.dart';
import 'data_diri.dart';
import 'tim.dart';

class Profil extends StatefulWidget {
  const Profil({super.key});

  @override
  State<Profil> createState() => _ProfilState();
}

class _ProfilState extends State<Profil> with MuatDenganCache {
  @override
  void initState() {
    super.initState();
    muatPath('/api/mobile/beranda/');
  }

  Map get _p => ((muat.data as Map?)?['profil'] as Map?) ?? {};

  void _buka(String rute, {Object? argumen}) => Navigator.pushNamed(context, rute, arguments: argumen);

  /// Sama dengan logika keluar di Beranda lama: ingatkan bila sesi kerja Bintang masih terbuka.
  Future<bool> _sesiBintangTerbuka() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final url = prefs.getString('typed_url');
      if (token == null || url == null) return false;
      final r = await http
          .get(Uri.parse('$url/api/attendance/bintang-status/'), headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 5));
      if (r.statusCode != 200) return false;
      final d = jsonDecode(r.body);
      return d['applicable'] == true && d['has_open_session'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _keluar() async {
    final bintang = await _sesiBintangTerbuka();
    if (!mounted) return;
    final yakin = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Keluar dari akun?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        content: Text(bintang
            ? 'Anda masih tercatat "Mulai Kerja" di sistem Bintang hari ini. Sebaiknya tekan "Selesai Kerja" di Bintang dulu supaya jam kerja tercatat benar.'
            : 'Anda perlu masuk lagi untuk memakai aplikasi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal', style: TextStyle(color: Warna.muted))),
          TextButton(onPressed: () => Navigator.pop(c, true),
              child: Text(bintang ? 'Tetap keluar' : 'Keluar', style: const TextStyle(color: Warna.ink, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (yakin != true) return;
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('typed_url');
    await prefs.remove('token');
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false, arguments: url);
  }

  @override
  Widget build(BuildContext context) {
    final ada = muat.data != null;
    final p = _p;
    return Scaffold(
      appBar: AppBar(title: const Text('Profil'), automaticallyImplyLeading: false),
      body: RefreshIndicator(
        color: Warna.navy,
        onRefresh: segarkanPath,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Center(child: AvatarInisial(inisial: p['inisial'] ?? '', foto: p['foto'], ukuran: 76)),
            const SizedBox(height: 10),
            if (!ada)
              const Center(child: Kerangka(tinggi: 18, lebar: 160))
            else ...[
              Text(p['nama'] ?? '-', textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text([p['jabatan'], p['departemen']].where((e) => e != null).join(' - '),
                  textAlign: TextAlign.center, style: Teks.isi),
              const SizedBox(height: 10),
              Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
                if (p['badge_id'] != null) LabelStatus('NIK ${p['badge_id']}'),
                if (p['tanggal_bergabung'] != null) LabelStatus('Bergabung ${tglPendek(p['tanggal_bergabung'])}'),
              ]),
            ],
            const SizedBox(height: 18),
            _grup([
              _menu(Icons.badge_outlined, 'Data diri & pekerjaan', 'Kontak, alamat, jabatan, atasan, rekening',
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DataDiri()))),
              if ((muat.data as Map?)?['punya_tim'] == true)
                _menu(Icons.groups_outlined, 'Tim saya', 'Status absen tim hari ini',
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TimSaya()))),
              _menu(Icons.description_outlined, 'Dokumen saya', 'Unggah dan lihat dokumen pribadi', () => _buka('/my_documents')),
              _menu(Icons.folder_open_outlined, 'Dokumen perusahaan', 'SOP dan peraturan', () => _buka('/company_documents')),
              _menu(Icons.notifications_none_rounded, 'Notifikasi', null, () => _buka('/notifications_list')),
            ]),
            const SizedBox(height: 12),
            _grup([
              _menu(Icons.logout_rounded, 'Keluar', null, _keluar),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _grup(List<Widget> isi) => Kartu(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (var i = 0; i < isi.length; i++) ...[
            isi[i],
            if (i < isi.length - 1) const Divider(height: 1, color: Warna.garis),
          ],
        ]),
      );

  Widget _menu(IconData ikon, String judul, String? sub, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: Warna.latar, borderRadius: BorderRadius.circular(12)),
            child: Icon(ikon, size: 20, color: Warna.ink2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(judul, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              if (sub != null) Text(sub, style: Teks.kecil),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: Warna.faint),
        ]),
      ),
    );
  }
}
