// Tampilan baru StarFoto HR (2026-11-15), acuan prototipe-mobile-hr/index.html:
// navy dari logo, aksen oranye sedikit, teks selalu hitam/abu-abu, warna hanya di garis
// bawah kartu, bar progres, dan titik kecil label status.
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class Warna {
  static const navy = Color(0xFF1F2A55);
  static const navySoft = Color(0xFFEEF0F7);
  static const oranye = Color(0xFFE8792B);
  static const ink = Color(0xFF0F172A);
  static const ink2 = Color(0xFF334155);
  static const muted = Color(0xFF64748B);
  static const faint = Color(0xFF94A3B8);
  static const garis = Color(0xFFE5E7EB);
  static const latar = Color(0xFFF4F5F8);
  static const kartu = Colors.white;
  static const abuMuda = Color(0xFFF1F5F9);

  // Palet garis aksen kartu -- sama dengan kartu dashboard ERP (AKSEN di PanelPeriode.jsx).
  static const hijau = Color(0xFF3ED0A8);
  static const kuning = Color(0xFFF5D90A);
  static const biru = Color(0xFF1890FF);
  static const ungu = Color(0xFF7B2FD0);
  static const merah = Color(0xFFE5333F);
  static const indigo = Color(0xFF4F46E5);
  static const slate = Color(0xFF94A3B8);

  // Titik label status.
  static const ok = Color(0xFF16A34A);
  static const tunggu = Color(0xFFF59E0B);
  static const tolak = Color(0xFFDC2626);
  static const info = Color(0xFF2563EB);
}

ThemeData temaAplikasi() {
  final dasar = ThemeData(useMaterial3: true, colorSchemeSeed: Warna.navy);
  return dasar.copyWith(
    scaffoldBackgroundColor: Warna.latar,
    textTheme: dasar.textTheme.apply(bodyColor: Warna.ink, displayColor: Warna.ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: Warna.latar,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Warna.ink,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Warna.ink),
    ),
  );
}

class Teks {
  static const label = TextStyle(fontSize: 11.5, color: Warna.muted, fontWeight: FontWeight.w600);
  static const judulBagian = TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Warna.ink);
  static const angka = TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Warna.ink);
  static const isi = TextStyle(fontSize: 13, color: Warna.ink2);
  static const kecil = TextStyle(fontSize: 11.5, color: Warna.muted);
}

/// Kartu putih bergaris tepi tipis; `aksen` menambah garis warna 6px di bawah.
class Kartu extends StatelessWidget {
  final Widget child;
  final Color? aksen;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const Kartu({super.key, required this.child, this.aksen, this.padding = const EdgeInsets.all(14), this.onTap});

  @override
  Widget build(BuildContext context) {
    final isi = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: padding, child: child),
        if (aksen != null) Container(height: 6, color: aksen),
      ],
    );
    return Material(
      color: Warna.kartu,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Warna.garis),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? isi : InkWell(onTap: onTap, child: isi),
    );
  }
}

/// Label status: teks abu gelap, warna hanya di titik kecil.
class LabelStatus extends StatelessWidget {
  final String teks;
  final Color titik;

  const LabelStatus(this.teks, {super.key, this.titik = Warna.slate});

  factory LabelStatus.cuti(String status) {
    switch (status) {
      case 'approved':
        return const LabelStatus('Disetujui', titik: Warna.ok);
      case 'rejected':
        return const LabelStatus('Ditolak', titik: Warna.tolak);
      case 'cancelled':
        return const LabelStatus('Dibatalkan', titik: Warna.slate);
      default:
        return const LabelStatus('Menunggu', titik: Warna.tunggu);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 9, 4),
      decoration: BoxDecoration(color: Warna.abuMuda, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: titik, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(teks, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Warna.ink2)),
      ]),
    );
  }
}

/// Kotak abu berkilau untuk menunggu data pertama kali (bukan putaran loading).
class Kerangka extends StatelessWidget {
  final double tinggi;
  final double? lebar;
  final double radius;

  const Kerangka({super.key, this.tinggi = 16, this.lebar, this.radius = 10});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFECEEF2),
      highlightColor: const Color(0xFFF7F8FA),
      child: Container(
        height: tinggi,
        width: lebar,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(radius)),
      ),
    );
  }
}

class JudulBagian extends StatelessWidget {
  final String judul;
  final String? aksi;
  final VoidCallback? onAksi;

