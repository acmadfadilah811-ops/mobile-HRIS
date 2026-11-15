// Kerangka utama aplikasi (2026-11-15): navigasi bawah Beranda / Absensi / Absen / Cuti / Profil.
// Keempat tab disimpan di IndexedStack -- pindah tab tidak memuat ulang layar, sehingga langsung tampil.
import 'package:flutter/material.dart';

import '../ui/tema.dart';
import 'absensi_saya.dart';
import 'beranda.dart';
import 'cuti_saya.dart';
import 'profil.dart';

class HalamanUtama extends StatefulWidget {
  final int tabAwal;

  const HalamanUtama({super.key, this.tabAwal = 0});

  @override
  State<HalamanUtama> createState() => HalamanUtamaState();
}

class HalamanUtamaState extends State<HalamanUtama> {
  late int _tab = widget.tabAwal;
  final _kunciBeranda = GlobalKey<BerandaState>();
  final _kunciAbsensi = GlobalKey<AbsensiSayaState>();
  final _kunciCuti = GlobalKey<CutiSayaState>();

  void pindahTab(int i) => setState(() => _tab = i);

  /// Buka layar absen; setelah kembali, Beranda dan Absensi disegarkan.
  Future<void> bukaAbsen() async {
    await Navigator.pushNamed(context, '/employee_checkin_checkout');
    _kunciBeranda.currentState?.segarkan();
    _kunciAbsensi.currentState?.segarkan();
  }

  void segarkanCuti() => _kunciCuti.currentState?.segarkan();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: [
        Beranda(key: _kunciBeranda, induk: this),
        AbsensiSaya(key: _kunciAbsensi),
        CutiSaya(key: _kunciCuti, saatBerubah: () => _kunciBeranda.currentState?.segarkan()),
        const Profil(),
      ]),
      bottomNavigationBar: _NavBawah(
        aktif: _tab,
        onTab: pindahTab,
        onAbsen: bukaAbsen,
      ),
    );
  }
}

class _NavBawah extends StatelessWidget {
  final int aktif;
  final ValueChanged<int> onTab;
  final VoidCallback onAbsen;

  const _NavBawah({required this.aktif, required this.onTab, required this.onAbsen});

  @override
  Widget build(BuildContext context) {
    Widget item(int i, IconData ikon, IconData ikonAktif, String label) {
      final on = aktif == i;
      return Expanded(
        child: InkWell(
          onTap: () => onTab(i),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(on ? ikonAktif : ikon, size: 23, color: on ? Warna.ink : Warna.faint),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: on ? Warna.ink : Warna.faint)),
          ]),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Warna.garis))),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(children: [
            item(0, Icons.home_outlined, Icons.home_rounded, 'Beranda'),
            item(1, Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Absensi'),
            Expanded(
              child: Center(
                child: Material(
                  color: Warna.navy,
                  borderRadius: BorderRadius.circular(18),
                  elevation: 4,
                  shadowColor: Warna.navy.withOpacity(.5),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: onAbsen,
                    child: const SizedBox(
                      width: 54,
                      height: 50,
                      child: Icon(Icons.fingerprint_rounded, color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ),
            ),
            item(2, Icons.beach_access_outlined, Icons.beach_access_rounded, 'Cuti'),
            item(3, Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
          ]),
        ),
      ),
    );
  }
}
