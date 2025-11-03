import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../models/detection_event.dart';
import 'constants.dart';

class DetectionAlgorithms {
  static int _drowsyFrameCount = 0;
  static int _phoneUsageFrameCount = 0;

  // /// Eye Aspect Ratio (EAR) 계산
  // /// Google ML Kit의 눈 개폐 확률을 활용하여 EAR 추정
  // static double calculateEAR(Face face) {
  //   // Google ML Kit은 눈의 개폐 확률을 제공합니다
  //   // leftEyeOpenProbability: 0.0 (감음) ~ 1.0 (뜸)
  //   final leftEyeOpen = face.leftEyeOpenProbability;
  //   final rightEyeOpen = face.rightEyeOpenProbability;

  //   if (leftEyeOpen == null || rightEyeOpen == null) {
  //     return 1.0; // 눈을 감지하지 못한 경우 정상으로 간주
  //   }

  //   // 개폐 확률을 EAR 스케일로 변환
  //   // 확률이 높을수록 (눈이 떠있을수록) EAR도 높아야 함
  //   // 확률 0.0 (감음) -> EAR ~0.0
  //   // 확률 1.0 (뜸) -> EAR ~0.4
  //   final leftEAR = leftEyeOpen * 0.4;
  //   final rightEAR = rightEyeOpen * 0.4;

  //   // 양쪽 눈 평균
  //   return (leftEAR + rightEAR) / 2.0;
  // }

  /// 졸음운전 감지
  static AlertLevel detectDrowsiness(Face face) {
    final double leftEyeOpen = face.leftEyeOpenProbability ?? 1.0;
    final double rightEyeOpen = face.rightEyeOpenProbability ?? 1.0;
    final headAngle = face.headEulerAngleX ?? 0.0;

    const double eyeOpenThreshold = 0.4;
    bool eyesClosed =
        rightEyeOpen < eyeOpenThreshold && leftEyeOpen < eyeOpenThreshold;

    if (eyesClosed) {
      _drowsyFrameCount++;
    } else {
      // --- 수정된 부분: 카운터가 더 빨리 감소하여 반응성 향상 ---
      _drowsyFrameCount = max(0, _drowsyFrameCount - 1);
      // --- 수정 끝 ---
    }

    if (headAngle > 15.0) {
      _drowsyFrameCount += 2;
    }

    if (_drowsyFrameCount >= AppConstants.DROWSY_CONSECUTIVE_FRAMES * 2) {
      return AlertLevel.danger;
    } else if (_drowsyFrameCount >= AppConstants.DROWSY_CONSECUTIVE_FRAMES) {
      return AlertLevel.warning;
    } else if (_drowsyFrameCount >= AppConstants.DROWSY_WARNING_FRAMES) {
      return AlertLevel.caution;
    }

    return AlertLevel.normal;
  }

  /// 휴대전화 사용 감지
  /// 얼굴이 아래를 보고 있는지 확인
  static AlertLevel detectPhoneUsage(Face face) {
    final headAngleX = face.headEulerAngleX ?? 0.0;
    const double headDownAngleThreshold = 20.0;
    bool lookingDown = headAngleX > headDownAngleThreshold;

    if (lookingDown) {
      _phoneUsageFrameCount++;
    } else {
      // --- 수정된 부분: 카운터가 더 빨리 감소하여 반응성 향상 ---
      _phoneUsageFrameCount = max(0, _phoneUsageFrameCount - 1);
      // --- 수정 끝 ---
    }

    if (_phoneUsageFrameCount >= AppConstants.PHONE_CONSECUTIVE_FRAMES * 2) {
      return AlertLevel.danger;
    } else if (_phoneUsageFrameCount >= AppConstants.PHONE_CONSECUTIVE_FRAMES) {
      return AlertLevel.warning;
    } else if (_phoneUsageFrameCount >=
        AppConstants.PHONE_CONSECUTIVE_FRAMES ~/ 2) {
      return AlertLevel.caution;
    }

    return AlertLevel.normal;
  }

  /// 카운터 리셋
  static void resetCounters() {
    _drowsyFrameCount = 0;
    _phoneUsageFrameCount = 0;
  }

  /// 현재 프레임 카운트 가져오기 (디버깅용)
  static Map<String, int> getFrameCounts() {
    return {
      'drowsy': _drowsyFrameCount,
      'phone': _phoneUsageFrameCount,
    };
  }

  /// 운전 점수 계산
  static double calculateDrivingScore({
    required int drowsinessEvents,
    required int phoneUsageEvents,
    required int durationMinutes,
  }) {
    double score = 100.0;

    // 졸음운전 감지 횟수 감점
    score -= drowsinessEvents * AppConstants.DROWSINESS_PENALTY;

    // 휴대전화 사용 감지 횟수 감점
    score -= phoneUsageEvents * AppConstants.PHONE_USAGE_PENALTY;

    // 장시간 안전 운전 보너스 (60분 이상, 위반 사항 없음)
    if (durationMinutes >= 60 &&
        drowsinessEvents == 0 &&
        phoneUsageEvents == 0) {
      score += AppConstants.SAFE_DRIVING_BONUS;
    }

    // 점수 범위 제한 (0-100)
    return score.clamp(0.0, 100.0);
  }

  /// 점수에 따른 등급 반환
  static String getScoreGrade(double score) {
    if (score >= 90) return 'S';
    if (score >= 80) return 'A';
    if (score >= 70) return 'B';
    if (score >= 60) return 'C';
    if (score >= 50) return 'D';
    return 'F';
  }

  /// 등급에 따른 색상
  static Color getGradeColor(String grade) {
    switch (grade) {
      case 'S':
        return const Color(0xFFFFD700); // Gold
      case 'A':
        return const Color(0xFF4CAF50); // Green
      case 'B':
        return const Color(0xFF2196F3); // Blue
      case 'C':
        return const Color(0xFFFFC107); // Amber
      case 'D':
        return const Color(0xFFFF9800); // Orange
      case 'F':
        return const Color(0xFFF44336); // Red
      default:
        return const Color(0xFF9E9E9E); // Grey
    }
  }
}
