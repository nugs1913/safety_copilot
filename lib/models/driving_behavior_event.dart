/// 운전 행동 유형
enum DrivingBehaviorType {
  harshAcceleration, // 급가속
  harshBraking,      // 급감속
  harshTurn,         // 급회전
}

/// 운전 행동 이벤트 (GPS 기반)
class DrivingBehaviorEvent {
  final int? id;
  final int? sessionId;
  final DrivingBehaviorType type;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double speed; // km/h
  final double? acceleration; // m/s² (급가속/급감속용)
  final double? turnRate; // degrees/second (급회전용)
  final int severity; // 1-3 (1=경미, 2=보통, 3=심각)

  DrivingBehaviorEvent({
    this.id,
    this.sessionId,
    required this.type,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.speed,
    this.acceleration,
    this.turnRate,
    required this.severity,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sessionId': sessionId,
      'type': type.toString().split('.').last,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'acceleration': acceleration,
      'turnRate': turnRate,
      'severity': severity,
    };
  }

  factory DrivingBehaviorEvent.fromMap(Map<String, dynamic> map) {
    return DrivingBehaviorEvent(
      id: map['id'],
      sessionId: map['sessionId'],
      type: DrivingBehaviorType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
      ),
      timestamp: DateTime.parse(map['timestamp']),
      latitude: map['latitude'],
      longitude: map['longitude'],
      speed: map['speed'],
      acceleration: map['acceleration'],
      turnRate: map['turnRate'],
      severity: map['severity'],
    );
  }

  /// 행동 타입의 한글 이름
  String get typeNameKo {
    switch (type) {
      case DrivingBehaviorType.harshAcceleration:
        return '급가속';
      case DrivingBehaviorType.harshBraking:
        return '급감속';
      case DrivingBehaviorType.harshTurn:
        return '급회전';
    }
  }

  /// 심각도 한글
  String get severityNameKo {
    switch (severity) {
      case 1:
        return '경미';
      case 2:
        return '보통';
      case 3:
        return '심각';
      default:
        return '알 수 없음';
    }
  }

  /// 아이콘
  String get icon {
    switch (type) {
      case DrivingBehaviorType.harshAcceleration:
        return '🚀';
      case DrivingBehaviorType.harshBraking:
        return '🛑';
      case DrivingBehaviorType.harshTurn:
        return '↩️';
    }
  }

  /// 상세 설명
  String get description {
    switch (type) {
      case DrivingBehaviorType.harshAcceleration:
        return '${acceleration?.toStringAsFixed(1)} m/s² 가속';
      case DrivingBehaviorType.harshBraking:
        return '${acceleration?.toStringAsFixed(1)} m/s² 감속';
      case DrivingBehaviorType.harshTurn:
        return '${turnRate?.toStringAsFixed(1)}°/s 회전';
    }
  }
}
