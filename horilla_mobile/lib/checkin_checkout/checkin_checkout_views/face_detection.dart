import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../ui/tema.dart';
import 'package:horilla/checkin_checkout/checkin_checkout_views/setup_imageface.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../controllers/face_detection_controller.dart';

class FaceScanner extends StatefulWidget {
  final Map userDetails;
  final String? attendanceState;
  final Position? userLocation;

  const FaceScanner({
    Key? key,
    required this.userDetails,
    required this.attendanceState,
    required this.userLocation,
  }) : super(key: key);

  @override
  _FaceScannerState createState() => _FaceScannerState();
}

class _FaceScannerState extends State<FaceScanner> with SingleTickerProviderStateMixin {
  late FaceScannerController _controller;
  bool _isCameraInitialized = false;
  bool _isComparing = false;
  String? _employeeImageBase64;
  bool _isDetectionPaused = false;
  bool _isFetchingImage = false;

  late AnimationController _animationController;
  late Animation _rotationAnimation;
  late Animation _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = FaceScannerController();
    _setupAnimations();
    _initializeApp();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _rotationAnimation = Tween(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );
    _scaleAnimation = Tween(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat();
  }

  Future<void> _initializeApp() async {
    try {
      await _fetchBiometricImage();
      if (_employeeImageBase64 != null && mounted) {
        await _initializeCamera();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal inisialisasi: $e')),
        );
      }
    }
  }

  Future<void> _initializeCamera() async {
    try {
      await _controller.initializeCamera();
      if (!mounted) return;

      setState(() => _isCameraInitialized = true);
      _startRealTimeFaceDetection();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal inisialisasi kamera: $e')),
        );
      }
    }
  }

  Future<void> _fetchBiometricImage() async {
    if (_isFetchingImage) return;
    setState(() => _isFetchingImage = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");
    final typedServerUrl = prefs.getString("typed_url");
    // Foto wajah acuan disimpan di server dan dikirim saat login ('face_detection_image').
    // Jangan bergantung pada penanda lokal (mis. 'imagePath'): hilang setelah logout/ganti HP,
    // padahal foto sudah ada di server, sehingga karyawan dipaksa upload ulang.
    final faceDetectionImage = prefs.getString("face_detection_image");

    if (token == null || typedServerUrl == null || faceDetectionImage == null || faceDetectionImage.isEmpty) {
      if (mounted) showImageAlertDialog(context);
      return;
    }

    try {
      // --- Build image URL ---
      final cleanedServerUrl = typedServerUrl.endsWith('/')
          ? typedServerUrl.substring(0, typedServerUrl.length - 1)
          : typedServerUrl;

      final cleanedPath = faceDetectionImage.startsWith('/')
          ? faceDetectionImage.substring(1)
          : faceDetectionImage;
      final imageUrl = '$cleanedServerUrl/$cleanedPath';

      debugPrint("🔎 Fetching biometric image: $imageUrl");

      // --- Correct usage of HttpClient + IOClient ---
      final httpClient = HttpClient();
      httpClient.badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
      httpClient.autoUncompress = false;

      final ioClient = IOClient(httpClient);

      final response = await ioClient.get(
        Uri.parse(imageUrl),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "image/*",
          "Accept-Encoding": "identity",
          "User-Agent": "FlutterApp/1.0",
          "Connection": "keep-alive",
        },
      );

      print('cfcfccf');

      debugPrint("📥 Status: ${response.statusCode}");
      debugPrint("📥 Headers: ${response.headers}");

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        setState(() {
          _employeeImageBase64 = base64Encode(response.bodyBytes);
        });
        debugPrint("✅ Image downloaded: ${response.bodyBytes.length} bytes");
      } else {
        debugPrint("❌ Invalid response or empty image data");
        if (mounted) showImageAlertDialog(context);
      }

      ioClient.close();
    } catch (e) {
      debugPrint("⚠️ Error fetching biometric image: $e");
      if (mounted) showImageAlertDialog(context);
    } finally {
      if (mounted) setState(() => _isFetchingImage = false);
    }
  }

  void showImageAlertDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Foto Karyawan Belum Diatur"),
        content: const Text("Atur Foto Wajah Baru?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Tidak"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final cameras = await availableCameras();
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CameraSetupPage(cameras: cameras)),
                );
              }
            },
            child: const Text("Ya"),
          ),
        ],
      ),
    );
  }

  Future<void> _startRealTimeFaceDetection() async {
    while (_isCameraInitialized && !_isDetectionPaused && mounted) {
      try {
        await Future.delayed(const Duration(milliseconds: 500)); // Increased delay

        if (!mounted || !_controller.cameraController.value.isInitialized) break;

        setState(() => _isComparing = true);
        final image = await _controller.captureImage();

        if (image == null || _employeeImageBase64 == null) {
          debugPrint('Image capture failed or no employee image');
          continue;
        }

        debugPrint('Starting face comparison...');
        final isMatched = await _controller.compareFaces(File(image.path), _employeeImageBase64!);
        debugPrint('Face comparison result: $isMatched');

        if (isMatched) {
          await _handleComparisonResult(true);
          break;
        } else {
          setState(() => _isDetectionPaused = true);
          await _showIncorrectFaceAlert();
          setState(() => _isDetectionPaused = false);
        }
      } catch (e) {
        debugPrint('Face detection error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kesalahan deteksi wajah. Silakan coba lagi.')),
          );
        }
      } finally {
        if (mounted) setState(() => _isComparing = false);
      }
    }
  }

  Future<void> _showIncorrectFaceAlert() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Wajah tidak cocok", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        content: const Text("Pastikan wajah terlihat jelas, cukup cahaya, dan tanpa masker, lalu coba lagi."),
        actions: [
          // 2026-11-15: dulu kembali ke layar absen lama; sekarang pilih coba lagi di sini atau batal.
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Batal", style: TextStyle(color: Warna.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Coba lagi", style: TextStyle(color: Warna.ink, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleComparisonResult(bool isMatched) async {
    if (!isMatched || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");
    final typedServerUrl = prefs.getString("typed_url");
    final geoFencing = prefs.getBool("geo_fencing") ?? false;

    if (geoFencing && widget.userLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lokasi tidak tersedia. Tidak dapat melanjutkan.')),
      );
      return;
    }

    try {
      final endpoint = widget.attendanceState == 'NOT_CHECKED_IN'
          ? 'api/attendance/clock-in/'
          : 'api/attendance/clock-out/';

      final uri = Uri.parse('$typedServerUrl/$endpoint');
      final headers = {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      };

      final body = geoFencing
          ? jsonEncode({
        "latitude": widget.userLocation!.latitude,
        "longitude": widget.userLocation!.longitude,
      })
          : jsonEncode({});

      final response = await http.post(uri, headers: headers, body: body);

      if (response.statusCode == 200 && mounted) {
        Navigator.pop(context, {
          if (widget.attendanceState == 'NOT_CHECKED_IN') 'checkedIn': true,
          if (widget.attendanceState == 'CHECKED_IN') 'checkedOut': true,
        });
      } else if (mounted) {
        final errorMessage = getErrorMessage(response.body);
        showCheckInFailedDialog(context, errorMessage);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kesalahan jaringan: $e')),
        );
      }
    }
  }

  String getErrorMessage(String responseBody) {
    try {
      final Map decoded = json.decode(responseBody);
      return decoded['message'] ?? 'Terjadi kesalahan tidak diketahui';
    } catch (e) {
      return 'Gagal memproses respon server';
    }
  }

  void showCheckInFailedDialog(BuildContext context, String errorMessage) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Check-in Gagal'),
        content: Text(errorMessage),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _isDetectionPaused = true;
    if (_controller.cameraController.value.isInitialized) {
      _controller.cameraController.dispose();
    }
    super.dispose();
  }

  // Tampilan baru 2026-11-15: latar navy, bingkai oval, keterangan status. Logika deteksi tidak berubah.
  @override
  Widget build(BuildContext context) {
    final lebar = MediaQuery.of(context).size.width;
    final siap = _isCameraInitialized && _controller.cameraController.value.isInitialized;
    final keterangan = _isFetchingImage
        ? 'Menyiapkan foto acuan...'
        : !siap
            ? 'Menyalakan kamera...'
            : _isComparing
                ? 'Mencocokkan wajah...'
                : 'Arahkan wajah ke dalam bingkai';
    return Scaffold(
      backgroundColor: Warna.navy,
      appBar: AppBar(
        backgroundColor: Warna.navy,
        foregroundColor: Colors.white,
        title: Text(widget.attendanceState == 'NOT_CHECKED_IN' ? 'Pindai wajah - absen masuk' : 'Pindai wajah - absen pulang',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: Column(children: [
          const SizedBox(height: 24),
          Center(
            child: AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) => Transform.scale(scale: _isComparing ? (0.97 + 0.03 * _scaleAnimation.value) : 1.0, child: child),
              child: Container(
                width: lebar * 0.72,
                height: lebar * 0.92,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.elliptical(lebar * 0.36, lebar * 0.46)),
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.all(Radius.elliptical(lebar * 0.36, lebar * 0.46)),
                  child: siap
                      ? FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _controller.cameraController.value.previewSize?.height ?? lebar,
                            height: _controller.cameraController.value.previewSize?.width ?? lebar,
                            child: CameraPreview(_controller.cameraController),
                          ),
                        )
                      : const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (_isComparing || !siap)
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Warna.ink2))
              else
                const Icon(Icons.center_focus_strong_rounded, size: 16, color: Warna.ink2),
              const SizedBox(width: 8),
              Text(keterangan, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Warna.ink)),
            ]),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
            child: Text(
              'Wajah dicocokkan dengan foto acuan di HR. Absen terkirim otomatis begitu cocok.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(.7), fontSize: 12),
            ),
          ),
        ]),
      ),
    );
  }
}
