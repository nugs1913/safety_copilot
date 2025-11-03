import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // SystemNavigator.pop
import 'package:flutter_background_service/flutter_background_service.dart'; // 서비스 제어
import '../services/background_service.dart';
import '../services/database_service.dart';
import 'monitoring_screen.dart';
import 'history_screen.dart';
import 'score_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BackgroundMonitoringService _monitoringService =
      BackgroundMonitoringService.instance;
  final DatabaseService _databaseService = DatabaseService.instance;

  Map<String, dynamic>? _statistics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    if (!mounted) return;
    final stats = await _databaseService.getStatistics();
    setState(() {
      _statistics = stats;
      _isLoading = false;
    });
  }

  // (추가) 종료 확인 다이얼로그
  Future<bool> _showExitDialog() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('앱 종료'),
          content: const Text('모니터링을 중지하고 앱을 종료하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('종료'),
            ),
          ],
        );
      },
    );

    return shouldPop ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // (수정) PopScope로 Scaffold를 감싸서 뒤로가기 제어
    return PopScope(
      canPop: false, // 뒤로가기 버튼을 수동으로 제어
      onPopInvoked: (didPop) async {
        if (didPop) {
          return;
        }

        final shouldExit = await _showExitDialog();
        if (shouldExit) {
          // 모니터링 중지 (카메라, DB 등)
          await _monitoringService.stopMonitoring();

          // 네이티브 서비스/알림도 강제 중지 (stopMonitoring에 이미 포함됨)
          // FlutterBackgroundService().invoke("stopService");

          // 앱 종료
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('SafeDrive AI'),
          centerTitle: true,
          backgroundColor: Colors.blue[700],
          elevation: 0,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildMonitoringButton(),
                    const SizedBox(height: 30),
                    _buildStatisticsCard(),
                    const SizedBox(height: 20),
                    _buildQuickActions(),
                    const SizedBox(height: 30),
                    _buildInfoCard(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildMonitoringButton() {
    final isMonitoring = _monitoringService.isMonitoring;

    return ElevatedButton(
      onPressed: () async {
        if (isMonitoring) {
          // stopMonitoring은 이제 네이티브 서비스도 중지시킴
          await _monitoringService.stopMonitoring();
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('모니터링이 종료되었습니다')),
          );
        } else {
          if (mounted) {
            // startMonitoring은 이제 네이티브 서비스도 시작시킴
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MonitoringScreen(),
              ),
            );
            // 화면 복귀 시 UI 갱신 및 통계 로드
            setState(() {});
            _loadStatistics();
          }
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isMonitoring ? Colors.red[600] : Colors.green[600],
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isMonitoring ? Icons.stop_circle : Icons.play_circle_filled,
            size: 32,
          ),
          const SizedBox(width: 12),
          Text(
            isMonitoring ? '모니터링 중지' : '모니터링 시작',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard() {
    if (_statistics == null) return const SizedBox.shrink();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '전체 통계',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  Icons.drive_eta,
                  '총 주행',
                  '${_statistics!['totalSessions']}회',
                ),
                _buildStatItem(
                  Icons.stars,
                  '평균 점수',
                  '${_statistics!['averageScore'].toStringAsFixed(1)}점',
                ),
                _buildStatItem(
                  Icons.warning_amber,
                  '총 경고',
                  '${_statistics!['totalEvents']}회',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 32, color: Colors.blue[700]),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            '운전 점수',
            Icons.assessment,
            Colors.purple,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ScoreScreen(),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _buildActionButton(
            '주행 기록',
            Icons.history,
            Colors.orange,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HistoryScreen(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Colors.blue[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  '사용 안내',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoItem('• 운전 시작 전 "모니터링 시작"을 눌러주세요'),
            _buildInfoItem('• 전면 카메라가 얼굴을 감지합니다'),
            _buildInfoItem('• 졸음 또는 휴대전화 사용 시 알림이 울립니다'),
            _buildInfoItem('• 운전 후 점수를 확인하세요'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[700],
        ),
      ),
    );
  }
}