  const JudulBagian(this.judul, {super.key, this.aksi, this.onAksi});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 22, 0, 10),
      child: Row(children: [
        Expanded(child: Text(judul, style: Teks.judulBagian)),
        if (aksi != null)
          GestureDetector(
            onTap: onAksi,
            child: Text(aksi!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Warna.ink2)),
          ),
      ]),
    );
  }
}

class TombolUtama extends StatelessWidget {
  final String label;
  final IconData? ikon;
  final VoidCallback? onPressed;
  final bool proses;
  final bool garis;

  const TombolUtama(this.label, {super.key, this.ikon, this.onPressed, this.proses = false, this.garis = false});

  @override
  Widget build(BuildContext context) {
    final warnaTeks = garis ? Warna.ink : Colors.white;
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: proses ? null : onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: garis ? Colors.white : Warna.navy,
          disabledBackgroundColor: garis ? Colors.white : Warna.navy.withOpacity(.55),
          foregroundColor: warnaTeks,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: garis ? const BorderSide(color: Warna.garis) : BorderSide.none,
          ),
        ),
        child: proses
            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: warnaTeks))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                if (ikon != null) ...[Icon(ikon, size: 20, color: warnaTeks), const SizedBox(width: 8)],
                Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: warnaTeks)),
              ]),
      ),
    );
  }
}

class AvatarInisial extends StatelessWidget {
  final String inisial;
  final String? foto;
  final double ukuran;
  final bool gelap;

  const AvatarInisial({super.key, required this.inisial, this.foto, this.ukuran = 42, this.gelap = false});

  @override
  Widget build(BuildContext context) {
    final latar = gelap ? Colors.white.withOpacity(.14) : Warna.navySoft;
    final warnaTeks = gelap ? Colors.white : Warna.ink;
    final cadangan = Center(
      child: Text(inisial, style: TextStyle(fontWeight: FontWeight.w800, fontSize: ukuran * .33, color: warnaTeks)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(ukuran * .33),
      child: Container(
        width: ukuran,
        height: ukuran,
        color: latar,
        child: (foto == null || foto!.isEmpty)
            ? cadangan
            : Image.network(foto!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => cadangan),
      ),
    );
  }
}

/// Bar progres tipis berwarna aksen.
class BarProgres extends StatelessWidget {
  final double nilai; // 0..1
  final Color warna;
  final Color latar;

  const BarProgres({super.key, required this.nilai, required this.warna, this.latar = const Color(0xFFEEF0F4)});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: LinearProgressIndicator(
        value: nilai.isNaN ? 0 : nilai.clamp(0, 1).toDouble(),
        minHeight: 5,
        backgroundColor: latar,
        valueColor: AlwaysStoppedAnimation(warna),
      ),
    );
  }
}

/// Pesan kosong/gagal yang rapi.
class PesanKosong extends StatelessWidget {
  final IconData ikon;
  final String judul;
  final String? isi;
  final String? aksi;
  final VoidCallback? onAksi;

  const PesanKosong({super.key, required this.ikon, required this.judul, this.isi, this.aksi, this.onAksi});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(children: [
        Icon(ikon, size: 36, color: Warna.faint),
        const SizedBox(height: 10),
        Text(judul, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, color: Warna.ink2)),
        if (isi != null) ...[
          const SizedBox(height: 4),
          Text(isi!, textAlign: TextAlign.center, style: Teks.kecil),
        ],
        if (aksi != null) ...[
          const SizedBox(height: 12),
          TextButton(onPressed: onAksi, child: Text(aksi!, style: const TextStyle(color: Warna.ink, fontWeight: FontWeight.w700))),
        ],
      ]),
    );
  }
}

const _bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
const _bulanPanjang = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];
const _hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

DateTime? tanggalDari(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

/// "15 Nov 2026"
String tglPendek(dynamic v) {
  final d = tanggalDari(v);
  if (d == null) return '-';
  return '${d.day} ${_bulan[d.month - 1]} ${d.year}';
}

/// "Sabtu, 15 November 2026"
String tglPanjang(DateTime d) => '${_hari[d.weekday - 1]}, ${d.day} ${_bulanPanjang[d.month - 1]} ${d.year}';

String namaBulan(int bulan, int tahun) => '${_bulanPanjang[bulan - 1]} $tahun';

String hariSingkat(DateTime d) => _hari[d.weekday - 1].substring(0, 3);

/// 8.0 -> "8", 1.5 -> "1,5"
String angkaHari(dynamic v) {
  final n = (v is num) ? v : num.tryParse('$v') ?? 0;
  if (n == n.roundToDouble()) return n.toInt().toString();
  return n.toStringAsFixed(1).replaceAll('.', ',');
}
