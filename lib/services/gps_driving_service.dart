import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/driving_behavior_event.dart';
import '../utils/constants.dart';

/// GPS 기반 운전 행동 감지 서비스
/// 급가속, 급감속, 급회전 등을 감지하고 주행 통계를 추적합니다
class GpsDrivingService {
  static final GpsDrivingService instance = GpsDrivingService._init();
  
  GpsDrivingService._init();

  StreamSubscription<Position>? _positionStream;
  Position? _previousPosition;
  double? _previousSpeed; // m/s
  DateTime? _previousTime;
  
  final List<DrivingBehaviorEvent> _behaviorEvents = [];
  
  // 주행 통계 추적
  double _totalDistance = 0.0; // 총 주행 거리 (km)
  double _maxSpeed = 0.0; // 최고 속도 (km/h)
  final List<double> _speedSamples = []; // 속도 샘플 (평균 계산용)
  
  // 콜백 함수들
  Function(DrivingBehaviorEvent)? onBehaviorDetected;
  
  bool _isMonitoring = false;
  bool get isMonitoring => _isMonitoring;

  /// GPS 모니터링 시작
  Future<bool> startMonitoring() async {
    if (_isMonitoring) return true;

    try {
      // 위치 권한 확인
      bool hasPermission = await _checkLocationPermission();
      if (!hasPermission) {
        debugPrint('Location permission denied');
        return false;
      }

      // 위치 서비스 활성화 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location service is disabled');
        return false;
      }

      // GPS 모니터링 시작
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // 5미터마다 업데이트
      );

