import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
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
    _notificationTimer = Timer.periodic(Duration(seconds: 3), (timer) {
      if (isAuthenticated) {
        fetchNotifications();
        unreadNotificationsCount();
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
              backgroundColor: Colors.lightBlue,
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        SystemNavigator.pop();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.42,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.0),
                  color: Colors.lightBlue,
                ),
                alignment: Alignment.bottomCenter,
                child: Center(
                  child: ClipOval(
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(10, 5, 10, 15),
                      child: Image.asset(
                        'Assets/horilla-logo.png',
                        height: MediaQuery.of(context).size.height * 0.11,
                        width: MediaQuery.of(context).size.height * 0.11,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              physics: ClampingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).size.height * 0.3,
                  left: horizontalMargin,
                  right: horizontalMargin,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10.0),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(20.0),
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: <Widget>[
                          const Text(
                            'Masuk',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                          _buildTextFormField(
                            'Email',
                            usernameController,
                            false,
                          ),
                          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                          _buildTextFormField(
                            'Kata Sandi',
                            passwordController,
                            true,
                            _passwordVisible,
                                () {
                              setState(() {
                                _passwordVisible = !_passwordVisible;
                              });
                            },
                          ),
                          SizedBox(height: MediaQuery.of(context).size.height * 0.04),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _login,
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.lightBlue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 10.0),
                                child: Text(
                                  'Masuk',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: _showForgotPassword,
                            child: const Text(
                              'Lupa kata sandi?',
                              style: TextStyle(color: Colors.lightBlue),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                  ],
                ),
              ),
            ),
          ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: MediaQuery.of(context).size.height * 0.005),
        TextFormField(
          controller: controller,
          obscureText: isPassword ? !(passwordVisible ?? false) : false,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderSide: const BorderSide(width: 1),
              borderRadius: BorderRadius.circular(8.0),
            ),
            contentPadding: EdgeInsets.symmetric(
              vertical: MediaQuery.of(context).size.height * 0.015,
              horizontal: controller.text.isNotEmpty ? 16.0 : 12.0,
            ),
            suffixIcon: isPassword
                ? IconButton(
              icon: Icon(
                passwordVisible! ? Icons.visibility : Icons.visibility_off,
                color: Colors.grey,
              ),
              onPressed: togglePasswordVisibility,
            )
                : null,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    subscription.cancel();
    super.dispose();
  }
}
