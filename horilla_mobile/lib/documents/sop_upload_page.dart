import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Form upload SOP dari mobile -- hanya muncul untuk pengguna yang lolos
/// permission-check base.add_companydocument (lihat company_documents.dart,
/// _CompanyDocumentsState._checkUploadPermission), sama seperti syarat form
/// upload di dashboard web. Server (POST /api/base/company-documents/create/)
/// mengecek ulang permission yang sama -- gate di app ini murni untuk
/// UX (sembunyikan tombol), bukan satu-satunya penjaga.
class SopUploadPage extends StatefulWidget {
  final String baseUrl;
  final String token;

  const SopUploadPage({
    super.key,
    required this.baseUrl,
    required this.token,
  });

  @override
  State<SopUploadPage> createState() => _SopUploadPageState();
}

class _SopUploadPageState extends State<SopUploadPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();

  bool _loadingDepartments = true;
  String? _departmentsError;
  List<Map<String, dynamic>> _departments = [];
  int? _selectedDepartmentId;

  File? _pickedFile;
  String? _pickedFileName;

  bool _submitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    setState(() {
      _loadingDepartments = true;
      _departmentsError = null;
    });
    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/api/base/departments/'),
        headers: {"Authorization": "Bearer ${widget.token}"},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _departments = (data['results'] as List)
              .map((e) => e as Map<String, dynamic>)
              .toList();
        });
      } else {
        setState(() => _departmentsError =
            'Gagal memuat daftar divisi (${response.statusCode}).');
      }
    } catch (e) {
      setState(() => _departmentsError = 'Gagal memuat daftar divisi: $e');
    } finally {
      setState(() => _loadingDepartments = false);
    }
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );
      if (result == null || result.files.single.path == null) return;
      final file = File(result.files.single.path!);
      final sizeInMb = (await file.length()) / (1024 * 1024);
      if (sizeInMb > 25) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ukuran file PDF harus di bawah 25MB.')),
        );
        return;
      }
      setState(() {
        _pickedFile = file;
        _pickedFileName = result.files.single.name;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih file: $e')),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedFile == null) {
      setState(() => _submitError = 'Pilih file PDF terlebih dahulu.');
      return;
    }
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final uri =
          Uri.parse('${widget.baseUrl}/api/base/company-documents/create/');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer ${widget.token}'
        ..fields['title'] = _titleController.text.trim()
        ..fields['category'] = 'sop';
      if (_selectedDepartmentId != null) {
        request.fields['department_id'] = _selectedDepartmentId.toString();
      }
      request.files
          .add(await http.MultipartFile.fromPath('file', _pickedFile!.path));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 201) {
        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      }
      if (response.statusCode == 403) {
        setState(() => _submitError =
            'Tidak punya izin untuk mengunggah SOP.');
        return;
      }
      setState(() => _submitError =
          'Gagal mengunggah (${response.statusCode}). ${response.body}');
    } catch (e) {
      setState(() => _submitError = 'Gagal mengunggah: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unggah SOP')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Judul SOP',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Judul wajib diisi'
                  : null,
            ),
            const SizedBox(height: 16),
            if (_loadingDepartments)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              )
            else if (_departmentsError != null)
              Row(
                children: [
                  Expanded(
                    child: Text(_departmentsError!,
                        style: const TextStyle(color: Colors.redAccent)),
                  ),
                  TextButton(
                    onPressed: _loadDepartments,
                    child: const Text('Coba lagi'),
                  ),
                ],
              )
            else
              DropdownButtonFormField<int?>(
                initialValue: _selectedDepartmentId,
                decoration: const InputDecoration(
                  labelText: 'Divisi (opsional -- kosongkan untuk SOP umum)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Umum (tidak per divisi)'),
                  ),
                  ..._departments.map(
                    (d) => DropdownMenuItem<int?>(
                      value: d['id'] as int,
                      child: Text(d['department']?.toString() ?? '-'),
                    ),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _selectedDepartmentId = value),
              ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _submitting ? null : _pickPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: Text(_pickedFileName ?? 'Pilih File PDF'),
            ),
            if (_submitError != null) ...[
              const SizedBox(height: 12),
              Text(_submitError!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(backgroundColor: Colors.lightBlue),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Unggah'),
            ),
          ],
        ),
      ),
    );
  }
}