      _positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        _onPositionUpdate,
        onError: (error) {
          debugPrint('GPS stream error: $error');
        },
        cancelOnError: false,
      );

      _isMonitoring = true;
      _behaviorEvents.clear();
      _previousPosition = null;
      _previousSpeed = null;
      _previousTime = null;
      
      // 주행 통계 초기화
      _totalDistance = 0.0;
      _maxSpeed = 0.0;
      _speedSamples.clear();

      debugPrint('GPS monitoring started');
      return true;
    } catch (e) {
      debugPrint('Error starting GPS monitoring: $e');
      return false;
    }
  }

  /// GPS 모니터링 중지
  void stopMonitoring() {
    _positionStream?.cancel();
    _positionStream = null;
    _isMonitoring = false;
    _previousPosition = null;
    _previousSpeed = null;
    _previousTime = null;
  }

  /// 위치 권한 확인 및 요청
  Future<bool> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// 위치 업데이트 처리
  void _onPositionUpdate(Position position) {
    try {
      if (_previousPosition == null) {
        _previousPosition = position;
        _previousSpeed = position.speed;
        _previousTime = DateTime.now();
        return;
      }

      final currentTime = DateTime.now();
      final timeDiff = currentTime.difference(_previousTime!).inMilliseconds / 1000.0; // 초 단위
      
      if (timeDiff < 0.5) return; // 0.5초 미만은 무시 (노이즈 방지)

      // 현재 속도 (m/s)
      final currentSpeed = position.speed;
      final currentSpeedKmh = currentSpeed * 3.6; // km/h로 변환
      
      // 주행 거리 계산
      if (currentSpeed > 0.5) { // 최소 1.8 km/h 이상일 때만 거리 계산
        final distance = Geolocator.distanceBetween(
          _previousPosition!.latitude,
          _previousPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        _totalDistance += distance / 1000.0; // 미터를 킬로미터로 변환
      }
      
      // 최고 속도 업데이트
      if (currentSpeedKmh > _maxSpeed) {
        _maxSpeed = currentSpeedKmh;
      }
      
      // 속도 샘플 추가 (평균 계산용)
      if (currentSpeed >= 0 && currentSpeedKmh < 200) { // 유효한 속도만
        _speedSamples.add(currentSpeedKmh);
        // 샘플이 너무 많아지지 않도록 제한 (최근 1000개)
        if (_speedSamples.length > 1000) {
          _speedSamples.removeAt(0);
        }
      }
      
      // 가속도 계산 (m/s²)
      if (_previousSpeed != null && currentSpeed >= 0) {
        final acceleration = (currentSpeed - _previousSpeed!) / timeDiff;
        
        // 비정상적인 값 필터링
        if (acceleration.abs() < 20.0) { // 20 m/s²를 초과하는 가속도는 무시
          // 급가속 감지 (2.5 m/s² 이상 = 약 0-100km/h를 11초에 도달)
          if (acceleration > AppConstants.HARSH_ACCELERATION_THRESHOLD) {
            _detectHarshAcceleration(position, acceleration);
          }
          
          // 급감속 감지 (-3.0 m/s² 이하 = 급제동)
          if (acceleration < -AppConstants.HARSH_BRAKING_THRESHOLD) {
            _detectHarshBraking(position, acceleration);
          }
        }
      }

      // 급회전 감지 (베어링 변화)
      if (_previousPosition != null && position.speed > 5.0) { // 5 m/s (18 km/h) 이상일 때만
        try {
          final bearing = Geolocator.bearingBetween(
            _previousPosition!.latitude,
            _previousPosition!.longitude,
            position.latitude,
            position.longitude,
          );
          
          // 이전 베어링과 비교
          if (_previousPosition!.heading != 0) {
            double bearingChange = (bearing - _previousPosition!.heading).abs();
            if (bearingChange > 180) {
              bearingChange = 360 - bearingChange;
            }
            
            // 1초에 30도 이상 변화 = 급회전
            if (timeDiff > 0 && (bearingChange / timeDiff) > 30) {
              _detectHarshTurn(position, bearingChange / timeDiff);
            }
          }
        } catch (e) {
          debugPrint('Bearing calculation error: $e');
        }
      }

      // 이전 값 업데이트
      _previousPosition = position;
      _previousSpeed = currentSpeed;
      _previousTime = currentTime;
    } catch (e) {
      debugPrint('Position update error: $e');
    }
  }

  /// 급가속 감지
  void _detectHarshAcceleration(Position position, double acceleration) {
    final event = DrivingBehaviorEvent(
      type: DrivingBehaviorType.harshAcceleration,
      timestamp: DateTime.now(),
      latitude: position.latitude,
      longitude: position.longitude,
      speed: position.speed * 3.6, // m/s to km/h
      acceleration: acceleration,
      severity: _calculateSeverity(acceleration, AppConstants.HARSH_ACCELERATION_THRESHOLD, 5.0),
    );

    _behaviorEvents.add(event);
    onBehaviorDetected?.call(event);
  }

  /// 급감속 감지
  void _detectHarshBraking(Position position, double acceleration) {
    final event = DrivingBehaviorEvent(
      type: DrivingBehaviorType.harshBraking,
      timestamp: DateTime.now(),
      latitude: position.latitude,
      longitude: position.longitude,
      speed: position.speed * 3.6, // m/s to km/h
      acceleration: acceleration,
      severity: _calculateSeverity(acceleration.abs(), AppConstants.HARSH_BRAKING_THRESHOLD, 6.0),
    );

    _behaviorEvents.add(event);
    onBehaviorDetected?.call(event);
  }

  /// 급회전 감지
  void _detectHarshTurn(Position position, double bearingChangeRate) {
    final event = DrivingBehaviorEvent(
      type: DrivingBehaviorType.harshTurn,
      timestamp: DateTime.now(),
      latitude: position.latitude,
      longitude: position.longitude,
      speed: position.speed * 3.6,
      turnRate: bearingChangeRate,
      severity: _calculateSeverity(bearingChangeRate, 30.0, 60.0),
    );

    _behaviorEvents.add(event);
    onBehaviorDetected?.call(event);
  }

  /// 심각도 계산 (1-3)
  /// 1 = 경미, 2 = 보통, 3 = 심각
  int _calculateSeverity(double value, double minThreshold, double maxThreshold) {
    final ratio = (value - minThreshold) / (maxThreshold - minThreshold);
    if (ratio < 0.33) return 1;
    if (ratio < 0.67) return 2;
    return 3;
  }

  /// 현재 세션의 운전 행동 이벤트 가져오기
  List<DrivingBehaviorEvent> getBehaviorEvents() {
    return List.unmodifiable(_behaviorEvents);
  }

  /// 운전 행동 점수 계산
  double calculateBehaviorScore() {
    if (_behaviorEvents.isEmpty) return 0.0;

    double totalPenalty = 0.0;

    for (var event in _behaviorEvents) {
      switch (event.type) {
        case DrivingBehaviorType.harshAcceleration:
          totalPenalty += event.severity * 3.0; // 급가속: 3-9점 감점
          break;
        case DrivingBehaviorType.harshBraking:
          totalPenalty += event.severity * 5.0; // 급감속: 5-15점 감점 (더 위험)
          break;
        case DrivingBehaviorType.harshTurn:
          totalPenalty += event.severity * 4.0; // 급회전: 4-12점 감점
          break;
      }
    }

    return totalPenalty;
  }

  /// 운전 행동 통계
  Map<String, int> getBehaviorStatistics() {
    return {
      'harshAcceleration': _behaviorEvents
          .where((e) => e.type == DrivingBehaviorType.harshAcceleration)
          .length,
      'harshBraking': _behaviorEvents
          .where((e) => e.type == DrivingBehaviorType.harshBraking)
          .length,
      'harshTurn': _behaviorEvents
          .where((e) => e.type == DrivingBehaviorType.harshTurn)
          .length,
    };
  }

  /// 현재 속도 가져오기 (km/h)
  double? getCurrentSpeed() {
    return _previousSpeed != null ? _previousSpeed! * 3.6 : null;
  }

  /// 현재 위치 가져오기
  Position? getCurrentPosition() {
    return _previousPosition;
  }
  
  /// 총 주행 거리 가져오기 (km)
  double getTotalDistance() {
    return _totalDistance;
  }
  
  /// 최고 속도 가져오기 (km/h)
  double getMaxSpeed() {
    return _maxSpeed;
  }
  
  /// 평균 속도 가져오기 (km/h)
  double getAverageSpeed() {
    if (_speedSamples.isEmpty) return 0.0;
    
    // 정지 상태 (5 km/h 미만) 제외하고 평균 계산
    final movingSamples = _speedSamples.where((speed) => speed >= 5.0).toList();
    if (movingSamples.isEmpty) return 0.0;
    
    final sum = movingSamples.reduce((a, b) => a + b);
    return sum / movingSamples.length;
  }
  
  /// 주행 통계 요약
  Map<String, double> getDrivingStatistics() {
    return {
      'totalDistance': _totalDistance,
      'maxSpeed': _maxSpeed,
      'averageSpeed': getAverageSpeed(),
    };
  }

  /// 서비스 정리
  void dispose() {
    stopMonitoring();
    _behaviorEvents.clear();
    _speedSamples.clear();
    _totalDistance = 0.0;
    _maxSpeed = 0.0;
  }
}
