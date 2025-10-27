import 'dart:async';
import 'package:camera/camera.dart';
import 'package:battery_plus/battery_plus.dart';
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
  Timer? _monitoringTimer;
  
  int _currentPollingRate = 1;
  int? _currentSessionId;
  int _drowsinessEventCount = 0;
  int _phoneUsageEventCount = 0;
  DateTime? _sessionStartTime;

  bool _isMonitoring = false;

  BackgroundMonitoringService._init();

  Future<void> initialize() async {
    await _notificationService.initialize();
    await _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      
      // 전면 카메라 찾기
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium, // 배터리 절약을 위해 중간 해상도
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

    _isMonitoring = true;
    _sessionStartTime = DateTime.now();

    // 새 운전 세션 생성
    final session = DrivingSession(
      startTime: _sessionStartTime!,
    );
    _currentSessionId = await _databaseService.createSession(session);

    // 배터리 레벨에 따른 폴링 레이트 조정
    await _adjustPollingRate();

    // 모니터링 시작
    _startPeriodicMonitoring();

    print('Monitoring started - Session ID: $_currentSessionId');
  }

  void _startPeriodicMonitoring() {
    _monitoringTimer?.cancel();
    
    _monitoringTimer = Timer.periodic(
      Duration(seconds: _currentPollingRate),
      (timer) async {
        if (!_isMonitoring) {
          timer.cancel();
          return;
        }

        await _processFrame();
        
        // 주기적으로 배터리 레벨 체크 (1분마다)
        if (timer.tick % 60 == 0) {
          await _adjustPollingRate();
        }
      },
    );
  }

  Future<void> _processFrame() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      // 카메라에서 이미지 스트림 가져오기
      _cameraController!.startImageStream((CameraImage image) async {
        final result = await _faceDetectionService.processImage(image);
        
        if (result['faceDetected'] == true) {
          await _handleDetectionResult(result);
        }
      });
    } catch (e) {
      print('Frame processing error: $e');
    }
  }

  Future<void> _handleDetectionResult(Map<String, dynamic> result) async {
    final drowsinessLevel = result['drowsinessLevel'] as AlertLevel;
    final phoneUsageLevel = result['phoneUsageLevel'] as AlertLevel;

    // 졸음운전 감지
    if (drowsinessLevel != AlertLevel.normal) {
      _drowsinessEventCount++;
      
      await _notificationService.showAlert(
        DetectionType.drowsiness,
        drowsinessLevel,
        _getDrowsinessMessage(drowsinessLevel),
      );

      // 이벤트 기록
      await _recordEvent(DetectionType.drowsiness, drowsinessLevel);
    }

    // 휴대전화 사용 감지
    if (phoneUsageLevel != AlertLevel.normal) {
      _phoneUsageEventCount++;
      
      await _notificationService.showAlert(
        DetectionType.phoneUsage,
        phoneUsageLevel,
        _getPhoneUsageMessage(phoneUsageLevel),
      );

      // 이벤트 기록
      await _recordEvent(DetectionType.phoneUsage, phoneUsageLevel);
    }
  }

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
      print('Polling rate adjusted to: $_currentPollingRate seconds');
      
      // 타이머 재시작
      if (_isMonitoring) {
        _startPeriodicMonitoring();
      }
    }
  }

  Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;

    _isMonitoring = false;
    _monitoringTimer?.cancel();
    _cameraController?.stopImageStream();

    // 세션 종료
    if (_currentSessionId != null && _sessionStartTime != null) {
      final duration = DateTime.now().difference(_sessionStartTime!).inMinutes;
      
      final score = DetectionAlgorithms.calculateDrivingScore(
        drowsinessEvents: _drowsinessEventCount,
        phoneUsageEvents: _phoneUsageEventCount,
        durationMinutes: duration,
      );

      final session = DrivingSession(
        id: _currentSessionId,
        startTime: _sessionStartTime!,
        endTime: DateTime.now(),
        drowsinessEvents: _drowsinessEventCount,
        phoneUsageEvents: _phoneUsageEventCount,
        score: score,
        durationMinutes: duration,
      );

      await _databaseService.updateSession(session);
    }

    // 카운터 리셋
    _drowsinessEventCount = 0;
    _phoneUsageEventCount = 0;
    _currentSessionId = null;
    _sessionStartTime = null;

    print('Monitoring stopped');
  }

  void dispose() {
    _monitoringTimer?.cancel();
    _cameraController?.dispose();
    _faceDetectionService.dispose();
    _notificationService.dispose();
  }

  bool get isMonitoring => _isMonitoring;
  int get currentPollingRate => _currentPollingRate;
}
