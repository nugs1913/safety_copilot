import 'package:flutter/material.dart';

class AppConstants {
  // 졸음운전 감지 임계값
  static const double EAR_THRESHOLD = 0.25;
  static const int DROWSY_CONSECUTIVE_FRAMES = 20;
  static const int DROWSY_WARNING_FRAMES = 10;
  static const int DROWSY_CAUTION_FRAMES = 5;
  
  // 휴대전화 사용 감지
  static const double HEAD_DOWN_ANGLE = 20.0;
  static const int PHONE_CONSECUTIVE_FRAMES = 15;
  
  // 배터리 최적화 폴링 레이트 (초)
  static const Map<String, int> POLLING_RATES = {
    'high_battery': 1,    // 70% 이상
    'medium_battery': 2,  // 30-70%
    'low_battery': 5,     // 30% 이하
  };
  
  // 운전 점수 가중치
  static const double DROWSINESS_PENALTY = 5.0;
  static const double PHONE_USAGE_PENALTY = 10.0;
  static const double SAFE_DRIVING_BONUS = 5.0;
  
  // 알림 색상
  static const Map<String, Color> ALERT_COLORS = {
    'normal': Colors.green,
    'caution': Colors.yellow,
    'warning': Colors.orange,
    'danger': Colors.red,
  };
  
  // 알림 소리 파일
  static const Map<String, String> ALERT_SOUNDS = {
    'caution': 'assets/sounds/soft_beep.mp3',
    'warning': 'assets/sounds/medium_alert.mp3',
    'danger': 'assets/sounds/urgent_alarm.mp3',
  };
  
  // 데이터베이스
  static const String DB_NAME = 'safedrive.db';
  static const int DB_VERSION = 1;
}
