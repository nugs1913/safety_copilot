import 'dart:async';
import 'package:camera/camera.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'face_detection_service.dart';
import 'notification_service.dart';
import 'database_service.dart';
import '../models/detection_event.dart';
import '../models/driving_session.dart';
import '../utils/constants.dart';
import '../utils/detection_algorithms.dart';

class BackgroundMonitoringService {
  static final BackgroundMonitoringService instance =
      BackgroundMonitoringService._init();

  final FaceDetectionService _faceDetectionService = FaceDetectionService();
  final NotificationService _notificationService = NotificationService.instance;
  final DatabaseService _databaseService = DatabaseService.instance;
  final Battery _battery = Battery();

  CameraController? _cameraController;
  Timer? _batteryCheckTimer;

  int _currentPollingRate = 1;
  int? _currentSessionId;
  int _drowsinessEventCount = 0;
  int _phoneUsageEventCount = 0;
  DateTime? _sessionStartTime;

  bool _isMonitoring = false;

  // 이벤트 카운트 쿨다운 플래그
  bool _isDrowsyAlertActive = false;
  bool _isPhoneAlertActive = false;

  BackgroundMonitoringService._init();

  CameraController? get cameraController => _cameraController;

  Future<void> initialize() async {
    await _notificationService.initialize();
    await _initializeCamera();
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
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();
    } catch (e) {
      print('Camera initialization error: $e');
    }
  }

  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      print("Camera not ready, initializing...");
      await _initializeCamera();
      if (_cameraController == null ||
          !_cameraController!.value.isInitialized) {
        print("Camera failed to initialize. Cannot start monitoring.");
        return;
      }
    }

    FlutterBackgroundService().startService();

    _isMonitoring = true;
    _sessionStartTime = DateTime.now();

    final session = DrivingSession(
      startTime: _sessionStartTime!,
    );
    _currentSessionId = await _databaseService.createSession(session);

    await _adjustPollingRate();

    _startImageProcessingStream();

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
        if (!_isMonitoring) {
          return;
        }

        final result = await _faceDetectionService.processImage(image);

        if (result['faceDetected'] == true) {
          await _handleDetectionResult(result);
        }
      });
    } catch (e) {
      print('Error starting image stream: $e');
    }
  }

  // --- 수정된 부분: 탐지 안되는 버그 수정 ---
  Future<void> _handleDetectionResult(Map<String, dynamic> result) async {
    final drowsinessLevel = result['drowsinessLevel'] as AlertLevel;
    final phoneUsageLevel = result['phoneUsageLevel'] as AlertLevel;

    // --- 졸음운전 감지 로직 ---
    // '경고' 또는 '위험' 단계일 때
    if (drowsinessLevel == AlertLevel.warning ||
        drowsinessLevel == AlertLevel.danger) {
      // 쿨다운 플래그가 false일 때만 이벤트로 간주 (최초 1회)
      if (!_isDrowsyAlertActive) {
        _isDrowsyAlertActive = true; // 쿨다운 활성화
        _drowsinessEventCount++; // 카운트 1 증가

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
      // '정상' 상태가 되면 쿨다운 해제
      _isDrowsyAlertActive = false;
    }
    // (참고) '주의' 단계(caution)에서는 쿨다운 플래그를 건드리지 않음

    // --- 휴대전화 사용 감지 로직 ---
    // '경고' 또는 '위험' 단계일 때
    if (phoneUsageLevel == AlertLevel.warning ||
        phoneUsageLevel == AlertLevel.danger) {
      // 쿨다운 플래그가 false일 때만 이벤트로 간주 (최초 1회)
      if (!_isPhoneAlertActive) {
        _isPhoneAlertActive = true; // 쿨다운 활성화
        _phoneUsageEventCount++; // 카운트 1 증가

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
      // '정상' 상태가 되면 쿨다운 해제
      _isPhoneAlertActive = false;
    }
    // (참고) '주의' 단계(caution)에서는 쿨다운 플래그를 건드리지 않음
  }
  // --- 수정 끝 ---

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

    FlutterBackgroundService().invoke("stopService");

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
        score: score,
        durationMinutes: durationInMinutes,
      );

      await _databaseService.updateSession(session);
    }

    // 카운터 및 플래그 리셋
    _drowsinessEventCount = 0;
    _phoneUsageEventCount = 0;
    _currentSessionId = null;
    _sessionStartTime = null;
    _isDrowsyAlertActive = false; // 플래그 리셋
    _isPhoneAlertActive = false; // 플래그 리셋

    print('Monitoring stopped');
  }

  void dispose() {
    _batteryCheckTimer?.cancel();
    _cameraController?.dispose();
    _faceDetectionService.dispose();
    _notificationService.dispose();
  }

  bool get isMonitoring => _isMonitoring;
  int get currentPollingRate => _currentPollingRate;
}
