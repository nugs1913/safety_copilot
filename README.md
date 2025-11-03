# SafeDrive AI - AI 기반 운전 안전 모니터링 앱

## 📱 프로젝트 소개

SafeDrive AI는 인공지능을 활용하여 운전 중 졸음운전과 휴대전화 사용을 실시간으로 감지하고 경고하는 Flutter 기반 모바일 애플리케이션입니다.

## ✨ 주요 기능

### 1. 실시간 얼굴 감지
- Google ML Kit Face Detection 사용
- 전면 카메라를 통한 지속적인 모니터링
- 백그라운드에서 실행 가능

### 2. 졸음운전 감지
- Eye Aspect Ratio (EAR) 기반 눈 감김 감지
- 고개 각도 분석을 통한 졸음 징후 파악
- 3단계 경고 시스템 (주의 → 경고 → 위험)

### 3. 휴대전화 사용 감지
- 얼굴 각도 분석
- 고개를 숙이고 있는 패턴 감지
- 즉각적인 알림

### 4. GPS 기반 운전 행동 분석 🆕
- **급가속 감지**: 2.5 m/s² 이상
- **급제동 감지**: 3.0 m/s² 이상
- **급회전 감지**: 30°/s 이상
- **실시간 속도 표시**
- **주행 거리 자동 기록**
- **최고/평균 속도 통계**

### 5. 배터리 최적화
- 배터리 레벨에 따른 동적 폴링 레이트 조정
  - 70% 이상: 1초마다
  - 30-70%: 2초마다
  - 30% 이하: 5초마다

### 6. 운전 점수 시스템
- 감지 이벤트 기반 점수 산정
- GPS 행동 분석 포함
- S~F 등급 평가
- 시각적 차트로 추이 확인

### 7. 주행 기록 관리
- SQLite 기반 로컬 데이터베이스
- 상세한 이벤트 로그 (얼굴 + GPS)
- 주행 통계 및 분석
- 이벤트별 위치 정보 저장

## 🛠 기술 스택

- **Framework**: Flutter 3.x
- **언어**: Dart
- **ML**: Google ML Kit (Face Detection)
- **위치**: Geolocator (GPS)
- **데이터베이스**: SQLite
- **상태관리**: Provider
- **차트**: fl_chart
- **알림**: flutter_local_notifications, audioplayers
- **백그라운드**: flutter_background_service

## 📋 시스템 요구사항

- Flutter SDK 3.0 이상
- Android: minSdkVersion 26 (Android 8.0 Oreo) 이상
- Android: compileSdk 36
- iOS: iOS 12.0 이상
- 전면 카메라 필수
- GPS 지원 필수
- 최소 2GB RAM 권장

## 🚀 설치 및 실행

### 1. 저장소 클론
```bash
git clone https://github.com/yourusername/safedrive_ai.git
cd safedrive_ai
```

### 2. 의존성 설치
```bash
flutter pub get
```

### 3. 앱 실행
```bash
# Android
flutter run

# iOS
flutter run
```

### 4. 빌드

```bash
# Android APK (테스트용)
flutter build apk --release --split-per-abi

# Android AAB (Play Store 배포용)
flutter build appbundle --release

# iOS
flutter build ios --release
```

자세한 빌드 및 배포 가이드는 아래 문서를 참조하세요:

- 📘 **[BUILD.md](BUILD.md)**: 빠른 빌드 가이드
- 📗 **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)**: Google Play Store 배포 절차
- 🎨 **[ICON_GUIDE.md](ICON_GUIDE.md)**: 앱 아이콘 적용 방법

## 📁 프로젝트 구조

```
lib/
├── main.dart                      # 앱 진입점
├── models/                        # 데이터 모델
│   ├── driving_session.dart
│   └── detection_event.dart
├── services/                      # 비즈니스 로직
│   ├── background_service.dart    # 백그라운드 모니터링
│   ├── face_detection_service.dart # 얼굴 감지
│   ├── notification_service.dart  # 알림 관리
│   └── database_service.dart      # 데이터베이스
├── screens/                       # UI 화면
│   ├── home_screen.dart
│   ├── monitoring_screen.dart
│   ├── score_screen.dart
│   └── history_screen.dart
└── utils/                         # 유틸리티
    ├── constants.dart
    └── detection_algorithms.dart  # 감지 알고리즘
```

## 🔍 핵심 알고리즘

### Eye Aspect Ratio (EAR)
```dart
EAR = (||p2-p6|| + ||p3-p5||) / (2 * ||p1-p4||)
```
- 눈이 감기면 0에 가까워짐
- 임계값(0.25) 이하일 때 졸음으로 판단

### 운전 점수 계산
```dart
점수 = 100 
     - (졸음 이벤트 수 × 5)
     - (휴대전화 사용 이벤트 수 × 10)
     + (60분 이상 무사고 시 +5)
```

## 📊 데이터베이스 스키마

### sessions 테이블
| 컬럼 | 타입 | 설명 |
|-----|------|------|
| id | INTEGER | 기본키 |
| startTime | TEXT | 시작 시간 |
| endTime | TEXT | 종료 시간 |
| drowsinessEvents | INTEGER | 졸음 이벤트 수 |
| phoneUsageEvents | INTEGER | 휴대전화 사용 이벤트 수 |
| score | REAL | 운전 점수 |
| durationMinutes | INTEGER | 주행 시간(분) |

### events 테이블
| 컬럼 | 타입 | 설명 |
|-----|------|------|
| id | INTEGER | 기본키 |
| sessionId | INTEGER | 세션 외래키 |
| type | TEXT | 이벤트 타입 |
| level | TEXT | 경고 레벨 |
| timestamp | TEXT | 발생 시간 |
| notes | TEXT | 추가 메모 |

## 🔐 권한

앱은 다음 권한이 필요합니다:
- **카메라**: 얼굴 감지를 통한 졸음/휴대전화 사용 감지
- **위치 (GPS)**: 운전 행동 분석 (급가속/급제동/급회전)
- **알림**: 위험 상황 푸시 알림
- **진동**: 긴급 경고 알림

**개인정보 보호:**
- 모든 데이터는 기기 내부에만 저장
- 서버 전송 없음
- 카메라는 얼굴 감지만 사용 (영상 저장 안 함)
- 위치는 운전 행동 분석에만 활용

## 🎯 향후 개발 계획

- [ ] 근처 휴게소/주차장 안내 기능
- [ ] 네비게이션 앱 연동 API
- [ ] 클라우드 데이터 동기화
- [ ] 친구와 점수 비교 (소셜 기능)
- [ ] 음성 경고 기능
- [ ] 다국어 지원
- [ ] 운전 습관 분석 리포트

## 🐛 알려진 이슈

1. **저조도 환경**: 어두운 환경에서 얼굴 감지 정확도 저하
   - 해결방안: 적외선 카메라 지원 또는 보정 알고리즘 개선

2. **배터리 소모**: 장시간 사용 시 배터리 소모
   - 해결방안: 폴링 레이트 최적화 적용 완료

## 📝 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다.

## 👥 기여

기여를 환영합니다! Pull Request를 보내주세요.

## 📧 연락처

문의사항이 있으시면 이슈를 등록해주세요.

## ⚠️ 면책 조항

이 앱은 운전 보조 도구일 뿐, 안전 운전의 책임은 운전자에게 있습니다.
앱 사용 중에도 항상 도로 상황에 주의를 기울여주세요.

---

Made with ❤️ using Flutter
