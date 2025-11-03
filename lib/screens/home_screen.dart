import 'package:flutter/material.dart';
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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final BackgroundMonitoringService _monitoringService =
      BackgroundMonitoringService.instance;
  final DatabaseService _databaseService = DatabaseService.instance;

  Map<String, dynamic>? _statistics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStatistics();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 다시 활성화될 때 (백그라운드에서 돌아올 때) statistics 갱신
    if (state == AppLifecycleState.resumed) {
      _loadStatistics();
    }
  }

  Future<void> _loadStatistics() async {
    final stats = await _databaseService.getStatistics();
    if (mounted) {
      setState(() {
        _statistics = stats;
        _isLoading = false;
      });
    }
  }

  // 다른 화면에서 돌아올 때 statistics 갱신
  void _navigateAndRefresh(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
    // 돌아왔을 때 statistics 갱신
    _loadStatistics();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SafeDrive AI'),
        centerTitle: true,
        backgroundColor: Colors.blue[700],
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStatistics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 모니터링 시작/중지 버튼
                    _buildMonitoringButton(),
                    const SizedBox(height: 30),

                    // 통계 카드
                    _buildStatisticsCard(),
                    const SizedBox(height: 20),

                    // 빠른 액션 버튼들
                    _buildQuickActions(),
                    const SizedBox(height: 30),

                    // 안내 메시지
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
          await _monitoringService.stopMonitoring();
          setState(() {});
          _loadStatistics(); // 모니터링 종료 시 statistics 갱신
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('모니터링이 종료되었습니다')),
            );
          }
        } else {
          _navigateAndRefresh(const MonitoringScreen());
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
                // _buildStatItem(
                //   Icons.warning_amber,
                //   '총 경고',
                //   '${_statistics!['totalEvents']}회',
                // ),
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
            () => _navigateAndRefresh(const ScoreScreen()),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _buildActionButton(
            '주행 기록',
            Icons.history,
            Colors.orange,
            () => _navigateAndRefresh(const HistoryScreen()),
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
