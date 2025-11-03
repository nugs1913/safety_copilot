import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../models/driving_session.dart';
import '../models/detection_event.dart';
import '../models/driving_behavior_event.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseService _databaseService = DatabaseService.instance;
  List<DrivingSession> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    final sessions = await _databaseService.readAllSessions();
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    }
  }

  /// 전체 기록 삭제 확인 다이얼로그
  Future<void> _showDeleteAllDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('전체 기록 삭제'),
        content: const Text('모든 주행 기록을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await _deleteAllRecords();
    }
  }

  /// 전체 기록 삭제
  Future<void> _deleteAllRecords() async {
    try {
      await _databaseService.deleteAllSessions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('모든 기록이 삭제되었습니다')),
        );
        await _loadSessions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
    }
  }

  /// 개별 세션 삭제 확인 다이얼로그
  Future<void> _showDeleteSessionDialog(DrivingSession session) async {
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(session.startTime);
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기록 삭제'),
        content: Text('$dateStr의 주행 기록을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await _deleteSession(session.id!);
    }
  }

  /// 개별 세션 삭제
  Future<void> _deleteSession(int sessionId) async {
    try {
      await _databaseService.deleteSession(sessionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('기록이 삭제되었습니다')),
        );
        await _loadSessions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
    }
  }

  /// 기간별 삭제 다이얼로그
  Future<void> _showDeleteByPeriodDialog() async {
    final period = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('기간별 삭제'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, '1week'),
            child: const Text('1주일 이전 기록'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, '1month'),
            child: const Text('1개월 이전 기록'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, '3months'),
            child: const Text('3개월 이전 기록'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, '6months'),
            child: const Text('6개월 이전 기록'),
          ),
        ],
      ),
    );

    if (period != null && mounted) {
      await _deleteByPeriod(period);
    }
  }

  /// 기간별 삭제 실행
  Future<void> _deleteByPeriod(String period) async {
    DateTime cutoffDate;
    final now = DateTime.now();

    switch (period) {
      case '1week':
        cutoffDate = now.subtract(const Duration(days: 7));
        break;
      case '1month':
        cutoffDate = DateTime(now.year, now.month - 1, now.day);
        break;
      case '3months':
        cutoffDate = DateTime(now.year, now.month - 3, now.day);
        break;
      case '6months':
        cutoffDate = DateTime(now.year, now.month - 6, now.day);
        break;
      default:
        return;
    }

    try {
      final count = await _databaseService.deleteSessionsBefore(cutoffDate);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count개의 기록이 삭제되었습니다')),
        );
        await _loadSessions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('주행 기록'),
        backgroundColor: Colors.orange[700],
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'delete_all':
                  _showDeleteAllDialog();
                  break;
                case 'delete_period':
                  _showDeleteByPeriodDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete_period',
                child: Row(
                  children: [
                    Icon(Icons.date_range, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('기간별 삭제'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red),
                    SizedBox(width: 8),
                    Text('전체 삭제', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadSessions,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(15),
                    itemCount: _sessions.length,
                    itemBuilder: (context, index) {
                      return _buildSessionCard(_sessions[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '아직 주행 기록이 없습니다',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            '모니터링을 시작하여 주행 기록을 남겨보세요',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(DrivingSession session) {
    final dateStr = DateFormat('yyyy-MM-dd').format(session.startTime);
    final timeStr = DateFormat('HH:mm').format(session.startTime);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showSessionDetail(session),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$timeStr • ${session.durationMinutes}분',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _buildScoreBadge(session.score, session.grade),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _showDeleteSessionDialog(session),
                        tooltip: '삭제',
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildEventChip(
                    icon: Icons.bedtime,
                    label: '졸음',
                    count: session.drowsinessEvents,
                    color: Colors.blue,
                  ),
                  _buildEventChip(
                    icon: Icons.phone_android,
                    label: '휴대전화',
                    count: session.phoneUsageEvents,
                    color: Colors.orange,
                  ),
                  _buildEventChip(
                    icon: Icons.speed,
                    label: '급가속',
                    count: session.harshAccelerationEvents,
                    color: Colors.purple,
                  ),
                  _buildEventChip(
                    icon: Icons.warning,
                    label: '급감속',
                    count: session.harshBrakingEvents,
                    color: Colors.red,
                  ),
                ],
              ),
              // GPS 통계 표시
              if (session.totalDistance != null || 
                  session.averageSpeed != null || 
                  session.maxSpeed != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          if (session.totalDistance != null)
                            _buildStatInfo(
                              Icons.route,
                              '주행거리',
                              '${session.totalDistance!.toStringAsFixed(1)} km',
                              Colors.blue[700]!,
                            ),
                          if (session.averageSpeed != null)
                            _buildStatInfo(
                              Icons.speed,
                              '평균속도',
                              '${session.averageSpeed!.toStringAsFixed(0)} km/h',
                              Colors.green[700]!,
                            ),
                          if (session.maxSpeed != null)
                            _buildStatInfo(
                              Icons.trending_up,
                              '최고속도',
                              '${session.maxSpeed!.toStringAsFixed(0)} km/h',
                              Colors.orange[700]!,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatInfo(IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildScoreBadge(double score, String grade) {
    Color badgeColor;
    if (score >= 90) {
      badgeColor = Colors.green;
    } else if (score >= 70) {
      badgeColor = Colors.orange;
    } else {
      badgeColor = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Text(
            grade,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${score.toStringAsFixed(0)}점',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventChip({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Future<void> _showSessionDetail(DrivingSession session) async {
    // 이벤트 로드
    final events = await _databaseService.readSessionEvents(session.id!);
    final behaviorEvents = await _databaseService.readSessionBehaviorEvents(session.id!);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return _buildSessionDetailContent(
            session,
            events,
            behaviorEvents,
            scrollController,
          );
        },
      ),
    );
  }

  Widget _buildSessionDetailContent(
    DrivingSession session,
    List<DetectionEvent> events,
    List<DrivingBehaviorEvent> behaviorEvents,
    ScrollController scrollController,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '주행 상세 정보',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              controller: scrollController,
              children: [
                _buildDetailSection('얼굴 감지 이벤트', events),
                const SizedBox(height: 16),
                _buildBehaviorSection('운전 행동 이벤트', behaviorEvents),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<DetectionEvent> events) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (events.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('이벤트 없음')),
          )
        else
          ...events.map((event) => ListTile(
                leading: Icon(
                  event.type == DetectionType.drowsiness ? Icons.bedtime : Icons.phone_android,
                  color: event.type == DetectionType.drowsiness ? Colors.blue : Colors.orange,
                ),
                title: Text(event.type == DetectionType.drowsiness ? '졸음 감지' : '휴대전화 사용'),
                subtitle: Text(DateFormat('HH:mm:ss').format(event.timestamp)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getLevelColor(event.level),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getLevelText(event.level),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              )),
      ],
    );
  }

  Widget _buildBehaviorSection(String title, List<DrivingBehaviorEvent> events) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (events.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('이벤트 없음')),
          )
        else
          ...events.map((event) => ListTile(
                leading: Text(
                  event.icon,
                  style: const TextStyle(fontSize: 24),
                ),
                title: Text(event.typeNameKo),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat('HH:mm:ss').format(event.timestamp)),
                    Text(
                      event.description,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getSeverityColor(event.severity),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    event.severityNameKo,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              )),
      ],
    );
  }

  Color _getLevelColor(AlertLevel level) {
    switch (level) {
      case AlertLevel.caution:
        return Colors.yellow[700]!;
      case AlertLevel.warning:
        return Colors.orange;
      case AlertLevel.danger:
        return Colors.red;
      case AlertLevel.normal:
        return Colors.green;
    }
  }

  String _getLevelText(AlertLevel level) {
    switch (level) {
      case AlertLevel.caution:
        return '주의';
      case AlertLevel.warning:
        return '경고';
      case AlertLevel.danger:
        return '위험';
      case AlertLevel.normal:
        return '정상';
    }
  }

  Color _getSeverityColor(int severity) {
    switch (severity) {
      case 1:
        return Colors.yellow[700]!;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
