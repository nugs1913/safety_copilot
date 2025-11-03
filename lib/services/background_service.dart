import 'dart:async';
import 'package:camera/camera.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'face_detection_service.dart';
import 'notification_service.dart';
import 'database_service.dart';
import '../models/detection_event.dart';
import '../models/driving_session.dart';
import '../utils/constants.dart';
import '../utils/detection_algorithms.dart';

class BackgroundMonitoringService {
  // [중요] 백그라운드 Isolate에서만 인스턴스가 생성되어야 함
  static final BackgroundMonitoringService instance =
      BackgroundMonitoringService._init();

  final FaceDetectionService _faceDetectionService = FaceDetectionService();
  final NotificationService _notificationService = NotificationService.instance;
  final DatabaseService _databaseService = DatabaseService.instance;
  final Battery _battery = Battery();

  CameraController? _cameraController;
  Timer? _batteryCheckTimer;
  StreamSubscription<Position>? _gpsSubscription;

  int _currentPollingRate = 1;
  int? _currentSessionId;
  int _drowsinessEventCount = 0;
  int _phoneUsageEventCount = 0;
  DateTime? _sessionStartTime;

  bool _isMonitoring = false;

  bool _isDrowsyAlertActive = false;
  bool _isPhoneAlertActive = false;

  // GPS 데이터 추적 변수
  Position? _previousPosition;
  DateTime? _previousTimestamp;
  double _totalDistance = 0.0;
  double _maxSpeed = 0.0;
  List<double> _speedHistory = [];
  int _harshAccelerationCount = 0;
  int _harshBrakingCount = 0;
  int _harshTurnCount = 0;
  bool _isHarshAccelerationAlertActive = false;
  bool _isHarshBrakingAlertActive = false;
  bool _isHarshTurnAlertActive = false;

  BackgroundMonitoringService._init();

  CameraController? get cameraController => _cameraController;

