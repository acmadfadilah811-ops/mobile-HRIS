import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../ui/tema.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late StreamSubscription subscription;
  var isDeviceConnected = false;
  bool isAlertSet = false;
  bool _passwordVisible = false;
  // Alamat server tetap -- kolom "Alamat Server" di layar login dihapus.
  // Tetap disimpan ke SharedPreferences ("typed_url") saat login karena
  // seluruh layar lain membacanya dari sana.
  static const String _serverAddress = 'https://hr.starphotoadvertising.com';
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  double horizontalMargin = 0.0;
  Timer? _notificationTimer;


  @override
  void initState() {
    super.initState();
    getConnectivity();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      double screenWidth = MediaQuery.of(context).size.width;
      setState(() {
        horizontalMargin = screenWidth * 0.1;
      });
    });
  }

  void _startNotificationTimer() {
    _notificationTimer?.cancel();
    // 30 detik dan satu permintaan (lihat catatan di main.dart).
    _notificationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (isAuthenticated) {
        fetchNotifications();
      } else {
        timer.cancel();
        _notificationTimer = null;
      }
    });
  }



  Future<void> _login() async {
    const String serverAddress = _serverAddress;
    String username = usernameController.text.trim();
    String password = passwordController.text.trim();
    String url = '$serverAddress/api/auth/login/';

    try {
      http.Response response = await http.post(
        Uri.parse(url),
        body: {'username': username, 'password': password},
      ).timeout(Duration(seconds: 3));

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);

        var token = responseBody['access'] ?? '';

        var employeeId = responseBody['employee']?['id'] ?? 0;
        var companyId = responseBody['company_id'] ?? 0;
        bool face_detection = responseBody['face_detection'] ?? false;
        bool geo_fencing = responseBody['geo_fencing'] ?? false;
        var face_detection_image = responseBody['face_detection_image']?.toString() ?? '';


        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("token", token);
        await prefs.setString("typed_url", serverAddress);
        await prefs.setString("face_detection_image", face_detection_image);
        await prefs.setBool("face_detection", face_detection);
        await prefs.setBool("geo_fencing", geo_fencing);
        await prefs.setInt("employee_id", employeeId);
        await prefs.setInt("company_id", companyId);

        isAuthenticated = true;
        _startNotificationTimer();
        prefetchData();

        Navigator.pushReplacementNamed(context, '/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email atau kata sandi tidak valid'),
            backgroundColor: Colors.lightBlue,
          ),
        );
      }
    } on TimeoutException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Batas waktu koneksi habis'),
          backgroundColor: Colors.lightBlue,
        ),
      );
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.'),
          backgroundColor: Colors.lightBlue,
        ),
      );
    }
  }


  void _snack(String pesan) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(pesan), backgroundColor: Colors.lightBlue),
    );
  }

  // Lupa kata sandi: server mengirim tautan ke email terdaftar; kata sandi
  // baru dibuat di halaman web yang terbuka dari tautan itu. Respons server
  // sengaja sama untuk akun yang ada maupun tidak (anti-enumerasi).
  Future<void> _showForgotPassword() async {
    final controller =
        TextEditingController(text: usernameController.text.trim());
    final kirim = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Lupa kata sandi',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan email Anda. Tautan untuk membuat kata sandi baru '
              'akan dikirim ke email yang terdaftar.',
              style: TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Email',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Warna.navy,
              foregroundColor: Colors.white,
            ),
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
    final username = controller.text.trim();
    controller.dispose();
    if (kirim != true) return;
    if (username.isEmpty) {
      _snack('Masukkan email Anda terlebih dahulu.');
      return;
    }
    try {
      final response = await http.post(
        Uri.parse('$_serverAddress/api/auth/forgot-password/'),
        body: {'username': username},
      ).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (response.statusCode == 200) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Text('Periksa email Anda'),
            content: const Text(
              'Jika akun ditemukan, tautan untuk membuat kata sandi baru '
              'sudah dikirim ke email terdaftar. Buka email itu lalu ikuti '
              'tautannya. Cek folder Spam bila belum muncul.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Mengerti'),
              ),
            ],
          ),
        );
      } else if (response.statusCode == 429) {
        _snack('Terlalu banyak percobaan. Coba lagi beberapa menit lagi.');
      } else if (response.statusCode == 503) {
        _snack('Layanan email belum siap. Hubungi HR.');
      } else {
        _snack('Gagal mengirim tautan. Coba lagi.');
      }
    } on TimeoutException {
      _snack('Batas waktu koneksi habis. Coba lagi.');
    } catch (_) {
      _snack('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    }
  }

  void getConnectivity() {
    // subscription = InternetConnectionChecker().onStatusChange.listen((status) {
    //   setState(() {
    //     isDeviceConnected = status == InternetConnectionStatus.connected;
    //   });
    // });
  }

  bool _memproses = false;

  Future<void> _masuk() async {
    if (_memproses) return;
    setState(() => _memproses = true);
    try {
      await _login();
    } finally {
      if (mounted) setState(() => _memproses = false);
    }
  }

  // Tampilan baru 2026-11-15 (navy, kartu putih, teks netral). Logika login tidak berubah.
  @override
  Widget build(BuildContext context) {
    final atas = MediaQuery.of(context).padding.top;
    return WillPopScope(
      onWillPop: () async {
        SystemNavigator.pop();
        return false;
      },
      child: Scaffold(
        backgroundColor: Warna.latar,
        resizeToAvoidBottomInset: true,
        body: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(children: [
            Container(
              width: double.infinity,
              color: Warna.navy,
              padding: EdgeInsets.fromLTRB(24, atas + 36, 24, 90),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                  child: Image.asset('Assets/horilla-logo.png', height: 64, width: 64, fit: BoxFit.contain),
                ),
                const SizedBox(height: 16),
                const Text('StarFoto HR', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Absensi, cuti, dan lembur dalam satu aplikasi',
                    style: TextStyle(color: Colors.white.withOpacity(.75), fontSize: 12.5)),
              ]),
            ),
            Transform.translate(
              offset: const Offset(0, -56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Kartu(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Text('Masuk', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text('Gunakan email dan kata sandi akun HR Anda.', style: Teks.kecil),
                    const SizedBox(height: 18),
                    _buildTextFormField('Email', usernameController, false),
                    const SizedBox(height: 14),
                    _buildTextFormField('Kata sandi', passwordController, true, _passwordVisible,
                        () => setState(() => _passwordVisible = !_passwordVisible)),
                    const SizedBox(height: 20),
                    TombolUtama('Masuk', ikon: Icons.login_rounded, proses: _memproses, onPressed: _masuk),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: _showForgotPassword,
                      child: const Text('Lupa kata sandi?', style: TextStyle(color: Warna.ink2, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildTextFormField(
    String label,
    TextEditingController controller,
    bool isPassword, [
    bool? passwordVisible,
    VoidCallback? togglePasswordVisibility,
  ]) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Warna.ink2)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        obscureText: isPassword ? !(passwordVisible ?? false) : false,
        keyboardType: isPassword ? TextInputType.visiblePassword : TextInputType.emailAddress,
        textInputAction: isPassword ? TextInputAction.done : TextInputAction.next,
        onFieldSubmitted: isPassword ? (_) => _masuk() : null,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          prefixIcon: Icon(isPassword ? Icons.lock_outline_rounded : Icons.mail_outline_rounded, color: Warna.muted, size: 20),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Warna.garis)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Warna.navy)),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(passwordVisible! ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Warna.muted),
                  onPressed: togglePasswordVisibility,
                )
              : null,
        ),
      ),
    ]);
  }

  @override
  void dispose() {
    subscription.cancel();
    super.dispose();
  }
}
