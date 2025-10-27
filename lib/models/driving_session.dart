class DrivingSession {
  final int? id;
  final DateTime startTime;
  final DateTime? endTime;
  final int drowsinessEvents;
  final int phoneUsageEvents;
  final double score;
  final int durationMinutes;

  DrivingSession({
    this.id,
    required this.startTime,
    this.endTime,
    this.drowsinessEvents = 0,
    this.phoneUsageEvents = 0,
    this.score = 100.0,
    this.durationMinutes = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'drowsinessEvents': drowsinessEvents,
      'phoneUsageEvents': phoneUsageEvents,
      'score': score,
      'durationMinutes': durationMinutes,
    };
  }

  factory DrivingSession.fromMap(Map<String, dynamic> map) {
    return DrivingSession(
      id: map['id'],
      startTime: DateTime.parse(map['startTime']),
      endTime: map['endTime'] != null ? DateTime.parse(map['endTime']) : null,
      drowsinessEvents: map['drowsinessEvents'] ?? 0,
      phoneUsageEvents: map['phoneUsageEvents'] ?? 0,
      score: map['score'] ?? 100.0,
      durationMinutes: map['durationMinutes'] ?? 0,
    );
  }

  DrivingSession copyWith({
    int? id,
    DateTime? startTime,
    DateTime? endTime,
    int? drowsinessEvents,
    int? phoneUsageEvents,
    double? score,
    int? durationMinutes,
  }) {
    return DrivingSession(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      drowsinessEvents: drowsinessEvents ?? this.drowsinessEvents,
      phoneUsageEvents: phoneUsageEvents ?? this.phoneUsageEvents,
      score: score ?? this.score,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }
}
