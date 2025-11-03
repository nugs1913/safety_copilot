import 'package:flutter/material.dart';
import 'dart:async';
import '../services/background_service.dart';
import '../services/gps_driving_service.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  final BackgroundMonitoringService _monitoringService =
      BackgroundMonitoringService.instance;
  final GpsDrivingService _gpsService = GpsDrivingService.instance;

  Timer? _durationTimer;
  Timer? _statsUpdateTimer;
  Duration _elapsedTime = Duration.zero;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  
  // 실시간 통계
  double _currentSpeed = 0.0;
  String _alertStatus = '정상';
  Color _alertColor = Colors.green;

  @override
  void initState() {
    super.initState();
    _startMonitoring();
  }

  Future<void> _startMonitoring() async {
    try {
      // 초기화
      await _monitoringService.initialize();
      
      // 모니터링 시작
      await _monitoringService.startMonitoring();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
      }

      // 경과 시간 타이머
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted && _monitoringService.isMonitoring) {
          setState(() {
            _elapsedTime = Duration(seconds: _elapsedTime.inSeconds + 1);
          });
        }
      });

      // 통계 업데이트 타이머
      _statsUpdateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        if (mounted && _gpsService.isMonitoring) {
          final speed = _gpsService.getCurrentSpeed();
          if (speed != null) {
            setState(() {
              _currentSpeed = speed;
            });
          }
        }
      });
    } catch (e) {
      debugPrint('Error starting monitoring: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
        
        _showErrorDialog('모니터링 시작 실패', '카메라 또는 권한 문제가 발생했습니다.\n\n오류: $e');
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // 다이얼로그 닫기
              Navigator.pop(context); // 모니터링 화면 닫기
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _statsUpdateTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 80, color: Colors.red),
              const SizedBox(height: 20),
              const Text(
                '모니터링 오류',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('돌아가기'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: !_isInitialized
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 20),
                    Text(
                      '모니터링 준비 중...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              )
            : Stack(
                children: [
                  // 카메라 프리뷰 대신 아이콘 (실제 카메라는 백그라운드에서 작동)
                  Center(
                    child: Icon(
                      Icons.face,
                      size: 200,
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),

                  // 상태 표시 오버레이
                  Positioned(
                    top: 20,
                    left: 20,
                    right: 20,
                    child: _buildStatusCard(),
                  ),

                  // GPS 정보
                  if (_gpsService.isMonitoring)
                    Positioned(
                      top: 200,
                      left: 20,
                      right: 20,
                      child: _buildGpsCard(),
                    ),

                  // 경과 시간
                  Positioned(
                    bottom: 100,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: Text(
                          _formatDuration(_elapsedTime),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 종료 버튼
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: ElevatedButton.icon(
                        onPressed: _stopMonitoring,
                        icon: const Icon(Icons.stop, size: 24),
                        label: const Text(
                          '모니터링 종료',
                          style: TextStyle(fontSize: 18),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 15,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _alertColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _alertColor, width: 2),
      ),
      child: Column(
        children: [
          Icon(_getStatusIcon(), size: 48, color: _alertColor),
          const SizedBox(height: 10),
          Text(
            _alertStatus,
            style: TextStyle(
              color: _alertColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '모니터링 중',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGpsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white30),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.speed, color: Colors.blue, size: 24),
              const SizedBox(width: 10),
              Text(
                '${_currentSpeed.toStringAsFixed(0)} km/h',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'GPS 추적 활성',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (_alertStatus) {
      case '졸음':
        return Icons.bedtime;
      case '휴대전화':
        return Icons.phone_android;
      case '급가속':
        return Icons.speed;
      case '급감속':
        return Icons.warning;
      default:
        return Icons.check_circle;
    }
  }

  Future<void> _stopMonitoring() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('모니터링 종료'),
        content: const Text('주행 기록을 저장하고 모니터링을 종료하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('종료'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        // 로딩 표시
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        await _monitoringService.stopMonitoring();
        
        if (mounted) {
          Navigator.pop(context); // 로딩 닫기
          Navigator.pop(context); // 모니터링 화면 닫기
        }
      } catch (e) {
        debugPrint('Error stopping monitoring: $e');
        if (mounted) {
          Navigator.pop(context); // 로딩 닫기
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('종료 중 오류 발생: $e')),
          );
        }
      }
    }
  }
}