  Future<void> initialize() async {
    // 알림 서비스 초기화 (main.dart에서도 호출하지만, Isolate에서 한 번 더 보장)
    await _notificationService.initialize();

    // GPS 권한 및 서비스 활성화 확인 (권한은 main에서 이미 요청했어야 함)
    await _initializeGps();

    // 카메라 초기화
    await _initializeCamera();
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
        ResolutionPreset.medium,
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
    _startGpsMonitoring();

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

  void _startGpsMonitoring() {
    _gpsSubscription?.cancel();
    _gpsSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      if (!_isMonitoring) return;

      _processGpsData(position);
    }, onError: (e) {
      print('GPS Stream Error: $e');
    });
  }

  void _processGpsData(Position position) {
    final currentTime = DateTime.now();

    // 현재 속도 (m/s -> km/h)
    final currentSpeed = (position.speed * 3.6).clamp(0.0, 300.0);

    // 속도 히스토리에 추가 (평균 속도 계산용)
    _speedHistory.add(currentSpeed);
    if (_speedHistory.length > 100) {
      _speedHistory.removeAt(0); // 최근 100개만 유지
    }

    // 최고 속도 업데이트
    if (currentSpeed > _maxSpeed) {
      _maxSpeed = currentSpeed;
    }

    // 이전 위치가 있으면 변화량 계산
    if (_previousPosition != null && _previousTimestamp != null) {
      final timeDiff = currentTime.difference(_previousTimestamp!).inMilliseconds / 1000.0;

      if (timeDiff > 0 && timeDiff < 10) { // 10초 이내의 유효한 데이터만 처리
        // 거리 계산 (미터)
        final distance = Geolocator.distanceBetween(
          _previousPosition!.latitude,
          _previousPosition!.longitude,
          position.latitude,
          position.longitude,
        );

        // 총 거리 누적 (km)
        _totalDistance += distance / 1000.0;

        // 이전 속도
        final previousSpeed = (_previousPosition!.speed * 3.6).clamp(0.0, 300.0);

        // 가속도 계산 (m/s²)
        final acceleration = ((currentSpeed - previousSpeed) / 3.6) / timeDiff;

        // 급가속 감지
        if (acceleration > AppConstants.HARSH_ACCELERATION_THRESHOLD) {
          if (!_isHarshAccelerationAlertActive) {
            _isHarshAccelerationAlertActive = true;
            _harshAccelerationCount++;
            print("--- HARSH ACCELERATION DETECTED (Total: $_harshAccelerationCount) ---");
            print("Acceleration: ${acceleration.toStringAsFixed(2)} m/s²");
            _notificationService.showAlert(
              DetectionType.phoneUsage, // GPS 이벤트용 임시 타입 사용
              AlertLevel.warning,
              '급가속이 감지되었습니다. 안전 운전하세요.',
            );
          }
        } else if (acceleration < AppConstants.HARSH_ACCELERATION_THRESHOLD * 0.5) {
          _isHarshAccelerationAlertActive = false;
        }

        // 급제동 감지
        if (acceleration < -AppConstants.HARSH_BRAKING_THRESHOLD) {
          if (!_isHarshBrakingAlertActive) {
            _isHarshBrakingAlertActive = true;
            _harshBrakingCount++;
            print("--- HARSH BRAKING DETECTED (Total: $_harshBrakingCount) ---");
            print("Deceleration: ${acceleration.abs().toStringAsFixed(2)} m/s²");
            _notificationService.showAlert(
              DetectionType.phoneUsage, // GPS 이벤트용 임시 타입 사용
              AlertLevel.danger,
              '급제동이 감지되었습니다. 안전거리를 유지하세요.',
            );
          }
        } else if (acceleration > -AppConstants.HARSH_BRAKING_THRESHOLD * 0.5) {
          _isHarshBrakingAlertActive = false;
        }

        // 방향 변화 계산 (급회전 감지)
        final bearing = Geolocator.bearingBetween(
          _previousPosition!.latitude,
          _previousPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        final previousBearing = _previousPosition!.heading;

        if (previousBearing >= 0 && distance > 5) { // 5미터 이상 이동했을 때만
          var bearingDiff = (bearing - previousBearing).abs();
          if (bearingDiff > 180) {
            bearingDiff = 360 - bearingDiff;
          }

          // 각도 변화율 (degrees/second)
          final turnRate = bearingDiff / timeDiff;

          // 급회전 감지
          if (turnRate > AppConstants.HARSH_TURN_THRESHOLD && currentSpeed > 10) {
            if (!_isHarshTurnAlertActive) {
              _isHarshTurnAlertActive = true;
              _harshTurnCount++;
              print("--- HARSH TURN DETECTED (Total: $_harshTurnCount) ---");
              print("Turn rate: ${turnRate.toStringAsFixed(2)} degrees/s");
              _notificationService.showAlert(
                DetectionType.phoneUsage, // GPS 이벤트용 임시 타입 사용
                AlertLevel.warning,
                '급회전이 감지되었습니다. 속도를 줄이세요.',
              );
            }
          } else if (turnRate < AppConstants.HARSH_TURN_THRESHOLD * 0.5) {
            _isHarshTurnAlertActive = false;
          }
        }
      }
    }

    // 현재 위치와 시간을 이전 값으로 저장
    _previousPosition = position;
    _previousTimestamp = currentTime;
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
    _gpsSubscription?.cancel();
    _gpsSubscription = null;

    // [제거] FlutterBackgroundService().invoke("stopService");

    if (_currentSessionId != null && _sessionStartTime != null) {
      // ... (세션 저장 로직은 원본과 동일) ...
      final endTime = DateTime.now();
      final duration = endTime.difference(_sessionStartTime!);
      final durationInMinutes = (duration.inSeconds / 60).ceil();
      final effectiveDurationMinutes =
          durationInMinutes < 1 ? 1 : durationInMinutes;
      // 평균 속도 계산
      final averageSpeed = _speedHistory.isNotEmpty
          ? _speedHistory.reduce((a, b) => a + b) / _speedHistory.length
          : 0.0;

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
        harshAccelerationEvents: _harshAccelerationCount,
        harshBrakingEvents: _harshBrakingCount,
        harshTurnEvents: _harshTurnCount,
        score: score,
        durationMinutes: durationInMinutes,
        totalDistance: _totalDistance > 0 ? _totalDistance : null,
        maxSpeed: _maxSpeed > 0 ? _maxSpeed : null,
        averageSpeed: averageSpeed > 0 ? averageSpeed : null,
      );
      await _databaseService.updateSession(session);
    }

    // 카운터 및 플래그 리셋
    _drowsinessEventCount = 0;
    _phoneUsageEventCount = 0;
    _harshAccelerationCount = 0;
    _harshBrakingCount = 0;
    _harshTurnCount = 0;
    _currentSessionId = null;
    _sessionStartTime = null;
    _isDrowsyAlertActive = false;
    _isPhoneAlertActive = false;
    _isHarshAccelerationAlertActive = false;
    _isHarshBrakingAlertActive = false;
    _isHarshTurnAlertActive = false;

    // GPS 데이터 리셋
    _previousPosition = null;
    _previousTimestamp = null;
    _totalDistance = 0.0;
    _maxSpeed = 0.0;
    _speedHistory.clear();

    // 서비스 종료 시 리소스 즉시 해제
    dispose();

    print('Monitoring stopped and resources disposed');
  }

  void dispose() {
    _batteryCheckTimer?.cancel();
    _cameraController?.dispose();
    _gpsSubscription?.cancel();
    _faceDetectionService.dispose();
    _notificationService.dispose();
    print("All services disposed.");
  }

  bool get isMonitoring => _isMonitoring;
  int get currentPollingRate => _currentPollingRate;
}
