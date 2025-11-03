import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/driving_session.dart';
import '../models/detection_event.dart';
import '../utils/constants.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(AppConstants.DB_NAME);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: AppConstants.DB_VERSION,
      onCreate: _createDB,
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
        score $realType,
        durationMinutes $intType
      )
    ''');

    // 감지 이벤트 테이블
    await db.execute('''
      CREATE TABLE events (
        id $idType,
        sessionId $intType,
        type $textType,
        level $textType,
        timestamp $textType,
        notes TEXT,
        FOREIGN KEY (sessionId) REFERENCES sessions (id)
      )
    ''');
  }

  // 세션 CRUD
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
    return await db.delete(
      'sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 이벤트 CRUD
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

  // 통계
  Future<Map<String, dynamic>> getStatistics() async {
    final db = await instance.database;
    
    final totalSessions = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM sessions'),
    ) ?? 0;

    final avgScore = await db.rawQuery(
      'SELECT AVG(score) as avgScore FROM sessions',
    );
    final averageScore = avgScore.first['avgScore'] as double? ?? 0.0;

    final totalEvents = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM events'),
    ) ?? 0;

    return {
      'totalSessions': totalSessions,
      'averageScore': averageScore,
      'totalEvents': totalEvents,
    };
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
