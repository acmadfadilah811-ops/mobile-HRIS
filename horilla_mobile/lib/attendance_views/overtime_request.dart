import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _hari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
const _bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

/// Format tanggal Indonesia tanpa bergantung pada inisialisasi locale intl.
String tanggalIndo(DateTime d) => '${_hari[d.weekday - 1]}, ${d.day} ${_bulan[d.month - 1]} ${d.year}';

/// Pengajuan Lembur (2026-09-24): karyawan mengajukan lembur di muka, atasan
/// langsung / HR menyetujui atau menolak. Server:
/// /api/attendance/overtime-request/ (GET ?scope=mine|approval, POST) dan
/// /api/attendance/overtime-request/<id>/<approve|reject|cancel>/.
class OvertimeRequestPage extends StatefulWidget {
  const OvertimeRequestPage({super.key});

  @override
  State<OvertimeRequestPage> createState() => _OvertimeRequestPageState();
}

class _OvertimeRequestPageState extends State<OvertimeRequestPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String baseUrl = '';
  String token = '';
  List<Map<String, dynamic>> _mine = [];
  List<Map<String, dynamic>> _approval = [];
  bool _loadingMine = true;
  bool _loadingApproval = true;
  int? _busyId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      baseUrl = prefs.getString('typed_url') ?? '';
      token = prefs.getString('token') ?? '';
    });
    _load('mine');
    _load('approval');
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<void> _load(String scope) async {
    setState(() {
      if (scope == 'mine') {
        _loadingMine = true;
      } else {
        _loadingApproval = true;
      }
    });
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/attendance/overtime-request/?scope=$scope'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body)['results'] as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        setState(() {
          if (scope == 'mine') {
            _mine = list;
          } else {
            _approval = list;
          }
        });
      }
    } catch (_) {
      _snack('Gagal memuat data. Periksa koneksi.');
    } finally {
      if (mounted) {
        setState(() {
          if (scope == 'mine') {
            _loadingMine = false;
          } else {
            _loadingApproval = false;
          }
        });
      }
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.lightBlue),
    );
  }

  Future<void> _aksi(Map<String, dynamic> req, String aksi, {String alasan = ''}) async {
    setState(() => _busyId = req['id'] as int);
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/attendance/overtime-request/${req['id']}/$aksi/'),
        headers: _headers,
        body: jsonEncode({'reason': alasan}),
      );
      if (res.statusCode == 200) {
        _snack(aksi == 'approve'
            ? 'Pengajuan disetujui.'
            : aksi == 'reject'
                ? 'Pengajuan ditolak.'
                : 'Pengajuan dibatalkan.');
        _load('mine');
        _load('approval');
      } else {
        _snack((jsonDecode(res.body)['error'] ?? 'Gagal memproses.').toString());
      }
    } catch (_) {
      _snack('Gagal memproses. Periksa koneksi.');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _tolak(Map<String, dynamic> req) async {
    final ctrl = TextEditingController();
    final alasan = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tolak Pengajuan'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Alasan penolakan'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
    if (alasan == null) return;
    if (alasan.isEmpty) {
      _snack('Alasan penolakan wajib diisi.');
      return;
    }
    _aksi(req, 'reject', alasan: alasan);
  }

  Future<void> _bukaForm() async {
    final terkirim = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OvertimeRequestFormPage(baseUrl: baseUrl, token: token),
      ),
    );
    if (terkirim == true) _load('mine');
  }

  Color _warna(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'canceled':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  String _tanggal(String? iso) {
    if (iso == null) return '-';
    try {
      return tanggalIndo(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  String _jam(String? t) => (t ?? '').length >= 5 ? t!.substring(0, 5) : (t ?? '-');

  Widget _kartu(Map<String, dynamic> req, {required bool approvalTab}) {
    final status = (req['status'] ?? '').toString();
    final busy = _busyId == req['id'];
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    approvalTab ? (req['employee_name'] ?? '') : _tanggal(req['date']),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _warna(status).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    (req['status_display'] ?? status).toString(),
                    style: TextStyle(fontSize: 11, color: _warna(status), fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (approvalTab) Text(_tanggal(req['date']), style: TextStyle(color: Colors.grey.shade700)),
            Text(
              '${_jam(req['start_time'])} - ${_jam(req['end_time'])}  (${req['durasi'] ?? '-'} jam)',
              style: TextStyle(color: Colors.grey.shade800),
            ),
            const SizedBox(height: 4),
            Text((req['reason'] ?? '').toString()),
            if ((req['approver_name'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Diputuskan oleh ${req['approver_name']}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ),
            if ((req['reject_reason'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Alasan ditolak: ${req['reject_reason']}',
                    style: const TextStyle(fontSize: 12, color: Colors.red)),
              ),
            if (busy)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              )
            else if (approvalTab && req['bisa_diputuskan'] == true)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => _tolak(req), child: const Text('Tolak', style: TextStyle(color: Colors.red))),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue),
                    onPressed: () => _aksi(req, 'approve'),
                    child: const Text('Setujui', style: TextStyle(color: Colors.white)),
                  ),
                ],
              )
            else if (!approvalTab && req['bisa_dibatalkan'] == true)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _aksi(req, 'cancel'),
                  child: const Text('Batalkan'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _daftar(List<Map<String, dynamic>> data, bool loading, String scope, String kosong) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: () => _load(scope),
      child: data.isEmpty
          ? ListView(children: [
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Text(kosong, style: TextStyle(color: Colors.grey.shade600))),
              ),
            ])
          : ListView(
              padding: const EdgeInsets.only(bottom: 90),
              children: data.map((r) => _kartu(r, approvalTab: scope == 'approval')).toList(),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengajuan Lembur'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.lightBlue,
          indicatorColor: Colors.lightBlue,
          unselectedLabelColor: Colors.grey,
          tabs: [
            const Tab(text: 'Pengajuan Saya'),
            Tab(text: _approval.isEmpty ? 'Persetujuan' : 'Persetujuan (${_approval.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _daftar(_mine, _loadingMine, 'mine', 'Belum ada pengajuan lembur.'),
          _daftar(_approval, _loadingApproval, 'approval', 'Tidak ada pengajuan yang menunggu persetujuan Anda.'),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _bukaForm,
              backgroundColor: Colors.lightBlue,
              icon: const Icon(Icons.add),
              label: const Text('Ajukan Lembur'),
            )
          : null,
    );
  }
}

class OvertimeRequestFormPage extends StatefulWidget {
  final String baseUrl;
  final String token;

  const OvertimeRequestFormPage({super.key, required this.baseUrl, required this.token});

  @override
  State<OvertimeRequestFormPage> createState() => _OvertimeRequestFormPageState();
}

class _OvertimeRequestFormPageState extends State<OvertimeRequestFormPage> {
  DateTime _tanggal = DateTime.now();
  TimeOfDay? _mulai;
  TimeOfDay? _selesai;
  final _alasan = TextEditingController();
  bool _mengirim = false;

  String _fmtJam(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _kirim() async {
    if (_mulai == null || _selesai == null) {
      _snack('Pilih jam mulai dan jam selesai.');
      return;
    }
    if (_alasan.text.trim().isEmpty) {
      _snack('Alasan / pekerjaan lembur wajib diisi.');
      return;
    }
    setState(() => _mengirim = true);
    try {
      final res = await http.post(
        Uri.parse('${widget.baseUrl}/api/attendance/overtime-request/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'date': DateFormat('yyyy-MM-dd').format(_tanggal),
          'start_time': _fmtJam(_mulai!),
          'end_time': _fmtJam(_selesai!),
          'reason': _alasan.text.trim(),
        }),
      );
      if (res.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengajuan lembur terkirim.'), backgroundColor: Colors.lightBlue),
        );
        Navigator.pop(context, true);
      } else {
        _snack((jsonDecode(res.body)['error'] ?? 'Gagal mengirim pengajuan.').toString());
      }
    } catch (_) {
      _snack('Gagal mengirim. Periksa koneksi.');
    } finally {
      if (mounted) setState(() => _mengirim = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.lightBlue),
    );
  }

  Widget _pemilih(String label, String nilai, VoidCallback onTap, IconData ikon) {
    return Card(
      child: ListTile(
        leading: Icon(ikon, color: Colors.lightBlue),
        title: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        subtitle: Text(nilai, style: const TextStyle(fontSize: 16, color: Colors.black87)),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajukan Lembur')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _pemilih('Tanggal Lembur', tanggalIndo(_tanggal), () async {
            final pilih = await showDatePicker(
              context: context,
              initialDate: _tanggal,
              firstDate: DateTime.now().subtract(const Duration(days: 30)),
              lastDate: DateTime.now().add(const Duration(days: 60)),
            );
            if (pilih != null) setState(() => _tanggal = pilih);
          }, Icons.event),
          _pemilih('Jam Mulai', _mulai == null ? 'Pilih jam' : _fmtJam(_mulai!), () async {
            final t = await showTimePicker(context: context, initialTime: _mulai ?? const TimeOfDay(hour: 17, minute: 0));
            if (t != null) setState(() => _mulai = t);
          }, Icons.schedule),
          _pemilih('Jam Selesai', _selesai == null ? 'Pilih jam' : _fmtJam(_selesai!), () async {
            final t = await showTimePicker(context: context, initialTime: _selesai ?? const TimeOfDay(hour: 19, minute: 0));
            if (t != null) setState(() => _selesai = t);
          }, Icons.schedule_outlined),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: TextField(
                controller: _alasan,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Alasan / Pekerjaan',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lembur dibayar sesuai absensi nyata, paling banyak sebesar jam yang disetujui atasan.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue),
              onPressed: _mengirim ? null : _kirim,
              child: _mengirim
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Kirim Pengajuan', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
