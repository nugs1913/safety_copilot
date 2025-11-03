import 'package:flutter/material.dart';
import 'dart:async';
import 'package:camera/camera.dart'; // 카메라 패키지 import
import '../services/background_service.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({Key? key}) : super(key: key);

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  final BackgroundMonitoringService _monitoringService =
      BackgroundMonitoringService.instance;

  Timer? _durationTimer;
  Duration _elapsedTime = Duration.zero;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _startMonitoring();
  }

  Future<void> _startMonitoring() async {
    // initialize()는 카메라 컨트롤러를 준비시킵니다.
    await _monitoringService.initialize();
    // startMonitoring()은 준비된 컨트롤러를 사용해 스트림을 시작합니다.
    await _monitoringService.startMonitoring();

    setState(() {
      _isInitialized = true;
    });

    // 경과 시간 타이머
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedTime = Duration(seconds: _elapsedTime.inSeconds + 1);
      });
    });
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
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
    // --- 수정된 부분: 서비스에서 카메라 컨트롤러 가져오기 ---
    final cameraController = _monitoringService.cameraController;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: !_isInitialized ||
                cameraController == null || // 컨트롤러가 null인지 확인
                !cameraController.value.isInitialized // 컨트롤러가 초기화되었는지 확인
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : Stack(
                children: [
                  // --- 수정된 부분: 카메라 프리뷰 표시 ---
                  Center(
                    child: Icon(
                      Icons.face,
                      size: 200,
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                  // --- 수정 끝 ---

                  // 상태 표시 오버레이
                  Positioned(
                    top: 20,
                    left: 20,
                    right: 20,
                    child: _buildStatusCard(),
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

                  // 중지 버튼
                  Positioned(
                    bottom: 30,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: ElevatedButton(
                        onPressed: () async {
                          await _monitoringService.stopMonitoring();
                          if (mounted) {
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[600],
                          padding: const EdgeInsets.symmetric(
                            horizontal: 50,
                            vertical: 15,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.stop_circle, size: 28),
                            SizedBox(width: 10),
                            Text(
                              '모니터링 종료',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
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
    return Card(
      color: Colors.black.withOpacity(0.7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  '모니터링 중',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatusItem(
                  Icons.visibility,
                  '얼굴 감지',
                  Colors.blue,
                ),
                _buildStatusItem(
                  Icons.warning_amber,
                  '안전 확인',
                  Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '폴링 로직 주기: ${_monitoringService.currentPollingRate}초', // 텍스트 수정
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(IconData icon, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[300],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
