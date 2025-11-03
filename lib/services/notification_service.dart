import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import '../models/detection_event.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._init();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  AudioPlayer? _audioPlayer;
  bool _isInitialized = false;

  NotificationService._init();

  Future<void> initialize() async {
    // 이미 초기화된 경우 스킵
    if (_isInitialized) {
      print('NotificationService already initialized');
      return;
    }

    // 1. 알림 채널 초기화
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _notifications.initialize(initSettings);

    // 2. 오디오 플레이어 생성 및 설정
    _audioPlayer = AudioPlayer();
    await _audioPlayer!.setReleaseMode(ReleaseMode.stop);

    _isInitialized = true;
    print('NotificationService initialized');
  }

  /// 위험 경고 알림 표시 (진동 및 소리 포함)
  Future<void> showAlert(
    DetectionType type,
    AlertLevel level,
    String message,
  ) async {
    // 1. 진동 실행
    try {
      bool? hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        // 위험 수준에 따라 다른 진동 패턴
        if (level == AlertLevel.danger) {
          Vibration.vibrate(pattern: [0, 400, 200, 400]); // 길게 두 번
        } else {
          Vibration.vibrate(duration: 500); // 0.5초
        }
      }
    } catch (e) {
      print('Vibration error: $e');
    }

    // 2. 소리 재생
    try {
      if (_audioPlayer != null) {
        await _audioPlayer!.play(AssetSource('sounds/medium_alarm.mp3'));
      } else {
        print('AudioPlayer not initialized');
      }
    } catch (e) {
      print('AudioPlayer error: $e');
    }

    // 3. 푸시 알림 표시
    String title = (type == DetectionType.drowsiness) ? '졸음 감지' : '휴대전화 사용 감지';

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'safedrive_alert_channel', // 경고용 채널
      'SafeDrive Alerts',
      channelDescription: '운전 중 위험 상황 경고',
      importance: Importance.max, // 가장 높은 중요도
      priority: Priority.high,
      sound: null, // 소리는 AudioPlayer로 재생하므로 기본값은 null
      enableVibration: false, // 진동은 Vibration 패키지로 제어
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(presentSound: false), // 소리 수동 제어
    );

    await _notifications.show(
      level.index, // ID
      title,
      message,
      notificationDetails,
    );
  }

  void dispose() {
    _audioPlayer?.dispose();
    _audioPlayer = null;
    _isInitialized = false;
    print('NotificationService disposed');
  }
}
