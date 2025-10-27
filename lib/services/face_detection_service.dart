import 'dart:typed_data';
import 'package:flutter/material.dart' show Size;
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../models/detection_event.dart';
import '../utils/detection_algorithms.dart';

class FaceDetectionService {
  late FaceDetector _faceDetector;
  bool _isProcessing = false;

  FaceDetectionService() {
    _initializeFaceDetector();
  }

  void _initializeFaceDetector() {
    final options = FaceDetectorOptions(
      enableLandmarks: true,
      enableClassification: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.fast,
    );
    _faceDetector = FaceDetector(options: options);
  }

  Future<Map<String, dynamic>> processImage(CameraImage image) async {
    if (_isProcessing) {
      return {
        'drowsinessLevel': AlertLevel.normal,
        'phoneUsageLevel': AlertLevel.normal,
        'faceDetected': false,
      };
    }

    _isProcessing = true;

    try {
      // CameraImage를 InputImage로 변환
      final inputImage = _convertCameraImage(image);
      
      // 얼굴 감지
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        return {
          'drowsinessLevel': AlertLevel.normal,
          'phoneUsageLevel': AlertLevel.normal,
          'faceDetected': false,
        };
      }

      // 첫 번째 얼굴 사용 (운전자)
      final face = faces.first;

      // 졸음운전 감지
      final drowsinessLevel = DetectionAlgorithms.detectDrowsiness(face);

      // 휴대전화 사용 감지
      final phoneUsageLevel = DetectionAlgorithms.detectPhoneUsage(face);

      return {
        'drowsinessLevel': drowsinessLevel,
        'phoneUsageLevel': phoneUsageLevel,
        'faceDetected': true,
        'headAngleX': face.headEulerAngleX,
        'headAngleY': face.headEulerAngleY,
        'headAngleZ': face.headEulerAngleZ,
      };
    } catch (e) {
      print('Face detection error: $e');
      return {
        'drowsinessLevel': AlertLevel.normal,
        'phoneUsageLevel': AlertLevel.normal,
        'faceDetected': false,
        'error': e.toString(),
      };
    } finally {
      _isProcessing = false;
    }
  }

  InputImage _convertCameraImage(CameraImage image) {
    // CameraImage를 InputImage로 변환하는 로직
    // 실제 구현에서는 이미지 회전 및 포맷 변환 필요
    
    final BytesBuilder allBytes = BytesBuilder();
    for (final Plane plane in image.planes) {
      allBytes.add(plane.bytes);
    }
    final bytes = allBytes.toBytes();

    final imageSize = Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );

    // InputImage 생성
    final inputImageData = InputImageMetadata(
      size: imageSize,
      rotation: InputImageRotation.rotation0deg,
      format: InputImageFormat.nv21,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: inputImageData,
    );
  }

  void dispose() {
    _faceDetector.close();
    DetectionAlgorithms.resetCounters();
  }
}

