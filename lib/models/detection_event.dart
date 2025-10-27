enum DetectionType {
  drowsiness,
  phoneUsage,
}

enum AlertLevel {
  normal,
  caution,   // 경고
  warning,   // 주의
  danger,    // 위험
}

class DetectionEvent {
  final int? id;
  final int sessionId;
  final DetectionType type;
  final AlertLevel level;
  final DateTime timestamp;
  final String? notes;

  DetectionEvent({
    this.id,
    required this.sessionId,
    required this.type,
    required this.level,
    required this.timestamp,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sessionId': sessionId,
      'type': type.toString(),
      'level': level.toString(),
      'timestamp': timestamp.toIso8601String(),
      'notes': notes,
    };
  }

  factory DetectionEvent.fromMap(Map<String, dynamic> map) {
    return DetectionEvent(
      id: map['id'],
      sessionId: map['sessionId'],
      type: DetectionType.values.firstWhere(
        (e) => e.toString() == map['type'],
      ),
      level: AlertLevel.values.firstWhere(
        (e) => e.toString() == map['level'],
      ),
      timestamp: DateTime.parse(map['timestamp']),
      notes: map['notes'],
    );
  }
}
