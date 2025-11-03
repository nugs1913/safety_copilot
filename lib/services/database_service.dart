import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/driving_session.dart';
import '../models/detection_event.dart';
import '../models/driving_behavior_event.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('safedrive.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3, // 버전 3으로 업그레이드 (maxSpeed, averageSpeed 추가)
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';
    const realType = 'REAL NOT NULL';

    // 운전 세션 테이블
    await db.execute('''
      CREATE TABLE sessions (
        id $idType,
        startTime $textType,
        endTime TEXT,
        drowsinessEvents $intType,
        phoneUsageEvents $intType,
        harshAccelerationEvents $intType,
        harshBrakingEvents $intType,
        harshTurnEvents $intType,
        score $realType,
        durationMinutes $intType,
        totalDistance REAL,
        maxSpeed REAL,
        averageSpeed REAL
      )
    ''');

    // 감지 이벤트 테이블 (얼굴 감지)
    await db.execute('''
      CREATE TABLE events (
        id $idType,
        sessionId $intType,
        type $textType,
        level $textType,
        timestamp $textType,
        notes TEXT,
        FOREIGN KEY (sessionId) REFERENCES sessions (id) ON DELETE CASCADE
      )
    ''');

    // 운전 행동 이벤트 테이블 (GPS 기반)
    await db.execute('''
      CREATE TABLE behavior_events (
        id $idType,
        sessionId $intType,
        type $textType,
        timestamp $textType,
        latitude $realType,
        longitude $realType,
        speed $realType,
        acceleration REAL,
        turnRate REAL,
        severity $intType,
        FOREIGN KEY (sessionId) REFERENCES sessions (id) ON DELETE CASCADE
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 버전 2로 업그레이드: GPS 기능 추가
      await db.execute('''
        ALTER TABLE sessions ADD COLUMN harshAccelerationEvents INTEGER DEFAULT 0
      ''');
      await db.execute('''
        ALTER TABLE sessions ADD COLUMN harshBrakingEvents INTEGER DEFAULT 0
      ''');
      await db.execute('''
        ALTER TABLE sessions ADD COLUMN harshTurnEvents INTEGER DEFAULT 0
      ''');
      await db.execute('''
        ALTER TABLE sessions ADD COLUMN totalDistance REAL
      ''');

      // 운전 행동 이벤트 테이블 생성
      await db.execute('''
        CREATE TABLE IF NOT EXISTS behavior_events (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sessionId INTEGER NOT NULL,
          type TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          latitude REAL NOT NULL,
          longitude REAL NOT NULL,
          speed REAL NOT NULL,
          acceleration REAL,
          turnRate REAL,
          severity INTEGER NOT NULL,
          FOREIGN KEY (sessionId) REFERENCES sessions (id) ON DELETE CASCADE
        )
      ''');
    }
    
    if (oldVersion < 3) {
      // 버전 3으로 업그레이드: 최고 속도, 평균 속도 추가
      try {
        await db.execute('''
          ALTER TABLE sessions ADD COLUMN maxSpeed REAL
        ''');
      } catch (e) {
        // 컬럼이 이미 존재할 수 있음
      }
      
      try {
        await db.execute('''
          ALTER TABLE sessions ADD COLUMN averageSpeed REAL
        ''');
      } catch (e) {
        // 컬럼이 이미 존재할 수 있음
      }
    }
  }

  // ==================== 세션 CRUD ====================
  
  Future<int> createSession(DrivingSession session) async {
    final db = await instance.database;
    return await db.insert('sessions', session.toMap());
  }

  Future<DrivingSession?> readSession(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'sessions',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return DrivingSession.fromMap(maps.first);
    }
    return null;
  }

  Future<List<DrivingSession>> readAllSessions() async {
    final db = await instance.database;
    const orderBy = 'startTime DESC';
    final result = await db.query('sessions', orderBy: orderBy);
    return result.map((json) => DrivingSession.fromMap(json)).toList();
  }

  Future<int> updateSession(DrivingSession session) async {
    final db = await instance.database;
    return db.update(
      'sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  Future<int> deleteSession(int id) async {
    final db = await instance.database;
    // CASCADE로 인해 관련 이벤트들도 자동 삭제됨
    return await db.delete(
      'sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 모든 세션 삭제 (전체 기록 삭제)
  Future<int> deleteAllSessions() async {
    final db = await instance.database;
    // CASCADE로 인해 모든 이벤트들도 자동 삭제됨
    return await db.delete('sessions');
  }

  /// 특정 날짜 이전의 세션 삭제
  Future<int> deleteSessionsBefore(DateTime date) async {
    final db = await instance.database;
    return await db.delete(
      'sessions',
      where: 'startTime < ?',
      whereArgs: [date.toIso8601String()],
    );
  }

  /// 특정 기간의 세션 삭제
  Future<int> deleteSessionsBetween(DateTime start, DateTime end) async {
    final db = await instance.database;
    return await db.delete(
      'sessions',
      where: 'startTime >= ? AND startTime <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
    );
  }

  // ==================== 감지 이벤트 CRUD ====================
  
  Future<int> createEvent(DetectionEvent event) async {
    final db = await instance.database;
    return await db.insert('events', event.toMap());
  }

  Future<List<DetectionEvent>> readSessionEvents(int sessionId) async {
    final db = await instance.database;
    final result = await db.query(
      'events',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp DESC',
    );
    return result.map((json) => DetectionEvent.fromMap(json)).toList();
  }

  Future<int> deleteSessionEvents(int sessionId) async {
    final db = await instance.database;
    return await db.delete(
      'events',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
    );
  }

  // ==================== 운전 행동 이벤트 CRUD ====================
  
  Future<int> createBehaviorEvent(DrivingBehaviorEvent event) async {
    final db = await instance.database;
    return await db.insert('behavior_events', event.toMap());
  }

  Future<List<DrivingBehaviorEvent>> readSessionBehaviorEvents(int sessionId) async {
    final db = await instance.database;
    final result = await db.query(
      'behavior_events',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp DESC',
    );
    return result.map((json) => DrivingBehaviorEvent.fromMap(json)).toList();
  }

  Future<int> deleteSessionBehaviorEvents(int sessionId) async {
    final db = await instance.database;
    return await db.delete(
      'behavior_events',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
    );
  }

  // ==================== 통계 ====================
  
  Future<Map<String, dynamic>> getStatistics() async {
    final db = await instance.database;
    
    final totalSessions = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM sessions'),
    ) ?? 0;

    final avgScore = await db.rawQuery(
      'SELECT AVG(score) as avgScore FROM sessions WHERE endTime IS NOT NULL',
    );
    final averageScore = avgScore.first['avgScore'] as double? ?? 0.0;

    final totalEvents = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM events'),
    ) ?? 0;

    final totalBehaviorEvents = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM behavior_events'),
    ) ?? 0;

    // 운전 행동별 통계
    final behaviorStats = await db.rawQuery('''
      SELECT 
        SUM(harshAccelerationEvents) as totalAcceleration,
        SUM(harshBrakingEvents) as totalBraking,
        SUM(harshTurnEvents) as totalTurns
      FROM sessions
      WHERE endTime IS NOT NULL
    ''');

    final stats = behaviorStats.first;

    return {
      'totalSessions': totalSessions,
      'averageScore': averageScore,
      'totalEvents': totalEvents,
      'totalBehaviorEvents': totalBehaviorEvents,
      'totalHarshAcceleration': stats['totalAcceleration'] ?? 0,
      'totalHarshBraking': stats['totalBraking'] ?? 0,
      'totalHarshTurns': stats['totalTurns'] ?? 0,
    };
  }

  /// 최근 N개 세션의 평균 점수
  Future<double> getRecentAverageScore(int count) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT AVG(score) as avgScore 
      FROM (
        SELECT score FROM sessions 
        WHERE endTime IS NOT NULL
        ORDER BY startTime DESC 
        LIMIT ?
      )
    ''', [count]);

    return result.first['avgScore'] as double? ?? 0.0;
  }

  /// 데이터베이스 크기 (대략적)
  Future<int> getDatabaseSize() async {
    final db = await instance.database;
    
    final sessionsCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM sessions'),
    ) ?? 0;
    
    final eventsCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM events'),
    ) ?? 0;
    
    final behaviorEventsCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM behavior_events'),
    ) ?? 0;

    // 대략적인 크기 계산 (레코드당 평균 크기 * 개수)
    return (sessionsCount * 200) + (eventsCount * 100) + (behaviorEventsCount * 150);
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
