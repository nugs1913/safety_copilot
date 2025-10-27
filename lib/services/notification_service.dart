import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import '../models/detection_event.dart';
import '../utils/constants.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  bool _isInitialized = false;

  NotificationService._init();

  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(settings);
    _isInitialized = true;
  }

  Future<void> showAlert(
    DetectionType type,
    AlertLevel level,
    String message,
  ) async {
    if (!_isInitialized) {
      await initialize();
    }

    // 알림음 재생
    await _playAlertSound(level);

    // 진동 (위험 수준일 때만)
    if (level == AlertLevel.danger) {
      await _vibrate();
    }

    // 푸시 알림 표시
    await _showNotification(type, level, message);
  }

  Future<void> _playAlertSound(AlertLevel level) async {
    String soundFile;
    
    switch (level) {
      case AlertLevel.caution:
        soundFile = AppConstants.ALERT_SOUNDS['caution']!;
        break;
      case AlertLevel.warning:
        soundFile = AppConstants.ALERT_SOUNDS['warning']!;
        break;
      case AlertLevel.danger:
        soundFile = AppConstants.ALERT_SOUNDS['danger']!;
        break;
      default:
        return;
    }

    try {
      await _audioPlayer.play(AssetSource(soundFile));
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  Future<void> _vibrate() async {
    if (await Vibration.hasVibrator() ?? false) {
      // 진동 패턴: [대기, 진동, 대기, 진동]
      await Vibration.vibrate(
        pattern: [0, 500, 200, 500, 200, 500],
        intensities: [0, 255, 0, 255, 0, 255],
      );
    }
  }

  Future<void> _showNotification(
    DetectionType type,
    AlertLevel level,
    String message,
  ) async {
    int notificationId = type == DetectionType.drowsiness ? 1 : 2;
    String title = type == DetectionType.drowsiness 
        ? '⚠️ 졸음 감지' 
        : '📱 휴대전화 사용 감지';

    // 중요도 설정
    Priority priority;
    Importance importance;
    
    switch (level) {
      case AlertLevel.danger:
        priority = Priority.max;
        importance = Importance.max;
        break;
      case AlertLevel.warning:
        priority = Priority.high;
        importance = Importance.high;
        break;
      case AlertLevel.caution:
        priority = Priority.defaultPriority;
        importance = Importance.defaultImportance;
        break;
      default:
        return;
    }

    final androidDetails = AndroidNotificationDetails(
      'safedrive_alerts',
      'Driving Safety Alerts',
      channelDescription: '운전 안전 경고 알림',
      importance: importance,
      priority: priority,
      showWhen: true,
      enableVibration: level == AlertLevel.danger,
      playSound: true,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      notificationId,
      title,
      message,
      details,
    );
  }

  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
