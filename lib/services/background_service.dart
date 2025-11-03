import 'dart:async';
import 'package:camera/camera.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'face_detection_service.dart';
import 'notification_service.dart';
import 'database_service.dart';
import 'gps_driving_service.dart';
import '../models/detection_event.dart';
import '../models/driving_session.dart';
import '../models/driving_behavior_event.dart';
import '../utils/constants.dart';
import '../utils/detection_algorithms.dart';

class BackgroundMonitoringService {
  // [중요] 백그라운드 Isolate에서만 인스턴스가 생성되어야 함
  static final BackgroundMonitoringService instance =
      BackgroundMonitoringService._init();

  final FaceDetectionService _faceDetectionService = FaceDetectionService();
  final NotificationService _notificationService = NotificationService.instance;
  final DatabaseService _databaseService = DatabaseService.instance;
  final GpsDrivingService _gpsService = GpsDrivingService.instance;
  final Battery _battery = Battery();

  CameraController? _cameraController;
  Timer? _batteryCheckTimer;

  int _currentPollingRate = 1;
  int? _currentSessionId;
  int _drowsinessEventCount = 0;
  int _phoneUsageEventCount = 0;
  DateTime? _sessionStartTime;

  bool _isMonitoring = false;

  bool _isDrowsyAlertActive = false;
  bool _isPhoneAlertActive = false;

  BackgroundMonitoringService._init();

  CameraController? get cameraController => _cameraController;

  Future<void> initialize() async {
    try {
      // 알림 서비스 초기화 (가벼운 작업)
      await _notificationService.initialize();

      // GPS 권한 확인 (가벼운 작업, 실제 GPS 시작은 나중에)
      await _initializeGps();

      // 카메라 초기화 (무거운 작업)
      await _initializeCamera();

      print('Background service initialized');
    } catch (e) {
      print('Background service initialization error: $e');
      rethrow;
    }
  }

