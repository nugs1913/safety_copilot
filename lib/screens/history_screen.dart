import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../models/driving_session.dart';
import '../models/detection_event.dart';
import '../utils/detection_algorithms.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

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
    final sessions = await _databaseService.readAllSessions();
    setState(() {
      _sessions = sessions;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('주행 기록'),
        backgroundColor: Colors.orange[700],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: _sessions.length,
                  itemBuilder: (context, index) {
                    return _buildSessionCard(_sessions[index]);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.drive_eta,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 20),
          Text(
            '주행 기록이 없습니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '모니터링을 시작하여 기록을 남겨보세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(DrivingSession session) {
    final grade = DetectionAlgorithms.getScoreGrade(session.score);
    final gradeColor = DetectionAlgorithms.getGradeColor(grade);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () => _showSessionDetails(session),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 날짜 및 시간
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('yyyy년 M월 d일').format(session.startTime),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${DateFormat('HH:mm').format(session.startTime)} - '
                        '${session.endTime != null ? DateFormat('HH:mm').format(session.endTime!) : "진행중"}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),

                  // 점수 뱃지
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: gradeColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Text(
                          grade,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${session.score.toStringAsFixed(0)}점',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),
              const Divider(),
              const SizedBox(height: 10),

              // 주행 정보
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildInfoChip(
                    Icons.access_time,
                    '${session.durationMinutes}분',
                    Colors.blue,
                  ),
                  _buildInfoChip(
                    Icons.bedtime,
                    '${session.drowsinessEvents}회',
                    Colors.purple,
                  ),
                  _buildInfoChip(
                    Icons.phone_android,
                    '${session.phoneUsageEvents}회',
                    Colors.red,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Future<void> _showSessionDetails(DrivingSession session) async {
    final events = await _databaseService.readSessionEvents(session.id!);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 핸들
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

                  // 제목
                  Text(
                    '주행 상세 정보',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    DateFormat('yyyy년 M월 d일 HH:mm')
                        .format(session.startTime),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 이벤트 목록
                  Text(
                    '감지 이벤트 (${events.length}건)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Expanded(
                    child: events.isEmpty
                        ? const Center(
                            child: Text('위반 사항이 없습니다 👍'),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: events.length,
                            itemBuilder: (context, index) {
                              return _buildEventTile(events[index]);
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEventTile(DetectionEvent event) {
    IconData icon;
    Color color;
    String title;

    if (event.type == DetectionType.drowsiness) {
      icon = Icons.bedtime;
      color = Colors.purple;
      title = '졸음 감지';
    } else {
      icon = Icons.phone_android;
      color = Colors.red;
      title = '휴대전화 사용 감지';
    }

    String levelText;
    switch (event.level) {
      case AlertLevel.caution:
        levelText = '경고';
        break;
      case AlertLevel.warning:
        levelText = '주의';
        break;
      case AlertLevel.danger:
        levelText = '위험';
        break;
      default:
        levelText = '정상';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(DateFormat('HH:mm:ss').format(event.timestamp)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getLevelColor(event.level),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            levelText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Color _getLevelColor(AlertLevel level) {
    switch (level) {
      case AlertLevel.caution:
        return Colors.yellow[700]!;
      case AlertLevel.warning:
        return Colors.orange[700]!;
      case AlertLevel.danger:
        return Colors.red[700]!;
      default:
        return Colors.green[700]!;
    }
  }
}
