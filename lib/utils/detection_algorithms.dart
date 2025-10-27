import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../models/detection_event.dart';
import 'constants.dart';

class DetectionAlgorithms {
  static int _drowsyFrameCount = 0;
  static int _phoneUsageFrameCount = 0;

  /// Eye Aspect Ratio (EAR) 계산
  /// 눈이 감기면 0에 가까워짐
  static double calculateEAR(Face face) {
    final leftEye = face.landmarks[FaceLandmarkType.leftEye];
    final rightEye = face.landmarks[FaceLandmarkType.rightEye];

    if (leftEye == null || rightEye == null) {
      return 1.0; // 눈을 감지하지 못한 경우 정상으로 간주
    }

    // 왼쪽 눈 EAR
    final leftEAR = _calculateSingleEyeEAR(leftEye.position);
    // 오른쪽 눈 EAR
    final rightEAR = _calculateSingleEyeEAR(rightEye.position);

    // 양쪽 눈 평균
    return (leftEAR + rightEAR) / 2.0;
  }

  static double _calculateSingleEyeEAR(Point<int> eyeCenter) {
    // 실제 구현에서는 눈의 6개 랜드마크 포인트를 사용해야 함
    // 여기서는 간단히 추정값 반환
    // 실제로는 MediaPipe나 더 정교한 모델 필요
    return 0.3; // placeholder
  }

  /// 졸음운전 감지
  static AlertLevel detectDrowsiness(Face face) {
    final ear = calculateEAR(face);
    final headAngle = face.headEulerAngleX ?? 0.0;

    // EAR이 임계값 이하면 눈을 감은 것으로 판단
    if (ear < AppConstants.EAR_THRESHOLD) {
      _drowsyFrameCount++;
    } else {
      _drowsyFrameCount = max(0, _drowsyFrameCount - 1); // 천천히 감소
    }

    // 고개가 앞으로 15도 이상 숙여진 경우 (졸음 징후)
    if (headAngle > 15) {
      _drowsyFrameCount += 2; // 가중치 추가
    }

    // 연속 프레임 체크에 따른 경고 레벨 반환
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
    final headAngleX = face.headEulerAngleX ?? 0.0; // 위아래 각도
    final headAngleY = face.headEulerAngleY ?? 0.0; // 좌우 각도

    // 고개가 아래로 20도 이상 숙여진 경우
    bool lookingDown = headAngleX > AppConstants.HEAD_DOWN_ANGLE;
    
    // 얼굴이 정면이 아닌 경우 (휴대전화를 보는 각도)
    bool notFacingForward = headAngleY.abs() > 10;

    if (lookingDown && notFacingForward) {
      _phoneUsageFrameCount++;
    } else {
      _phoneUsageFrameCount = max(0, _phoneUsageFrameCount - 1);
    }

    // 연속 프레임 체크
    if (_phoneUsageFrameCount >= AppConstants.PHONE_CONSECUTIVE_FRAMES * 2) {
      return AlertLevel.danger;
    } else if (_phoneUsageFrameCount >= AppConstants.PHONE_CONSECUTIVE_FRAMES) {
      return AlertLevel.warning;
    } else if (_phoneUsageFrameCount >= AppConstants.PHONE_CONSECUTIVE_FRAMES ~/ 2) {
      return AlertLevel.caution;
    }

    return AlertLevel.normal;
  }

  /// 카운터 리셋
  static void resetCounters() {
    _drowsyFrameCount = 0;
    _phoneUsageFrameCount = 0;
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
