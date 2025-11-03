import 'dart:async';
import 'package:camera/camera.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter/foundation.dart';
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
  bool _isProcessingImage = false; // 이미지 처리 중 플래그

  // 이벤트 카운트 쿨다운 플래그
  bool _isDrowsyAlertActive = false;
  bool _isPhoneAlertActive = false;

  BackgroundMonitoringService._init();

  CameraController? get cameraController => _cameraController;
  bool get isMonitoring => _isMonitoring;

  Future<void> initialize() async {
    try {
      await _notificationService.initialize();
      await _initializeCamera();
    } catch (e) {
      debugPrint('Initialization error: $e');
      rethrow;
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        throw Exception('No cameras available');
      }

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
      debugPrint('Camera initialized successfully');
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      _cameraController = null;
      rethrow;
    }
  }

  Future<void> startMonitoring() async {
    if (_isMonitoring) {
      debugPrint('Already monitoring');
      return;
    }

    try {
      // 카메라 확인
      if (_cameraController == null ||
          !_cameraController!.value.isInitialized) {
        debugPrint("Camera not ready, initializing...");
        await _initializeCamera();

        if (_cameraController == null ||
            !_cameraController!.value.isInitialized) {
          throw Exception("Camera failed to initialize");
        }
      }

      FlutterBackgroundService().startService();

      _isMonitoring = true;
      _sessionStartTime = DateTime.now();

      // 세션 생성
      final session = DrivingSession(
        startTime: _sessionStartTime!,
      );
      _currentSessionId = await _databaseService.createSession(session);
      debugPrint('Session created: $_currentSessionId');

      // 배터리 기반 폴링 레이트 조정
      await _adjustPollingRate();

      // GPS 모니터링 시작 (선택적)
      try {
        final gpsStarted = await _gpsService.startMonitoring();
        if (gpsStarted) {
          debugPrint('GPS monitoring started');
          _gpsService.onBehaviorDetected = _onBehaviorDetected;
        } else {
          debugPrint(
              'GPS monitoring not available (permission denied or disabled)');
        }
      } catch (e) {
        debugPrint('GPS service error: $e');
        // GPS 실패해도 계속 진행
      }

      // 이미지 처리 스트림 시작
      _startImageProcessingStream();

      // 배터리 체크 타이머
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

      debugPrint('Monitoring started successfully');
    } catch (e) {
      debugPrint('Error starting monitoring: $e');
      _isMonitoring = false;
      rethrow;
    }
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

  void _onBehaviorDetected(DrivingBehaviorEvent event) async {
    try {
      // 알림 표시
      DetectionType notificationType = DetectionType.drowsiness; // 기본값
      String message = '';
      AlertLevel alertLevel =
          event.severity >= 2 ? AlertLevel.warning : AlertLevel.caution;

      switch (event.type) {
        case DrivingBehaviorType.harshAcceleration:
          message = '급가속이 감지되었습니다. 부드럽게 운전하세요.';
          break;
        case DrivingBehaviorType.harshBraking:
          message = '급감속이 감지되었습니다. 안전거리를 유지하세요.';
          break;
        case DrivingBehaviorType.harshTurn:
          message = '급회전이 감지되었습니다. 천천히 회전하세요.';
          break;
      }

      await _notificationService.showAlert(
        notificationType,
        alertLevel,
        message,
      );

      // 데이터베이스에 저장
      if (_currentSessionId != null) {
        final eventWithSession = DrivingBehaviorEvent(
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
        await _databaseService.createBehaviorEvent(eventWithSession);
      }
    } catch (e) {
      debugPrint('Error handling behavior event: $e');
    }
  }

  Future<void> _adjustPollingRate() async {
    try {
      final batteryLevel = await _battery.batteryLevel;

      if (batteryLevel >= 70) {
        _currentPollingRate = AppConstants.POLLING_RATES['high_battery']!;
      } else if (batteryLevel >= 30) {
        _currentPollingRate = AppConstants.POLLING_RATES['medium_battery']!;
      } else {
        _currentPollingRate = AppConstants.POLLING_RATES['low_battery']!;
      }

      debugPrint(
          'Polling rate adjusted: $_currentPollingRate seconds (Battery: $batteryLevel%)');
    } catch (e) {
      debugPrint('Error adjusting polling rate: $e');
      _currentPollingRate = 2; // 기본값
    }
  }

  Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;

    try {
      _isMonitoring = false;

      // 이미지 스트림 중지
      try {
        await _cameraController?.stopImageStream();
      } catch (e) {
        debugPrint('Error stopping image stream: $e');
      }

      // GPS 중지
      _gpsService.stopMonitoring();

      // 타이머 중지
      _batteryCheckTimer?.cancel();
      _batteryCheckTimer = null;

      // 세션 종료
      if (_currentSessionId != null && _sessionStartTime != null) {
        final endTime = DateTime.now();
        final duration = endTime.difference(_sessionStartTime!);

        // GPS 통계 가져오기
        final behaviorStats = _gpsService.getBehaviorStatistics();
        final gpsScore = _gpsService.calculateBehaviorScore();
        final drivingStats = _gpsService.getDrivingStatistics();

        // 점수 계산
        double score = 100.0;
        score -= _drowsinessEventCount * AppConstants.DROWSINESS_PENALTY;
        score -= _phoneUsageEventCount * AppConstants.PHONE_USAGE_PENALTY;
        score -= gpsScore;
        score = score.clamp(0.0, 100.0);

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
          durationMinutes: duration.inMinutes,
          totalDistance: drivingStats['totalDistance'],
          maxSpeed: drivingStats['maxSpeed'],
          averageSpeed: drivingStats['averageSpeed'],
        );

        await _databaseService.updateSession(session);
        debugPrint(
            'Session ended: ID $_currentSessionId, Score: ${score.toStringAsFixed(1)}');
        debugPrint(
            '  Distance: ${drivingStats['totalDistance']?.toStringAsFixed(1)} km');
        debugPrint(
            '  Max Speed: ${drivingStats['maxSpeed']?.toStringAsFixed(0)} km/h');
        debugPrint(
            '  Avg Speed: ${drivingStats['averageSpeed']?.toStringAsFixed(0)} km/h');
      }

      // 초기화
      _currentSessionId = null;
      _sessionStartTime = null;
      _drowsinessEventCount = 0;
      _phoneUsageEventCount = 0;
      _isDrowsyAlertActive = false;
      _isPhoneAlertActive = false;

      debugPrint('Monitoring stopped successfully');
    } catch (e) {
      debugPrint('Error stopping monitoring: $e');
    }
  }

  Future<void> dispose() async {
    await stopMonitoring();
    await _cameraController?.dispose();
    _cameraController = null;
    _gpsService.dispose();
  }
}
