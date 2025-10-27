# SafeDrive AI - 설치 및 실행 가이드

## 📋 사전 요구사항

1. **Flutter SDK 설치**
   - [Flutter 공식 사이트](https://flutter.dev/docs/get-started/install)에서 설치
   - 버전: Flutter 3.0 이상

2. **개발 환경 설정**
   - Android Studio 또는 VS Code
   - Android SDK (Android 5.0 이상)
   - 실제 Android 기기 (에뮬레이터는 카메라 제한 있음)

## 🚀 빠른 시작

### 1. 프로젝트 설정

```bash
# 1. 압축 해제
unzip safedrive_ai.zip
cd safedrive_ai

# 2. Flutter 패키지 설치
flutter pub get

# 3. Flutter 환경 확인
flutter doctor
```

### 2. 누락된 에셋 추가

프로젝트의 `assets/sounds/` 폴더에 다음 알림음 파일을 추가해야 합니다:

**필수 알림음 파일:**
- `soft_beep.mp3` - 경고 단계 (부드러운 소리)
- `medium_alert.mp3` - 주의 단계 (중간 강도)
- `urgent_alarm.mp3` - 위험 단계 (강한 알림음)

**무료 효과음 다운로드 사이트:**
- [Freesound.org](https://freesound.org/)
- [Zapsplat.com](https://www.zapsplat.com/)
- [Mixkit.co](https://mixkit.co/free-sound-effects/)

**권장 설정:**
- 파일 형식: MP3
- 길이: 1-3초
- 음량: 정규화된 오디오

**또는 임시 파일 생성:**
```bash
# assets/sounds 폴더에 더미 파일 생성 (테스트용)
mkdir -p assets/sounds
touch assets/sounds/soft_beep.mp3
touch assets/sounds/medium_alert.mp3
touch assets/sounds/urgent_alarm.mp3
```

### 3. Android 기기 연결

```bash
# 연결된 기기 확인
adb devices

# USB 디버깅 활성화
# 설정 > 개발자 옵션 > USB 디버깅 켜기
```

### 4. 앱 실행

```bash
# 디버그 모드로 실행
flutter run

# 또는 특정 기기 선택
flutter run -d <device-id>
```

### 5. Release 빌드 (선택사항)

```bash
# APK 빌드
flutter build apk --release

# 빌드된 APK 위치:
# build/app/outputs/flutter-apk/app-release.apk
```

## 🔧 문제 해결

### 문제 1: "SDK location not found"
```bash
# Android SDK 경로 설정
# local.properties 파일 생성 (android/ 폴더)
sdk.dir=/Users/사용자명/Library/Android/sdk  # macOS
sdk.dir=C:\\Users\\사용자명\\AppData\\Local\\Android\\sdk  # Windows
```

### 문제 2: Gradle 빌드 오류
```bash
# Gradle 캐시 정리
cd android
./gradlew clean

# 다시 빌드
cd ..
flutter pub get
flutter run
```

### 문제 3: 권한 오류
```bash
# AndroidManifest.xml이 올바르게 설정되었는지 확인
# 앱 실행 후 권한 요청 허용
```

### 문제 4: 카메라 감지 안됨
```bash
# 실제 기기에서 테스트 (에뮬레이터 X)
# 전면 카메라가 있는 기기 사용
# 권한이 허용되었는지 확인
```

## 📱 첫 실행

1. **권한 허용**
   - 카메라 권한 허용
   - 알림 권한 허용

2. **모니터링 시작**
   - 홈 화면에서 "모니터링 시작" 버튼 클릭
   - 전면 카메라가 얼굴을 감지할 수 있도록 위치 조정

3. **테스트**
   - 눈을 감아서 졸음 감지 테스트
   - 고개를 숙여서 휴대전화 사용 감지 테스트

## 🎨 커스터마이징

### 감지 임계값 조정
`lib/utils/constants.dart` 파일에서 수정:

```dart
// 졸음운전 감지 민감도
static const double EAR_THRESHOLD = 0.25;  // 낮을수록 민감

// 연속 프레임 수
static const int DROWSY_CONSECUTIVE_FRAMES = 20;  // 높을수록 덜 민감
```

### 폴링 레이트 조정
```dart
static const Map<String, int> POLLING_RATES = {
  'high_battery': 1,    // 초 단위
  'medium_battery': 2,
  'low_battery': 5,
};
```

### 점수 가중치 조정
```dart
static const double DROWSINESS_PENALTY = 5.0;      // 졸음 감점
static const double PHONE_USAGE_PENALTY = 10.0;    // 휴대전화 감점
```

## 📊 데이터 위치

앱 데이터는 로컬에 저장됩니다:
- **Android**: `/data/data/com.safedrive.ai/databases/safedrive.db`
- **데이터베이스**: SQLite

## 🐛 디버깅 팁

```bash
# 로그 확인
flutter logs

# 특정 기기 로그
adb logcat | grep flutter

# 앱 재설치 (데이터 초기화)
flutter clean
flutter pub get
flutter run
```

## 📞 도움말

- **Flutter 문제**: [Flutter 공식 문서](https://flutter.dev/docs)
- **ML Kit 문제**: [Google ML Kit 문서](https://developers.google.com/ml-kit)
- **이슈 등록**: GitHub Issues

## ⚠️ 중요 참고사항

1. **실제 기기 필수**: 에뮬레이터에서는 카메라 기능이 제한적입니다
2. **전면 카메라**: 얼굴 감지를 위해 전면 카메라 필요
3. **배터리**: 장시간 사용 시 배터리 소모 주의
4. **안전**: 실제 운전 중 테스트 시 안전 최우선

## ✅ 체크리스트

설치 완료 전 확인사항:
- [ ] Flutter SDK 설치 완료
- [ ] `flutter doctor` 실행하여 환경 확인
- [ ] 알림음 파일 3개 추가 완료
- [ ] Android 기기 연결 및 USB 디버깅 활성화
- [ ] 앱 실행 성공
- [ ] 권한 허용 완료
- [ ] 카메라 얼굴 감지 확인

---

설치 중 문제가 발생하면 위의 문제 해결 섹션을 참고하세요!