  Future<void> _initializeGps() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled.');
      }
      // 권한 확인 (이미 main에서 요청했지만, 여기서도 확인)
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print('Location permissions are denied. Cannot start GPS.');
        throw Exception('Location permissions are denied.');
      }
      print('GPS initialized');
    } catch (e) {
      print('GPS initialization error: $e');
      rethrow; // 에러를 상위로 전파하여 서비스 시작 중단
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.low, // 빠른 초기화를 위해 low 사용
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();
      print("Camera initialized");
    } catch (e) {
      print('Camera initialization error: $e');
      rethrow; // 에러를 상위로 전파하여 서비스 시작 중단
    }
  }

  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      print("Camera not ready. Cannot start monitoring.");
      return;
    }

    // [제거] FlutterBackgroundService().startService();

    _isMonitoring = true;
    _sessionStartTime = DateTime.now();

    final session = DrivingSession(
      startTime: _sessionStartTime!,
    );
    _currentSessionId = await _databaseService.createSession(session);

    await _adjustPollingRate();

    _startImageProcessingStream();

    // GPS 서비스를 비동기로 시작 (UI 블로킹 방지)
    _gpsService.startMonitoring().then((success) {
      if (success) {
        print('GPS monitoring started successfully');
      } else {
        print('GPS monitoring failed to start');
      }
    });

    _batteryCheckTimer?.cancel();
    _batteryCheckTimer = Timer.periodic(
      const Duration(minutes: 1),
      (timer) async {
        if (!_isMonitoring) {
          timer.cancel();
          return;
        }
        await _adjustPollingRate();
      },
    );

    print('Monitoring started - Session ID: $_currentSessionId');
  }

  void _startImageProcessingStream() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      print("Camera not ready for stream");
      return;
    }

    try {
      _cameraController!.startImageStream((CameraImage image) async {
        if (!_isMonitoring) return;

        // 이 로직은 이제 백그라운드 스레드에서 실행됩니다.
        final result = await _faceDetectionService.processImage(image);

        if (result['faceDetected'] == true) {
          await _handleDetectionResult(result);
        }
      });
    } catch (e) {
      print('Error starting image stream: $e');
    }
  }

  // --- (졸음 감지 로직 _handleDetectionResult는 원본과 동일) ---
  Future<void> _handleDetectionResult(Map<String, dynamic> result) async {
    final drowsinessLevel = result['drowsinessLevel'] as AlertLevel;
    final phoneUsageLevel = result['phoneUsageLevel'] as AlertLevel;

    // --- 졸음운전 감지 로직 ---
    if (drowsinessLevel == AlertLevel.warning ||
        drowsinessLevel == AlertLevel.danger) {
      if (!_isDrowsyAlertActive) {
        _isDrowsyAlertActive = true;
        _drowsinessEventCount++;
        print(
            "--- NEW DROWSINESS EVENT DETECTED (Total: $_drowsinessEventCount) ---");
        await _notificationService.showAlert(
          DetectionType.drowsiness,
          drowsinessLevel,
          _getDrowsinessMessage(drowsinessLevel),
        );
        await _recordEvent(DetectionType.drowsiness, drowsinessLevel);
      }
    } else if (drowsinessLevel == AlertLevel.normal) {
      _isDrowsyAlertActive = false;
    }

    // --- 휴대전화 사용 감지 로직 ---
    if (phoneUsageLevel == AlertLevel.warning ||
        phoneUsageLevel == AlertLevel.danger) {
      if (!_isPhoneAlertActive) {
        _isPhoneAlertActive = true;
        _phoneUsageEventCount++;
        print(
            "--- NEW PHONE USAGE EVENT DETECTED (Total: $_phoneUsageEventCount) ---");
        await _notificationService.showAlert(
          DetectionType.phoneUsage,
          phoneUsageLevel,
          _getPhoneUsageMessage(phoneUsageLevel),
        );
        await _recordEvent(DetectionType.phoneUsage, phoneUsageLevel);
      }
    } else if (phoneUsageLevel == AlertLevel.normal) {
      _isPhoneAlertActive = false;
    }
  }

  // --- (_getDrowsinessMessage, _getPhoneUsageMessage, _recordEvent, _adjustPollingRate는 원본과 동일) ---
  String _getDrowsinessMessage(AlertLevel level) {
    switch (level) {
      case AlertLevel.caution:
        return '졸음 징후가 감지되었습니다. 주의하세요.';
      case AlertLevel.warning:
        return '졸음운전 위험! 잠시 휴식을 취하세요.';
      case AlertLevel.danger:
        return '⚠️ 즉시 안전한 곳에 정차하세요!';
      default:
        return '';
    }
  }

  String _getPhoneUsageMessage(AlertLevel level) {
    switch (level) {
      case AlertLevel.caution:
        return '휴대전화 사용이 의심됩니다.';
      case AlertLevel.warning:
        return '운전 중 휴대전화 사용은 위험합니다!';
      case AlertLevel.danger:
        return '⚠️ 휴대전화를 내려놓으세요!';
      default:
        return '';
    }
  }

  Future<void> _recordEvent(DetectionType type, AlertLevel level) async {
    if (_currentSessionId == null) return;
    final event = DetectionEvent(
      sessionId: _currentSessionId!,
      type: type,
      level: level,
      timestamp: DateTime.now(),
    );
    await _databaseService.createEvent(event);
  }

  Future<void> _adjustPollingRate() async {
    final batteryLevel = await _battery.batteryLevel;
    int newRate;
    if (batteryLevel > 70) {
      newRate = AppConstants.POLLING_RATES['high_battery']!;
    } else if (batteryLevel > 30) {
      newRate = AppConstants.POLLING_RATES['medium_battery']!;
    } else {
      newRate = AppConstants.POLLING_RATES['low_battery']!;
    }

    if (newRate != _currentPollingRate) {
      _currentPollingRate = newRate;
      print('Polling rate logic adjusted to: $_currentPollingRate seconds');
    }
  }

  Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;

    _isMonitoring = false;
    _batteryCheckTimer?.cancel();
    _cameraController?.stopImageStream();

    // GPS 서비스 중지 및 데이터 가져오기
    final gpsStats = _gpsService.getDrivingStatistics();
    final behaviorStats = _gpsService.getBehaviorStatistics();
    final behaviorEvents = _gpsService.getBehaviorEvents();
    _gpsService.stopMonitoring();

    // GPS 행동 이벤트를 데이터베이스에 저장
    if (_currentSessionId != null && behaviorEvents.isNotEmpty) {
      for (var event in behaviorEvents) {
        final eventWithSessionId = DrivingBehaviorEvent(
          sessionId: _currentSessionId,
          type: event.type,
          timestamp: event.timestamp,
          latitude: event.latitude,
          longitude: event.longitude,
          speed: event.speed,
          acceleration: event.acceleration,
          turnRate: event.turnRate,
          severity: event.severity,
        );
        await _databaseService.createBehaviorEvent(eventWithSessionId);
      }
    }

    if (_currentSessionId != null && _sessionStartTime != null) {
      final endTime = DateTime.now();
      final duration = endTime.difference(_sessionStartTime!);
      final durationInMinutes = (duration.inSeconds / 60).ceil();
      final effectiveDurationMinutes =
          durationInMinutes < 1 ? 1 : durationInMinutes;

      final score = DetectionAlgorithms.calculateDrivingScore(
        drowsinessEvents: _drowsinessEventCount,
        phoneUsageEvents: _phoneUsageEventCount,
        durationMinutes: effectiveDurationMinutes,
      );

      final session = DrivingSession(
        id: _currentSessionId,
        startTime: _sessionStartTime!,
        endTime: endTime,
        drowsinessEvents: _drowsinessEventCount,
        phoneUsageEvents: _phoneUsageEventCount,
        harshAccelerationEvents: behaviorStats['harshAcceleration'] ?? 0,
        harshBrakingEvents: behaviorStats['harshBraking'] ?? 0,
        harshTurnEvents: behaviorStats['harshTurn'] ?? 0,
        score: score,
        durationMinutes: durationInMinutes,
        totalDistance: gpsStats['totalDistance']! > 0 ? gpsStats['totalDistance'] : null,
        maxSpeed: gpsStats['maxSpeed']! > 0 ? gpsStats['maxSpeed'] : null,
        averageSpeed: gpsStats['averageSpeed']! > 0 ? gpsStats['averageSpeed'] : null,
      );
      await _databaseService.updateSession(session);
    }

    // 카운터 및 플래그 리셋
    _drowsinessEventCount = 0;
    _phoneUsageEventCount = 0;
    _currentSessionId = null;
    _sessionStartTime = null;
    _isDrowsyAlertActive = false;
    _isPhoneAlertActive = false;

    // 서비스 종료 시 리소스 즉시 해제
    dispose();

    print('Monitoring stopped and resources disposed');
  }

  void dispose() {
    _batteryCheckTimer?.cancel();
    _cameraController?.dispose();
    _gpsService.dispose();
    _faceDetectionService.dispose();
    // NotificationService는 싱글톤이므로 dispose하지 않음 (재사용 가능하도록)
    print("All services disposed.");
  }

  bool get isMonitoring => _isMonitoring;
  int get currentPollingRate => _currentPollingRate;
}
