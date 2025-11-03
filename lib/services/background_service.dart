import 'dart:async';
import 'package:camera/camera.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'face_detection_service.dart';
import 'notification_service.dart';
import 'database_service.dart';
import 'gps_driving_service.dart';
import '../models/detection_event.dart';
import '../models/driving_session.dart';
import '../models/driving_behavior_event.dart';
import '../utils/constants.dart';

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
      if (_cameraController == null || !_cameraController!.value.isInitialized) {
        debugPrint("Camera not ready, initializing...");
        await _initializeCamera();
        
        if (_cameraController == null || !_cameraController!.value.isInitialized) {
          throw Exception("Camera failed to initialize");
        }
      }

      _isMonitoring = true;
      _sessionStartTime = DateTime.now();
      _drowsinessEventCount = 0;
      _phoneUsageEventCount = 0;

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
          debugPrint('GPS monitoring not available (permission denied or disabled)');
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
      debugPrint('Camera not initialized for stream');
      return;
    }

    try {
      int frameCount = 0;
      
      // startImageStream은 void를 반환하므로 직접 할당하지 않음
      _cameraController!.startImageStream((CameraImage image) {
        frameCount++;
        
        // 폴링 레이트에 따라 프레임 스킵
        if (frameCount % (30 * _currentPollingRate) != 0) {
          return;
        }

        // 이미 처리 중이면 스킵
        if (_isProcessingImage) {
          return;
        }

        _isProcessingImage = true;
        _processImage(image).whenComplete(() {
          _isProcessingImage = false;
        });
      });

      debugPrint('Image stream started');
    } catch (e) {
      debugPrint('Error starting image stream: $e');
    }
  }

  Future<void> _processImage(CameraImage image) async {
    try {
      final result = await _faceDetectionService.processImage(image);

      if (result['faceDetected'] != true) return;

      final drowsinessLevel = result['drowsinessLevel'] as AlertLevel;
      final phoneUsageLevel = result['phoneUsageLevel'] as AlertLevel;

      // 디버깅을 위한 로그
      if (drowsinessLevel != AlertLevel.normal || phoneUsageLevel != AlertLevel.normal) {
        debugPrint('Detection: drowsiness=$drowsinessLevel, phone=$phoneUsageLevel');
      }

      // 졸음 감지
      if (drowsinessLevel != AlertLevel.normal) {
        await _handleDrowsinessDetection(drowsinessLevel);
      }

      // 휴대전화 사용 감지
      if (phoneUsageLevel != AlertLevel.normal) {
        await _handlePhoneUsageDetection(phoneUsageLevel);
      }
    } catch (e) {
      debugPrint('Image processing error: $e');
    }
  }

  Future<void> _handleDrowsinessDetection(AlertLevel level) async {
    if (_isDrowsyAlertActive) return;

    _isDrowsyAlertActive = true;
    _drowsinessEventCount++;

    debugPrint('⚠️ Drowsiness detected! Level: $level, Count: $_drowsinessEventCount');

    try {
      // 알림 표시
      await _notificationService.showAlert(
        DetectionType.drowsiness,
        level,
        '졸음이 감지되었습니다. 안전한 곳에서 휴식을 취하세요.',
      );

      // 데이터베이스에 저장
      if (_currentSessionId != null) {
        final event = DetectionEvent(
          sessionId: _currentSessionId!,
          type: DetectionType.drowsiness,
          level: level,
          timestamp: DateTime.now(),
          notes: '졸음 감지',
        );
        await _databaseService.createEvent(event);
        debugPrint('Drowsiness event saved to database');
      }

      // 쿨다운 (30초)
      await Future.delayed(const Duration(seconds: 30));
    } catch (e) {
      debugPrint('Error handling drowsiness detection: $e');
    } finally {
      _isDrowsyAlertActive = false;
    }
  }

  Future<void> _handlePhoneUsageDetection(AlertLevel level) async {
    if (_isPhoneAlertActive) return;

    _isPhoneAlertActive = true;
    _phoneUsageEventCount++;

    debugPrint('📱 Phone usage detected! Level: $level, Count: $_phoneUsageEventCount');

    try {
      // 알림 표시
      await _notificationService.showAlert(
        DetectionType.phoneUsage,
        level,
        '휴대전화 사용이 감지되었습니다. 안전 운전하세요.',
      );

      // 데이터베이스에 저장
      if (_currentSessionId != null) {
        final event = DetectionEvent(
          sessionId: _currentSessionId!,
          type: DetectionType.phoneUsage,
          level: level,
          timestamp: DateTime.now(),
          notes: '휴대전화 사용 감지',
        );
        await _databaseService.createEvent(event);
        debugPrint('Phone usage event saved to database');
      }

      // 쿨다운 (20초)
      await Future.delayed(const Duration(seconds: 20));
    } catch (e) {
      debugPrint('Error handling phone usage detection: $e');
    } finally {
      _isPhoneAlertActive = false;
    }
  }

  void _onBehaviorDetected(DrivingBehaviorEvent event) async {
    try {
      // 알림 표시
      DetectionType notificationType = DetectionType.drowsiness; // 기본값
      String message = '';
      AlertLevel alertLevel = event.severity >= 2 ? AlertLevel.warning : AlertLevel.caution;
      
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

      debugPrint('Polling rate adjusted: $_currentPollingRate seconds (Battery: $batteryLevel%)');
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
        debugPrint('Session ended: ID $_currentSessionId, Score: ${score.toStringAsFixed(1)}');
        debugPrint('  Distance: ${drivingStats['totalDistance']?.toStringAsFixed(1)} km');
        debugPrint('  Max Speed: ${drivingStats['maxSpeed']?.toStringAsFixed(0)} km/h');
        debugPrint('  Avg Speed: ${drivingStats['averageSpeed']?.toStringAsFixed(0)} km/h');
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
