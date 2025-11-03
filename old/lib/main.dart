import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 세로 모드 고정
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 알림 서비스 초기화
  await NotificationService.instance.initialize();

  // 백그라운드 서비스 초기화
  await initializeService();

  runApp(const SafeDriveApp());
}

/// 백그라운드 서비스 설정
Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'safedrive_channel',
    'SafeDrive Background',
    description: '운전 중 안전 상태 감시 서비스',
    importance: Importance.low,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false, // (수정) true에서 false로 변경
      isForegroundMode: true,
      notificationChannelId: 'safedrive_channel',
      initialNotificationTitle: 'SafeDrive AI 실행 중',
      initialNotificationContent: '운전 상태를 감시하고 있습니다.',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(),
  );

  // (수정) 여기서 startService()를 호출하지 않음. 사용자가 버튼을 눌러 시작.
  // await service.startService();
}

/// 실제 백그라운드 동작
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    service.on('stopService').listen((event) {
      service.stopSelf(); // "stopService" 메시지를 받으면 서비스 중지
    });
  }

  // (수정) 5초마다 로그 출력하는 Timer.periodic 제거
  // 이 서비스는 이제 알림을 표시하고, 'stopService' 신호를 기다리는 역할만 함.
  debugPrint("✅ SafeDrive Background Service Initialized (onStart).");
}

class SafeDriveApp extends StatelessWidget {
  const SafeDriveApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeDrive AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        cardTheme: const CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
      ),
      home: const PermissionScreen(),
    );
  }
}

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({Key? key}) : super(key: key);

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  bool _isChecking = true;
  bool _allPermissionsGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final cameraStatus = await Permission.camera.status;
    final notificationStatus = await Permission.notification.status;

    if (cameraStatus.isGranted && notificationStatus.isGranted) {
      setState(() {
        _allPermissionsGranted = true;
        _isChecking = false;
      });
      _navigateToHome();
    } else {
      setState(() {
        _isChecking = false;
      });
    }
  }

  Future<void> _requestPermissions() async {
    final statuses = await [
      Permission.camera,
      Permission.notification,
    ].request();

    final allGranted = statuses.values.every((status) => status.isGranted);

    if (allGranted) {
      _navigateToHome();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('앱을 사용하려면 모든 권한이 필요합니다'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _navigateToHome() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_allPermissionsGranted) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.security,
                size: 100,
                color: Colors.blue[700],
              ),
              const SizedBox(height: 30),
              const Text(
                'SafeDrive AI',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                'AI 기반 운전 안전 모니터링',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 60),
              _buildPermissionItem(
                Icons.camera_alt,
                '카메라',
                '얼굴 감지를 위해 필요합니다',
              ),
              const SizedBox(height: 20),
              _buildPermissionItem(
                Icons.notifications,
                '알림',
                '위험 상황 알림을 위해 필요합니다',
              ),
              const SizedBox(height: 50),
              ElevatedButton(
                onPressed: _requestPermissions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  '권한 허용하기',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionItem(IconData icon, String title, String description) {
    return Row(
      children: [
        Icon(icon, size: 40, color: Colors.blue[700]),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
