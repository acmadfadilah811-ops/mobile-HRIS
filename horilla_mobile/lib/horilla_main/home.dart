import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animated_notch_bottom_bar/animated_notch_bottom_bar/animated_notch_bottom_bar.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:geocoding/geocoding.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../checkin_checkout/checkin_checkout_views/geofencing.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late StreamSubscription subscription;
  var isDeviceConnected = false;
  final ScrollController _scrollController = ScrollController();
  final _pageController = PageController(initialPage: 0);
  final _controller = NotchBottomBarController(index: 0);
  late Map<String, dynamic> arguments = {};
  bool permissionCheck = false;
  bool isLoading = true;
  bool isFirstFetch = true;
  bool isAlertSet = false;
  bool permissionLeaveOverviewCheck = false;
  bool permissionLeaveTypeCheck = false;
  bool permissionGeoFencingMapViewCheck = false;
  bool geoFencingEnabled = false;
  bool permissionWardCheck = false;
  bool permissionLeaveAssignCheck = false;
  bool permissionLeaveRequestCheck = false;
  bool permissionMyLeaveRequestCheck = false;
  bool permissionLeaveAllocationCheck = false;
  int initialTabIndex = 0;
  int notificationsCount = 0;
  int maxCount = 5;
  String? duration;
  List<Map<String, dynamic>> notifications = [];
  Timer? _notificationTimer;
  Set<int> seenNotificationIds = {};
  int currentPage = 0;
  List<dynamic> responseDataLocation = [];
  final List<LocationWithRadius> locations = [];
  LocationWithRadius? selectedLocation;
  late final AnimatedMapController _mapController;
  bool _isPermissionLoading = true;
  bool isAuthenticated = true;


  @override
  void initState() {
    super.initState();
    _mapController = AnimatedMapController(vsync: this);
    _scrollController.addListener(_scrollListener);
    _initializePermissionsAndData();
  }


  Future _initializePermissionsAndData() async {
    await checkAllPermissions();
    await Future.wait([
      permissionGeoFencingMapView(),
      loadGeoFencingPreference(),
      permissionLeaveOverviewChecks(),
      permissionLeaveTypeChecks(),
      permissionLeaveRequestChecks(),
      permissionLeaveAssignChecks(),
      permissionWardChecks(),
      fetchNotifications(),
      unreadNotificationsCount(),
      prefetchData(),
      fetchData(),
    ]);
    setState(() {
      _isPermissionLoading = false;
      isLoading = false;
    });
  }


  Future<void> loadGeoFencingPreference() async {
    final prefs = await SharedPreferences.getInstance();
    bool? geoFencing = prefs.getBool("geo_fencing");
    setState(() {
      geoFencingEnabled = geoFencing ?? false;
    });
  }

  Future<void> permissionLeaveOverviewChecks() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/leave/check-perm/');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    setState(() {
      if (response.statusCode == 200) {
        permissionLeaveOverviewCheck = true;
        permissionMyLeaveRequestCheck = true;
        permissionLeaveAllocationCheck = true;
      } else {
        permissionMyLeaveRequestCheck = true;
        permissionLeaveAllocationCheck = true;
      }
    });
  }

  Future<void> permissionLeaveTypeChecks() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/leave/check-type/');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    setState(() {
      if (response.statusCode == 200) {
        permissionLeaveTypeCheck = true;
        permissionMyLeaveRequestCheck = true;
        permissionLeaveAllocationCheck = true;
      } else {
        permissionMyLeaveRequestCheck = true;
        permissionLeaveAllocationCheck = true;
      }
    });
  }

  Future<void> permissionGeoFencingMapView() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/geofencing/setup-check/');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    setState(() {
      permissionGeoFencingMapViewCheck = response.statusCode == 200;
    });
  }

  Future<void> permissionLeaveRequestChecks() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/leave/check-request/');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    setState(() {
      if (response.statusCode == 200) {
        permissionLeaveRequestCheck = true;
        permissionMyLeaveRequestCheck = true;
        permissionLeaveAllocationCheck = true;
      } else {
        permissionMyLeaveRequestCheck = true;
        permissionLeaveAllocationCheck = true;
      }
    });
  }

  Future<void> permissionLeaveAssignChecks() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/leave/check-assign/');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    setState(() {
      if (response.statusCode == 200) {
        permissionLeaveAssignCheck = true;
        permissionMyLeaveRequestCheck = true;
        permissionLeaveAllocationCheck = true;
      } else {
        permissionMyLeaveRequestCheck = true;
        permissionLeaveAllocationCheck = true;
      }
    });
  }

  void getConnectivity() {
    subscription = InternetConnectionChecker().onStatusChange.listen((status) {
      setState(() {
        isDeviceConnected = status == InternetConnectionStatus.connected;
        if (!isDeviceConnected && !isAlertSet) {
          showSnackBar();
          isAlertSet = true;
        } else if (isDeviceConnected && isAlertSet) {
          isAlertSet = false;
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
      });
    });
  }

  final List<Widget> bottomBarPages = [
    const Home(),
    const Overview(),
    const User(),
  ];

  void _scrollListener() {
    if (_scrollController.offset >=
        _scrollController.position.maxScrollExtent &&
        !_scrollController.position.outOfRange) {
      currentPage++;
      fetchNotifications();
    }
  }

  Future<void> fetchData() async {
    await permissionWardChecks();
    setState(() {});
  }

  void permissionChecks() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri =
    Uri.parse('$typedServerUrl/api/attendance/permission-check/attendance');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    setState(() {
      permissionCheck = response.statusCode == 200;
    });
  }

  Future<void> permissionWardChecks() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/ward/check-ward/');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    setState(() {
      permissionWardCheck = response.statusCode == 200;
    });
  }

  Future<void> prefetchData() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var employeeId = prefs.getInt("employee_id");
    var uri = Uri.parse('$typedServerUrl/api/employee/employees/$employeeId');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      setState(() {
        arguments = {
          'employee_id': responseData['id'] ?? '',
          'employee_name': (responseData['employee_first_name'] ?? '') +
              ' ' +
              (responseData['employee_last_name'] ?? ''),
          'badge_id': responseData['badge_id'] ?? '',
          'email': responseData['email'] ?? '',
          'phone': responseData['phone'] ?? '',
          'date_of_birth': responseData['dob'] ?? '',
          'gender': responseData['gender'] ?? '',
          'address': responseData['address'] ?? '',
          'country': responseData['country'] ?? '',
          'state': responseData['state'] ?? '',
          'city': responseData['city'] ?? '',
          'qualification': responseData['qualification'] ?? '',
          'experience': responseData['experience'] ?? '',
          'marital_status': responseData['marital_status'] ?? '',
          'children': responseData['children'] ?? '',
          'emergency_contact': responseData['emergency_contact'] ?? '',
          'emergency_contact_name': responseData['emergency_contact_name'] ?? '',
          'employee_work_info_id': responseData['employee_work_info_id'] ?? '',
          'employee_bank_details_id':
          responseData['employee_bank_details_id'] ?? '',
          'employee_profile': responseData['employee_profile'] ?? '',
          'job_position_name': responseData['job_position_name'] ?? ''
        };
      });
    }
  }

  Future<void> fetchNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");

    List<Map<String, dynamic>> allNotifications = [];
    int page = 1;
    bool hasMore = true;

    while (hasMore) {
      var uri = Uri.parse(
          '$typedServerUrl/api/notifications/notifications/list/unread?page=$page');

      var response = await http.get(uri, headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      });

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);
        var results = responseData['results'] as List;

        if (results.isEmpty) break;

        // Filter out deleted notifications
        List<Map<String, dynamic>> fetched = results
            .where((n) => n['deleted'] == false)
            .cast<Map<String, dynamic>>()
            .toList();

        allNotifications.addAll(fetched);

        // Check if there's a next page
        if (responseData['next'] == null) {
          hasMore = false;
        } else {
          page++;
        }
      } else {
        print('Failed to fetch notifications: ${response.statusCode}');
        hasMore = false;
      }
    }

    // Deduplicate notifications by converting to JSON strings
    Set<String> uniqueMapStrings = allNotifications
        .map((notification) => jsonEncode(notification))
        .toSet();

    setState(() {
      notifications = uniqueMapStrings
          .map((jsonString) => jsonDecode(jsonString))
          .cast<Map<String, dynamic>>()
          .toList();
      notificationsCount = notifications.length;
      isLoading = false;
    });
  }

  Future<void> unreadNotificationsCount() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse(
        '$typedServerUrl/api/notifications/notifications/list/unread');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });

    if (response.statusCode == 200) {
      setState(() {
        notificationsCount = jsonDecode(response.body)['count'];
        isLoading = false;
      });
    }
  }

  Future<void> markReadNotification(int notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse(
        '$typedServerUrl/api/notifications/notifications/$notificationId/');
    var response = await http.post(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      setState(() {
        notifications.removeWhere((item) => item['id'] == notificationId);
        unreadNotificationsCount();
        fetchNotifications();
      });
    }
  }

  Future<void> markAllReadNotification() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri =
    Uri.parse('$typedServerUrl/api/notifications/notifications/bulk-read/');
    var response = await http.post(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      setState(() {
        notifications.clear();
        unreadNotificationsCount();
        fetchNotifications();
      });
    }
  }

  Future checkAllPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");

    Future<bool> _getPerm(String endpoint) async {
      try {
        var uri = Uri.parse('$typedServerUrl$endpoint');
        var res = await http.get(uri, headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        });
        return res.statusCode == 200;
      } catch (e) {
        print("Permission check failed for $endpoint: $e");
        return false;
      }
    }

    bool overview = await _getPerm("/api/attendance/permission-check/attendance");
    bool att = true;
    bool attReq = true;
    bool hourAcc = true;



    await prefs.setBool("perm_overview", overview);
    await prefs.setBool("perm_attendance", att);
    await prefs.setBool("perm_attendance_request", attReq);
    await prefs.setBool("perm_hour_account", hourAcc);

    print("✅ Permissions saved in SharedPreferences");
  }

  Future<void> clearAllUnreadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse(
        '$typedServerUrl/api/notifications/notifications/bulk-delete-unread/');
    var response = await http.delete(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      setState(() {
        notifications.clear();
        unreadNotificationsCount();
        fetchNotifications();
      });
    }
  }

  /// Cek ke backend HR (yang meneruskan ke Bintang lewat jembatan server-
  /// ke-server -- token jembatan TIDAK pernah ada di app mobile ini) apakah
  /// karyawan masih tercatat "Mulai Kerja" (belum "Selesai Kerja") hari ini
  /// di Bintang. Dipanggil sebelum Logout supaya karyawan diingatkan --
  /// GAGAL memanggil (offline, server error, dsb) TIDAK BOLEH menghalangi
  /// Logout, jadi selalu dianggap "tidak perlu peringatan" kalau error.
  Future<bool> _bintangSesiKerjaMasihTerbuka() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      final typedServerUrl = prefs.getString("typed_url");
      if (token == null || typedServerUrl == null) return false;

      final uri = Uri.parse('$typedServerUrl/api/attendance/bintang-status/');
      final response = await http
          .get(uri, headers: {"Authorization": "Bearer $token"})
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return false;

      final data = jsonDecode(response.body);
      if (data['applicable'] != true) return false;
      return data['has_open_session'] == true;
    } catch (e) {
      print('Cek status sesi kerja Bintang gagal (diabaikan): $e');
      return false;
    }
  }

  Future<bool> _konfirmasiSesiKerjaBintangBelumDitutup(
      BuildContext context) async {
    final hasil = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sesi Kerja Bintang Belum Ditutup',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const Text(
            'Anda tercatat masih "Mulai Kerja" di sistem Bintang hari ini dan '
            'belum menekan "Selesai Kerja". Disarankan menutup sesi kerja '
            'Anda di Bintang dulu supaya jam kerja tercatat dengan benar '
            'sebelum keluar dari aplikasi ini.',
            style: TextStyle(fontSize: 13.5, height: 1.4),
          ),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal',
                  style: TextStyle(color: Colors.black54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Tetap Keluar',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
    return hasil ?? false;
  }

  Future<void> clearToken(BuildContext context) async {
    final sesiMasihTerbuka = await _bintangSesiKerjaMasihTerbuka();
    if (sesiMasihTerbuka) {
      final tetapKeluar =
          await _konfirmasiSesiKerjaBintangBelumDitutup(context);
      if (!tetapKeluar) return;
    }

    final prefs = await SharedPreferences.getInstance();
    String? typedServerUrl = prefs.getString("typed_url");
    await prefs.remove('token');
    isAuthenticated = false;
    _notificationTimer?.cancel();
    _notificationTimer = null;

    Navigator.pushNamed(context, '/login', arguments: typedServerUrl);
  }

  Future<void> enableFaceDetection() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/facedetection/config/');
    var response = await http.put(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        'start': true,
      }),
    );
    print('Face Detection Enable Response: ${response.statusCode}');
    print(response.body);
  }

  Future<void> disableFaceDetection() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/facedetection/config/');
    var response = await http.put(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        'start': false,
      }),
    );
    print('Face Detection Disable Response: ${response.statusCode}');
  }

  Future<bool> getFaceDetection() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/facedetection/config/');
    var response = await http.get(uri, headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    });
    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      bool isEnabled = data['start'] ?? false;
      return isEnabled;
    } else {
      print('Failed to get face detection');
      return false;
    }
  }


  Future<bool?> getGeoFence() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/geofencing/setup/');

    try {
      var response = await http.get(uri, headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      });

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        var data = jsonDecode(response.body);
        bool isEnabled = data['start'] ?? false;
        return isEnabled;
      }
      else if (response.statusCode == 404) {
        print('Geofencing not configured yet');
        return null;
      }
      else {
        print('Failed to get geofencing: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error getting geofencing: $e');
      return false;
    }
  }


  Future<void> enableGeoFenceLocation() async {
    await getGeoFenceLocation();
    if (responseDataLocation.isEmpty) return;
    var locationId = responseDataLocation[0]['id'];
    final prefs = await SharedPreferences.getInstance();
    var companyId = prefs.getInt("company_id");
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/geofencing/setup/$locationId/');
    var response = await http.put(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        'latitude': selectedLocation?.coordinates.latitude,
        'longitude': selectedLocation?.coordinates.longitude,
        'radius_in_meters': selectedLocation?.radius,
        'start': true,
        'company_id': companyId
      }),
    );
    print('GeoFence Enable Response: ${response.statusCode}');
  }

  Future<void> disableGeoFenceLocation() async {
    await getGeoFenceLocation();
    if (responseDataLocation.isEmpty) return;

    var locationId = responseDataLocation[0]['id'];
    final prefs = await SharedPreferences.getInstance();
    var companyId = prefs.getInt("company_id");
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/geofencing/setup/$locationId/');
    var response = await http.put(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        'latitude': selectedLocation?.coordinates.latitude,
        'longitude': selectedLocation?.coordinates.longitude,
        'radius_in_meters': selectedLocation?.radius,
        'start': false,
        'company_id': companyId
      }),
    );
    print('GeoFence Disable Response: ${response.statusCode}');
  }

  Future<void> getGeoFenceLocation() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString("token");
    var typedServerUrl = prefs.getString("typed_url");
    var uri = Uri.parse('$typedServerUrl/api/geofencing/setup/');

    try {
      var response = await http.get(uri, headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.isNotEmpty) {
          final lat = data['latitude'];
          final lng = data['longitude'];
          final rad = data['radius_in_meters'];

          if (lat != null && lng != null && rad != null) {
            final locationName = await _getLocationName(lat, lng);
            final location = LocationWithRadius(
              LatLng(lat, lng),
              locationName,
              (rad).toDouble(),
            );

            setState(() {
              responseDataLocation = [data];
              locations.clear();
              locations.add(location);
              selectedLocation = location;
              _mapController.animateTo(dest: location.coordinates, zoom: 12.0);
            });
            print('responseDataLocation: $responseDataLocation');
          }
        }
      } else {
        print('Failed to load geofence data: ${response.statusCode}');
      }
    } catch (e) {
      print("Error fetching geofence data: $e");
    }
  }


  Future<String> _getLocationName(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks =
      await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String name = "${place.locality ?? ''}, ${place.country ?? ''}".trim();
        return name.isEmpty ? "Unknown Location" : name;
      }
      return "Unknown Location";
    } catch (e) {
      print('Error getting location name: $e');
      return "Unknown Location";
    }
  }

  Future<void> showSavedAnimation() async {
    String jsonContent = '''
{
  "imagePath": "Assets/gif22.gif"
}
''';
    Map<String, dynamic> jsonData = json.decode(jsonContent);
    String imagePath = jsonData['imagePath'];

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.3,
            width: MediaQuery.of(context).size.width * 0.85,
            child: SingleChildScrollView(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(imagePath,
                        width: 180, height: 180, fit: BoxFit.cover),
                    const SizedBox(height: 16),
                    const Text(
                      "Pengaturan Berhasil Disimpan",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.lightBlue),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    Future.delayed(const Duration(seconds: 3), () async {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(),
        ),
      );
    });
  }

  void _showUnreadNotifications(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Stack(
              children: [
                AlertDialog(
                  backgroundColor: Colors.white,
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Notifikasi",
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width * 0.05,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          Navigator.of(context).pop(true);
                        },
                      ),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            onPressed: () async {
                              await markAllReadNotification();
                              Navigator.pop(context);
                              _showUnreadNotifications(context);
                            },
                            icon: Icon(Icons.done_all,
                                color: Colors.lightBlue,
                                size:
                                MediaQuery.of(context).size.width * 0.0357),
                            label: Text(
                              'Tandai sudah dibaca',
                              style: TextStyle(
                                  color: Colors.lightBlue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: MediaQuery.of(context).size.width *
                                      0.0368),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              await clearAllUnreadNotifications();
                              Navigator.pop(context);
                              _showUnreadNotifications(context);
                            },
                            icon: Icon(Icons.clear,
                                color: Colors.lightBlue,
                                size:
                                MediaQuery.of(context).size.width * 0.0357),
                            label: Text(
                              'Hapus semua',
                              style: TextStyle(
                                  color: Colors.lightBlue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: MediaQuery.of(context).size.width *
                                      0.0368),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16.0),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.8,
                        height: MediaQuery.of(context).size.height * 0.3,
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.8,
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal:
                              MediaQuery.of(context).size.width * 0.0357),
                          child: Center(
                            child: isLoading
                                ? Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: ListView.builder(
                                itemCount: 3,
                                itemBuilder: (context, index) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8.0),
                                  child: Container(
                                    width: double.infinity,
                                    height: MediaQuery.of(context)
                                        .size
                                        .height *
                                        0.0616,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            )
                                : notifications.isEmpty
                                ? Center(
                              child: Column(
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.notifications,
                                    color: Colors.black,
                                    size: MediaQuery.of(context)
                                        .size
                                        .width *
                                        0.2054,
                                  ),
                                  SizedBox(
                                      height: MediaQuery.of(context)
                                          .size
                                          .height *
                                          0.0205),
                                  Text(
                                    "Tidak ada catatan notifikasi untuk ditampilkan",
                                    style: TextStyle(
                                      fontSize: MediaQuery.of(context)
                                          .size
                                          .width *
                                          0.0268,
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            )
                                : Column(
                              children: [
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: notifications.length,
                                    itemBuilder: (context, index) {
                                      final record =
                                      notifications[index];
                                      return Padding(
                                        padding:
                                        const EdgeInsets.all(4.0),
                                        child: Column(
                                          children: [
                                            if (record['verb'] !=
                                                null)
                                              buildListItem(context,
                                                  record, index),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                  actions: <Widget>[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/notifications_list');
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                              horizontal:
                              MediaQuery.of(context).size.width * 0.0134,
                              vertical:
                              MediaQuery.of(context).size.width * 0.0134),
                          backgroundColor: Colors.lightBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Lihat semua notifikasi',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize:
                              MediaQuery.of(context).size.width * 0.0335),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget buildListItem(
      BuildContext context, Map<String, dynamic> record, int index) {
    final timestamp = DateTime.parse(record['timestamp']);
    final timeAgo = timeago.format(timestamp);
    final user = arguments['employee_name'];
    return Padding(
      padding: const EdgeInsets.all(0),
      child: GestureDetector(
        onTap: () async {
          setState(() {});
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.lightBlue.shade100),
            borderRadius: BorderRadius.circular(8.0),
            color: Colors.lightBlue.shade100,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
                vertical: MediaQuery.of(context).size.height * 0.0082),
            child: Container(
              color: Colors.lightBlue.shade100,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, top: 6.0),
                    child: Container(
                      margin: EdgeInsets.only(
                          right: MediaQuery.of(context).size.width * 0.0357),
                      width: MediaQuery.of(context).size.width * 0.0223,
                      height: MediaQuery.of(context).size.width * 0.0223,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.lightBlue.shade500,
                        border: Border.all(
                            color: Colors.grey,
                            width: MediaQuery.of(context).size.width * 0.0022),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record['verb'],
                          style: TextStyle(
                              fontSize:
                              MediaQuery.of(context).size.width * 0.0313,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          '$timeAgo oleh Pengguna $user',
                          style: TextStyle(
                              fontSize:
                              MediaQuery.of(context).size.width * 0.0268),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: GestureDetector(
                      onTap: () async {
                        var notificationId = record['id'];
                        await markReadNotification(notificationId);
                        Navigator.pop(context);
                        _showUnreadNotifications(context);
                      },
                      child: Icon(
                        Icons.check,
                        color: Colors.lightBlue.shade500,
                        size: 20.0,
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        forceMaterialTransparency: true,
        backgroundColor: Colors.white,
        title: const Text(
          'Modul',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        automaticallyImplyLeading: false,
        actions: [
          if (_isPermissionLoading)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else ...[
            Visibility(
              visible: permissionGeoFencingMapViewCheck,
              child: IconButton(
                icon: const Icon(
                  Icons.settings,
                  color: Colors.black,
                ),
                onPressed: () async {
                  var faceDetection = await getFaceDetection();
                  var geoFencingResponse = await getGeoFence();
                  final prefs = await SharedPreferences.getInstance();

                  bool geoFencingSetupExists = geoFencingResponse != null;
                  bool geoFencingEnabled = geoFencingSetupExists ? geoFencingResponse : false;

                  prefs.remove('face_detection');
                  prefs.setBool("face_detection", faceDetection);
                  prefs.remove('geo_fencing');
                  prefs.setBool("geo_fencing", geoFencingEnabled);

                  showDialog(
                    context: context,
                    builder: (context) {
                      bool tempFaceDetection = faceDetection;
                      bool tempGeofencing = geoFencingEnabled;
                      bool isGeofencingSetup = geoFencingSetupExists;

                      return StatefulBuilder(
                        builder: (context, setState) {
                          return AlertDialog(
                            title: const Text('Pengaturan'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SwitchListTile(
                                  title: const Text('Deteksi Wajah'),
                                  value: tempFaceDetection,
                                  onChanged: (val) {
                                    setState(() {
                                      tempFaceDetection = val;
                                    });
                                    // Immediately apply face detection changes
                                    if (val) {
                                      enableFaceDetection();
                                    } else {
                                      disableFaceDetection();
                                    }
                                  },
                                ),
                                SwitchListTile(
                                  title: const Text('Geofencing'),
                                  value: tempGeofencing,
                                  onChanged: (val) async {
                                    setState(() {
                                      tempGeofencing = val;
                                    });
                                    print('wswsws');
                                    print(isGeofencingSetup);

                                    if (!isGeofencingSetup && val) {
                                      Navigator.pop(context); // Close settings dialog
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const MapScreen(),
                                        ),
                                      );
                                      return;
                                    }

                                    if (val) {
                                      await enableGeoFenceLocation();
                                    } else {
                                      await disableGeoFenceLocation();
                                    }
                                  },
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Batal'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setBool("face_detection", tempFaceDetection);
                                  await prefs.setBool("geo_fencing", tempGeofencing);

                                  setState(() {
                                    geoFencingEnabled = tempGeofencing;
                                  });

                                  Navigator.pop(context);
                                  await showSavedAnimation();
                                },
                                child: const Text('OK'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            Visibility(
              visible: permissionGeoFencingMapViewCheck && geoFencingEnabled,
              child: IconButton(
                icon: const Icon(
                  Icons.location_on,
                  color: Colors.black,
                ),
                onPressed: () async {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MapScreen(),
                    ),
                  );
                },
              ),
            ),
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.notifications,
                    color: Colors.black,
                  ),
                  onPressed: () {
                    markAllReadNotification();
                    Navigator.pushNamed(context, '/notifications_list');
                    setState(() {
                      fetchNotifications();
                      unreadNotificationsCount();
                    });
                  },
                ),
                if (notificationsCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: MediaQuery.of(context).size.width * 0.012,
                        vertical: MediaQuery.of(context).size.width * 0.004,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.lightBlue,
                        shape: BoxShape.circle,
                      ),
                      constraints: BoxConstraints(
                        minWidth: MediaQuery.of(context).size.width * 0.032,
                        minHeight: MediaQuery.of(context).size.height * 0.016,
                      ),
                      child: Center(
                        child: Text(
                          '$notificationsCount',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: MediaQuery.of(context).size.width * 0.018,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            IconButton(
              icon: const Icon(
                Icons.logout,
                color: Colors.black,
              ),
              onPressed: () async {
                await clearToken(context);
              },
            )
          ],
        ],
      ),
      body: _isPermissionLoading
          ? Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ListView(
            children: [
              const SizedBox(height: 50.0),
              const SizedBox(height: 50.0),
              Card(
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    color: Colors.white,
                  ),
                  title: Container(
                    width: double.infinity,
                    height: 20,
                    color: Colors.white,
                  ),
                  subtitle: Container(
                    width: double.infinity,
                    height: 16,
                    color: Colors.white,
                  ),
                  trailing: Container(
                    width: 24,
                    height: 24,
                    color: Colors.white,
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    color: Colors.white,
                  ),
                  title: Container(
                    width: double.infinity,
                    height: 20,
                    color: Colors.white,
                  ),
                  subtitle: Container(
                    width: double.infinity,
                    height: 16,
                    color: Colors.white,
                  ),
                  trailing: Container(
                    width: 24,
                    height: 24,
                    color: Colors.white,
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    color: Colors.white,
                  ),
                  title: Container(
                    width: double.infinity,
                    height: 20,
                    color: Colors.white,
                  ),
                  subtitle: Container(
                    width: double.infinity,
                    height: 16,
                    color: Colors.white,
                  ),
                  trailing: Container(
                    width: 24,
                    height: 24,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView(
          children: [
            const SizedBox(height: 50.0),
            const SizedBox(height: 50.0),
            Card(
              child: ListTile(
                leading: const Icon(Icons.people),
                title: const Text('Karyawan'),
                subtitle: Text(
                  'Lihat dan kelola semua karyawan Anda.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                trailing: const Icon(Icons.keyboard_arrow_right),
                onTap: () {
                  Navigator.pushNamed(context, '/employees_list',
                      arguments: permissionCheck);
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.checklist_rtl),
                title: const Text('Kehadiran'),
                subtitle: Text(
                  'Catat dan lihat riwayat kehadiran karyawan.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                trailing: const Icon(Icons.keyboard_arrow_right),
                onTap: () {
                  if (permissionCheck) {
                    Navigator.pushNamed(context, '/attendance_overview',
                        arguments: permissionCheck);
                  } else {
                    Navigator.pushNamed(context, '/employee_hour_account',
                        arguments: permissionCheck);
                  }
                },
              ),
            ),
            Card(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (permissionLeaveOverviewCheck) {
                      Navigator.pushNamed(context, '/leave_overview');
                    } else {
                      Navigator.pushNamed(context, '/my_leave_request');
                    }
                  });
                },
                child: ListTile(
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: const Text('Cuti'),
                  subtitle: Text(
                    'Catat dan lihat informasi cuti',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  trailing: const Icon(Icons.keyboard_arrow_right),
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.more_time),
                title: const Text('Pengajuan Lembur'),
                subtitle: Text(
                  'Ajukan lembur & setujui lembur bawahan.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                trailing: const Icon(Icons.keyboard_arrow_right),
                onTap: () {
                  Navigator.pushNamed(context, '/overtime_request');
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.business_outlined),
                title: const Text('Dokumen Perusahaan'),
                subtitle: Text(
                  'SOP, Corporate Guideline, dan Peraturan Perusahaan.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                trailing: const Icon(Icons.keyboard_arrow_right),
                onTap: () {
                  Navigator.pushNamed(context, '/company_documents');
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.campaign_outlined),
                title: const Text('Pengumuman'),
                subtitle: Text(
                  'Info dan pengumuman dari perusahaan.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                trailing: const Icon(Icons.keyboard_arrow_right),
                onTap: () {
                  Navigator.pushNamed(context, '/announcements');
                },
              ),
            ),
          ],
        ),
      ),
      extendBody: true,
      bottomNavigationBar: (bottomBarPages.length <= maxCount)
          ? AnimatedNotchBottomBar(
        notchBottomBarController: _controller,
        color: Colors.lightBlue,
        showLabel: true,
        notchColor: Colors.lightBlue,
        kBottomRadius: 28.0,
        kIconSize: 24.0,
        removeMargins: false,
        bottomBarWidth: MediaQuery.of(context).size.width * 1,
        durationInMilliSeconds: 500,
        bottomBarItems: const [
          BottomBarItem(
            inActiveItem: Icon(
              Icons.home_filled,
              color: Colors.white,
            ),
            activeItem: Icon(
              Icons.home_filled,
              color: Colors.white,
            ),
          ),
          BottomBarItem(
            inActiveItem: Icon(
              Icons.update_outlined,
              color: Colors.white,
            ),
            activeItem: Icon(
              Icons.update_outlined,
              color: Colors.white,
            ),
          ),
          BottomBarItem(
            inActiveItem: Icon(
              Icons.person,
              color: Colors.white,
            ),
            activeItem: Icon(
              Icons.person,
              color: Colors.white,
            ),
          ),
        ],
        onTap: (index) async {
          switch (index) {
            case 0:
              Future.delayed(const Duration(milliseconds: 1000), () {
                Navigator.pushNamed(context, '/home');
              });
              break;
            case 1:
              Future.delayed(const Duration(milliseconds: 1000), () {
                Navigator.pushNamed(context, '/employee_checkin_checkout');
              });
              break;
            case 2:
              Future.delayed(const Duration(milliseconds: 1000), () {
                Navigator.pushNamed(context, '/employees_form',
                    arguments: arguments);
              });
              break;
          }
        },
      )
          : null,
    );
  }

  void showSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.lightBlue,
        content: const Text('Silakan periksa koneksi internet Anda',
            style: TextStyle(color: Colors.white)),
        action: SnackBarAction(
          backgroundColor: Colors.lightBlue,
          label: 'Tutup',
          textColor: Colors.white,
          onPressed: () async {
            setState(() => isAlertSet = false);
            isDeviceConnected = await InternetConnectionChecker().hasConnection;
            if (!isDeviceConnected && !isAlertSet) {
              showSnackBar();
              setState(() => isAlertSet = true);
            }
          },
        ),
        duration: const Duration(hours: 1),
      ),
    );
  }
}

class Home extends StatelessWidget {
  const Home({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushNamed(context, '/home');
    });
    return Container(
      color: Colors.white,
      child: const Center(child: Text('Page 1')),
    );
  }
}

class Overview extends StatelessWidget {
  const Overview({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
        color: Colors.white, child: const Center(child: Text('Page 2')));
  }
}

class User extends StatelessWidget {
  const User({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushNamed(context, '/user');
    });
    return Container(
      color: Colors.white,
      child: const Center(child: Text('Page 1')),
    );
  }
}
