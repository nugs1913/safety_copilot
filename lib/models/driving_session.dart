class DrivingSession {
  final int? id;
  final DateTime startTime;
  final DateTime? endTime;
  final int drowsinessEvents;
  final int phoneUsageEvents;
  
  // GPS 기반 운전 행동 이벤트
  final int harshAccelerationEvents;
  final int harshBrakingEvents;
  final int harshTurnEvents;
  
  final double score;
  final int durationMinutes;
  final double? totalDistance; // km
  final double? maxSpeed; // km/h - 최고 속도
  final double? averageSpeed; // km/h - 평균 속도

  DrivingSession({
    this.id,
    required this.startTime,
    this.endTime,
    this.drowsinessEvents = 0,
    this.phoneUsageEvents = 0,
    this.harshAccelerationEvents = 0,
    this.harshBrakingEvents = 0,
    this.harshTurnEvents = 0,
    this.score = 100.0,
    this.durationMinutes = 0,
    this.totalDistance,
    this.maxSpeed,
    this.averageSpeed,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'drowsinessEvents': drowsinessEvents,
      'phoneUsageEvents': phoneUsageEvents,
      'harshAccelerationEvents': harshAccelerationEvents,
      'harshBrakingEvents': harshBrakingEvents,
      'harshTurnEvents': harshTurnEvents,
      'score': score,
      'durationMinutes': durationMinutes,
      'totalDistance': totalDistance,
      'maxSpeed': maxSpeed,
      'averageSpeed': averageSpeed,
    };
  }

  factory DrivingSession.fromMap(Map<String, dynamic> map) {
    return DrivingSession(
      id: map['id'],
      startTime: DateTime.parse(map['startTime']),
      endTime: map['endTime'] != null ? DateTime.parse(map['endTime']) : null,
      drowsinessEvents: map['drowsinessEvents'] ?? 0,
      phoneUsageEvents: map['phoneUsageEvents'] ?? 0,
      harshAccelerationEvents: map['harshAccelerationEvents'] ?? 0,
      harshBrakingEvents: map['harshBrakingEvents'] ?? 0,
      harshTurnEvents: map['harshTurnEvents'] ?? 0,
      score: map['score'] ?? 100.0,
      durationMinutes: map['durationMinutes'] ?? 0,
      totalDistance: map['totalDistance'],
      maxSpeed: map['maxSpeed'],
      averageSpeed: map['averageSpeed'],
    );
  }

  DrivingSession copyWith({
    int? id,
    DateTime? startTime,
    DateTime? endTime,
    int? drowsinessEvents,
    int? phoneUsageEvents,
    int? harshAccelerationEvents,
    int? harshBrakingEvents,
    int? harshTurnEvents,
    double? score,
    int? durationMinutes,
    double? totalDistance,
    double? maxSpeed,
    double? averageSpeed,
  }) {
    return DrivingSession(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      drowsinessEvents: drowsinessEvents ?? this.drowsinessEvents,
      phoneUsageEvents: phoneUsageEvents ?? this.phoneUsageEvents,
      harshAccelerationEvents: harshAccelerationEvents ?? this.harshAccelerationEvents,
      harshBrakingEvents: harshBrakingEvents ?? this.harshBrakingEvents,
      harshTurnEvents: harshTurnEvents ?? this.harshTurnEvents,
      score: score ?? this.score,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      totalDistance: totalDistance ?? this.totalDistance,
      maxSpeed: maxSpeed ?? this.maxSpeed,
      averageSpeed: averageSpeed ?? this.averageSpeed,
    );
  }

  /// 총 위험 이벤트 수
  int get totalDangerousEvents {
    return drowsinessEvents + phoneUsageEvents + 
           harshAccelerationEvents + harshBrakingEvents + harshTurnEvents;
  }

  /// 운전 등급 (S ~ F)
  String get grade {
    if (score >= 95) return 'S';
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    return 'F';
  }
}
