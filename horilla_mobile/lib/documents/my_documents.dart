import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import '../utils/pdf_opener.dart';

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
      SnackBar(content: Text(message), backgroundColor: Colors.lightBlue),
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

  ({IconData icon, Color color, String subtitle, bool tappable})
      _contractStatus(Map<String, dynamic> contract) {
    if (contract['document_url'] != null) {
      final signed = contract['document_type'] == 'signed';
      return (
        icon: signed ? Icons.verified_outlined : Icons.description_outlined,
        color: signed ? Colors.green : Colors.lightBlue,
        subtitle: signed
            ? 'Kontrak bertanda tangan. Ketuk untuk membuka.'
            : 'Dokumen kontrak dari HR. Ketuk untuk membuka.',
        tappable: true,
      );
    }
    if (contract['signed_at'] == null) {
      return (
        icon: Icons.hourglass_empty,
        color: Colors.grey,
        subtitle: 'Dokumen kontrak belum diunggah HR.',
        tappable: false,
      );
    }
    if (contract['hr_signed_at'] == null) {
      return (
        icon: Icons.hourglass_top,
        color: Colors.lightBlue,
        subtitle: 'Menunggu persetujuan HR.',
        tappable: false,
      );
    }
    if (contract['is_downloadable'] == true) {
      var expiresText = '';
      final expiresAt = contract['download_expires_at'];
      if (expiresAt != null) {
        try {
          expiresText =
              ' Tersedia sampai ${DateFormat('d MMM yyyy').format(DateTime.parse(expiresAt))}.';
        } catch (_) {}
      }
      return (
        icon: Icons.verified_outlined,
        color: Colors.green,
        subtitle: 'Siap diunduh.$expiresText',
        tappable: true,
      );
    }
    return (
      icon: Icons.event_busy,
      color: Colors.grey,
      subtitle: 'Masa unduh sudah berakhir. Hubungi HR untuk salinan baru.',
      tappable: false,
    );
  }

  String _formatPeriod(Map<String, dynamic> payslip) {
    try {
      final start = DateFormat('yyyy-MM-dd').parse(payslip['start_date']);
      final end = DateFormat('yyyy-MM-dd').parse(payslip['end_date']);
      final formatter = DateFormat('d MMM yyyy');
      return '${formatter.format(start)} - ${formatter.format(end)}';
    } catch (_) {
      return '${payslip['start_date']} - ${payslip['end_date']}';
    }
  }

  Widget _shimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 4,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Container(
          height: 72,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ),
    );
  }

  Widget _payslipTab() {
    if (isLoadingPayslip) return _shimmerList();
    if (payslips.isEmpty) return _emptyState('Belum ada slip gaji.');
    return RefreshIndicator(
      onRefresh: _loadPayslips,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: payslips.length,
        itemBuilder: (context, index) {
          final payslip = payslips[index];
          final isOpening = openingId == payslip['id'];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.receipt_long, color: Colors.lightBlue),
              title: Text(_formatPeriod(payslip)),
              subtitle: Text(
                'Status: ${payslip['status'] ?? '-'}',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              trailing: isOpening
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
              onTap: isOpening ? null : () => _openPayslip(payslip),
            ),
          );
        },
      ),
    );
  }

  Widget _contractTab() {
    if (isLoadingContract) return _shimmerList();
    if (contracts.isEmpty) return _emptyState('Belum ada kontrak.');
    return RefreshIndicator(
      onRefresh: _loadContracts,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: contracts.length,
        itemBuilder: (context, index) {
          final contract = contracts[index];
          final status = _contractStatus(contract);
          final isOpening = openingId == contract['id'];
          return Card(
            child: ListTile(
              leading: Icon(status.icon, color: status.color),
              title: Text(contract['contract_name'] ?? '-'),
              subtitle: Text(
                status.subtitle,
                style: TextStyle(color: Colors.grey.shade700),
              ),
              trailing: isOpening
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : (status.tappable
                      ? const Icon(Icons.download_outlined)
                      : null),
              onTap: (isOpening || !status.tappable)
                  ? null
                  : () => _openContract(contract),
            ),
          );
        },
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
          labelColor: Colors.lightBlue,
          indicatorColor: Colors.lightBlue,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Slip Gaji'),
            Tab(text: 'Kontrak'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_payslipTab(), _contractTab()],
      ),
    );
  }
}
