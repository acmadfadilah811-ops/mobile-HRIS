import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/pdf_opener.dart';
import '../ui/tema.dart';

class MyDocuments extends StatefulWidget {
  const MyDocuments({super.key});

  @override
  State<MyDocuments> createState() => _MyDocumentsState();
}

class _MyDocumentsState extends State<MyDocuments>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String baseUrl = '';
  String token = '';

  bool isLoadingPayslip = true;
  bool isLoadingContract = true;
  List<Map<String, dynamic>> payslips = [];
  List<Map<String, dynamic>> contracts = [];
  int? openingId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      baseUrl = prefs.getString("typed_url") ?? '';
      token = prefs.getString("token") ?? '';
    });
    await Future.wait([_loadPayslips(), _loadContracts()]);
  }

  Future<void> _loadPayslips() async {
    setState(() => isLoadingPayslip = true);
    try {
      final uri = Uri.parse('$baseUrl/api/payroll/payslip/');
      final response = await http.get(uri, headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      });
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          payslips = (data['results'] as List)
              .map((e) => e as Map<String, dynamic>)
              .toList();
        });
      }
    } finally {
      setState(() => isLoadingPayslip = false);
    }
  }

  Future<void> _loadContracts() async {
    setState(() => isLoadingContract = true);
    try {
      final uri = Uri.parse('$baseUrl/api/payroll/contract/');
      final response = await http.get(uri, headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      });
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          contracts = (data['results'] as List)
              .map((e) => e as Map<String, dynamic>)
              .toList();
        });
      }
    } finally {
      setState(() => isLoadingContract = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF7F1D1D)),
    );
  }

  Future<void> _openPayslip(Map<String, dynamic> payslip) async {
    setState(() => openingId = payslip['id']);
    final url =
        '$baseUrl/api/payroll/payslip-download/${payslip['id']}?format=pdf';
    final periode =
        '${payslip['start_date']}_${payslip['end_date']}'.replaceAll('-', '');
    final error = await openPersistentPdf(
      url,
      token,
      'slip_gaji_${payslip['id']}_$periode',
    );
    setState(() => openingId = null);
    if (error != null) _showError(error);
  }

  // Tanda tangan kontrak sepenuhnya di web HR (karyawan dipanggil ke ruang
  // HRD, tanda tangan di komputer HR -- bukan di app mobile). Mobile cuma
  // menampilkan status & mengunduh dokumen final setelah HR menyetujui.
  // 2026-09-24: berkas kontrak yang diunggah HR langsung bisa dibuka tanpa
  // menunggu tanda tangan -- server mengirim `document_url` (versi bertanda
  // tangan diutamakan bila ada).
  Future<void> _openContract(Map<String, dynamic> contract) async {
    if (contract['document_url'] == null) return;

    setState(() => openingId = contract['id']);
    final path = contract['document_url'];
    if (path == null) {
      setState(() => openingId = null);
      _showError('Dokumen kontrak belum tersedia.');
      return;
    }
    final url = path.toString().startsWith('http') ? path : '$baseUrl$path';
    final error = await openTemporaryPdf(
      url,
      token,
      'contract_${contract['id']}',
    );
    setState(() => openingId = null);
    if (error != null) _showError(error);
  }

  // Status kontrak: ikon, label status (titik warna), keterangan, bisa dibuka atau tidak.
  ({IconData icon, LabelStatus label, String subtitle, bool tappable}) _contractStatus(Map<String, dynamic> contract) {
    if (contract['document_url'] != null) {
      final signed = contract['document_type'] == 'signed';
      return (
        icon: signed ? Icons.verified_outlined : Icons.description_outlined,
        label: signed ? const LabelStatus('Ditandatangani', titik: Warna.ok) : const LabelStatus('Dari HR', titik: Warna.info),
        subtitle: 'Ketuk untuk membuka.',
        tappable: true,
      );
    }
    if (contract['signed_at'] == null) {
      return (
        icon: Icons.hourglass_empty_rounded,
        label: const LabelStatus('Belum ada berkas'),
        subtitle: 'Dokumen kontrak belum diunggah HR.',
        tappable: false,
      );
    }
    if (contract['hr_signed_at'] == null) {
      return (
        icon: Icons.hourglass_top_rounded,
        label: const LabelStatus('Menunggu HR', titik: Warna.tunggu),
        subtitle: 'Menunggu persetujuan HR.',
        tappable: false,
      );
    }
    if (contract['is_downloadable'] == true) {
      var expiresText = '';
      final expiresAt = contract['download_expires_at'];
      if (expiresAt != null) expiresText = ' Tersedia sampai ${tglPendek(expiresAt)}.';
      return (
        icon: Icons.verified_outlined,
        label: const LabelStatus('Siap diunduh', titik: Warna.ok),
        subtitle: 'Ketuk untuk membuka.$expiresText',
        tappable: true,
      );
    }
    return (
      icon: Icons.event_busy_outlined,
      label: const LabelStatus('Kedaluwarsa', titik: Warna.tolak),
      subtitle: 'Masa unduh sudah berakhir. Hubungi HR untuk salinan baru.',
      tappable: false,
    );
  }

  String _formatPeriod(Map<String, dynamic> payslip) {
    final a = tglPendek(payslip['start_date']);
    final b = tglPendek(payslip['end_date']);
    return '$a - $b';
  }

  Widget _kerangka() => ListView(
        padding: const EdgeInsets.all(18),
        children: const [Kerangka(tinggi: 220, radius: 16)],
      );

  Widget _kosong(IconData ikon, String judul) => ListView(
        padding: const EdgeInsets.all(18),
        children: [Kartu(child: PesanKosong(ikon: ikon, judul: judul))],
      );

  Widget _baris({
    required IconData ikon,
    required String judul,
    required String sub,
    Widget? label,
    required bool memuat,
    VoidCallback? onTap,
    required bool terakhir,
  }) {
    return InkWell(
      onTap: memuat ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(border: terakhir ? null : const Border(bottom: BorderSide(color: Warna.garis))),
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
              Text(sub, style: Teks.kecil),
            ]),
          ),
          if (label != null) ...[const SizedBox(width: 8), label],
          const SizedBox(width: 8),
          if (memuat)
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Warna.muted))
          else if (onTap != null)
            const Icon(Icons.download_outlined, size: 20, color: Warna.muted),
        ]),
      ),
    );
  }

  Widget _payslipTab() {
    if (isLoadingPayslip) return _kerangka();
    if (payslips.isEmpty) return _kosong(Icons.receipt_long_outlined, 'Belum ada slip gaji.');
    return RefreshIndicator(
      color: Warna.navy,
      onRefresh: _loadPayslips,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Kartu(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (var i = 0; i < payslips.length; i++)
                _baris(
                  ikon: Icons.receipt_long_outlined,
                  judul: _formatPeriod(payslips[i]),
                  sub: 'Slip gaji',
                  label: LabelStatus('${payslips[i]['status'] ?? '-'}'),
                  memuat: openingId == payslips[i]['id'],
                  onTap: () => _openPayslip(payslips[i]),
                  terakhir: i == payslips.length - 1,
                ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _contractTab() {
    if (isLoadingContract) return _kerangka();
    if (contracts.isEmpty) return _kosong(Icons.description_outlined, 'Belum ada kontrak.');
    return RefreshIndicator(
      color: Warna.navy,
      onRefresh: _loadContracts,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Kartu(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (var i = 0; i < contracts.length; i++)
                Builder(builder: (_) {
                  final c = contracts[i];
                  final st = _contractStatus(c);
                  return _baris(
                    ikon: st.icon,
                    judul: '${c['contract_name'] ?? '-'}',
                    sub: st.subtitle,
                    label: st.label,
                    memuat: openingId == c['id'],
                    onTap: st.tappable ? () => _openContract(c) : null,
                    terakhir: i == contracts.length - 1,
                  );
                }),
            ]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dokumen Saya'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Warna.ink,
          indicatorColor: Warna.navy,
          unselectedLabelColor: Warna.muted,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [Tab(text: 'Slip Gaji'), Tab(text: 'Kontrak')],
        ),
      ),
      body: TabBarView(controller: _tabController, children: [_payslipTab(), _contractTab()]),
    );
  }
}
