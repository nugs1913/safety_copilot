# 빠른 오류 수정 가이드

이 문서는 프로젝트에서 발생할 수 있는 일반적인 경고 및 오류를 해결하는 방법을 안내합니다.

## ✅ 이미 수정된 오류들

다음 오류들은 최신 버전에서 수정되었습니다:

1. ✅ `Color` 클래스를 찾을 수 없음 → `flutter/material.dart` import 추가
2. ✅ `WriteBuffer` 클래스를 찾을 수 없음 → `dart:typed_data` import 추가
3. ✅ `CardTheme` 타입 오류 → `CardThemeData`로 수정
4. ✅ `path` 패키지 의존성 누락 → pubspec.yaml에 추가
5. ✅ assets 디렉토리 없음 → 폴더 및 더미 파일 생성
6. ✅ 사용하지 않는 import 제거

## ⚠️ 남아있는 경고 (무시 가능)

다음은 앱 실행에 영향을 주지 않는 경고들입니다:

### 1. `use_super_parameters` (정보)
```dart
// 경고:
const HomeScreen({Key? key}) : super(key: key);

// 권장 (선택사항):
const HomeScreen({super.key});
```
**영향**: 없음. 코드 스타일 제안일 뿐입니다.

### 2. `use_build_context_synchronously` (정보)
```dart
// 경고가 나는 경우:
await someAsyncFunction();
Navigator.push(context, ...);  // BuildContext 사용

// 권장 수정:
await someAsyncFunction();
if (mounted) {
  Navigator.push(context, ...);
}
```
**영향**: 이미 주요 부분에 `mounted` 체크 추가됨.

### 3. `deprecated_member_use` - `withOpacity`
```dart
// 경고:
Colors.blue.withOpacity(0.5)

// 권장 (선택사항):
Colors.blue.withValues(alpha: 0.5)
```
**영향**: 없음. `withOpacity`는 여전히 작동합니다.

## 🔧 추가 설정이 필요한 사항

### 1. 실제 알림음 파일 추가

현재 더미 파일이 있지만, 실제 소리가 나지 않습니다.

```bash
# 다음 사이트에서 무료 알림음 다운로드
# - https://freesound.org/
# - https://zapsplat.com/
# - https://mixkit.co/

# 다운로드한 파일을 다음 위치에 복사
assets/sounds/soft_beep.mp3      # 경고음
assets/sounds/medium_alert.mp3   # 주의음
assets/sounds/urgent_alarm.mp3   # 위험음
```

### 2. Android 아이콘 추가 (선택사항)

기본 Flutter 아이콘이 사용됩니다. 커스텀 아이콘을 원하면:

```bash
# Android 아이콘 위치
android/app/src/main/res/
  ├── mipmap-hdpi/ic_launcher.png
  ├── mipmap-mdpi/ic_launcher.png
  ├── mipmap-xhdpi/ic_launcher.png
  ├── mipmap-xxhdpi/ic_launcher.png
  └── mipmap-xxxhdpi/ic_launcher.png
```

## 📱 실행 전 체크리스트

```bash
# 1. 의존성 설치
flutter pub get

# 2. 환경 확인
flutter doctor

# 3. 코드 분석 (선택사항)
flutter analyze

# 4. 실행
flutter run
```

## 🐛 자주 발생하는 문제

### 문제 1: Gradle 동기화 실패

**증상**: "Could not resolve..." 또는 "Sync failed"

**해결**:
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

### 문제 2: 카메라 권한 오류

**증상**: "Camera permission denied"

**해결**:
1. 앱 설정에서 카메라 권한 허용
2. 앱 재시작

### 문제 3: ML Kit 초기화 실패

**증상**: "Face detection failed"

**해결**:
1. 실제 기기 사용 (에뮬레이터 비추천)
2. Google Play Services 최신 버전 확인
3. 인터넷 연결 확인 (최초 실행 시 모델 다운로드)

### 문제 4: 빌드 오류 - "Execution failed for task"

**해결**:
```bash
# 1. Flutter 캐시 정리
flutter clean
flutter pub get

# 2. Gradle 캐시 정리
cd android
./gradlew clean
./gradlew build --refresh-dependencies

# 3. Android Studio에서 "Invalidate Caches / Restart"
```

## 📊 성능 최적화 팁

### 1. 배터리 소모 줄이기

`lib/utils/constants.dart`에서 폴링 레이트 조정:

```dart
static const Map<String, int> POLLING_RATES = {
  'high_battery': 2,    // 1초 → 2초로 변경
  'medium_battery': 3,  // 2초 → 3초로 변경
  'low_battery': 5,     // 그대로 유지
};
```

### 2. 감지 민감도 조정

졸음 감지가 너무 민감하거나 둔감한 경우:

```dart
// 더 민감하게 (더 자주 경고)
static const double EAR_THRESHOLD = 0.30;
static const int DROWSY_CONSECUTIVE_FRAMES = 15;

// 덜 민감하게 (덜 자주 경고)
static const double EAR_THRESHOLD = 0.20;
static const int DROWSY_CONSECUTIVE_FRAMES = 25;
```

## 🔍 디버깅 명령어

```bash
# 실시간 로그 확인
flutter logs

# 특정 기기 로그
flutter logs -d <device-id>

# adb 로그캣
adb logcat | grep -i flutter

# 앱 성능 프로파일링
flutter run --profile
```

## ✨ 추천 VS Code 확장 프로그램

- **Dart**: 필수
- **Flutter**: 필수
- **Flutter Widget Snippets**: 생산성 향상
- **Error Lens**: 인라인 오류 표시
- **Pubspec Assist**: 패키지 관리

## 🎓 추가 학습 리소스

- [Flutter 공식 문서](https://docs.flutter.dev/)
- [Dart 언어 가이드](https://dart.dev/guides)
- [Google ML Kit 문서](https://developers.google.com/ml-kit)
- [Flutter 커뮤니티](https://flutter.dev/community)

---

**참고**: 대부분의 경고는 코드 품질 개선을 위한 제안이며, 앱 실행에는 영향을 주지 않습니다.
