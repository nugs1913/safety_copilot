# 🚀 SafeDrive AI - 빠른 시작 가이드

## ⚡ 5분 안에 실행하기

### 1단계: 압축 해제
```bash
unzip safedrive_ai_v1.0_final.zip
cd safedrive_ai
```

### 2단계: Flutter 환경 확인
```bash
flutter doctor
```

**필수 체크사항:**
- ✅ Flutter SDK 설치됨
- ✅ Android toolchain 설치됨
- ✅ Android Studio 또는 VS Code 설치됨
- ✅ 연결된 기기 또는 에뮬레이터

### 3단계: 캐시 정리 (첫 빌드 시)
```bash
flutter clean
```

### 4단계: 의존성 설치
```bash
flutter pub get
```

### 5단계: 실행!
```bash
flutter run
```

---

## ⚠️ 빌드 전 필수 확인사항

### Android SDK 36 필요 ⭐

이 프로젝트는 **Android SDK 36**을 요구합니다.

**이유**: 다음 플러그인들이 SDK 36 컴파일을 요구합니다
- camera_android
- geolocator_android
- sqflite_android
- 기타 5개 플러그인

**걱정 마세요!** SDK 36으로 빌드해도 Android 5.0(API 21) 이상 모든 기기에서 작동합니다.

### Android SDK 설치 확인

**Android Studio에서:**
1. Tools → SDK Manager 열기
2. SDK Platforms 탭에서 "Android 15.0 (VanillaIceCream)" 확인
3. 없으면 설치

**또는 명령어로:**
```bash
sdkmanager --list | grep "system-images;android-36"
```

### JDK 17 이상 필요

```bash
java -version
# java version "17.0.x" 이상 확인
```

JDK 17 미만이면:
- [Oracle JDK 17](https://www.oracle.com/java/technologies/javase/jdk17-archive-downloads.html)
- 또는 [OpenJDK 17](https://adoptium.net/)

---

## 🎯 빌드 타입별 명령어

### 디버그 모드 (개발용)
```bash
flutter run
# 또는
flutter run -d <device-id>
```

### Release APK (배포용)
```bash
flutter build apk --release
# 출력: build/app/outputs/flutter-apk/app-release.apk
```

### App Bundle (Google Play 배포용)
```bash
flutter build appbundle --release
# 출력: build/app/outputs/bundle/release/app-release.aab
```

---

## 🐛 일반적인 오류와 해결방법

### 오류 1: "requires compileSdk 36"

**증상:**
```
plugin requires to be compiled against Android SDK 36
```

**해결:**
이미 수정되어 있습니다! `android/app/build.gradle`에 `compileSdk 36` 설정됨.

만약 문제가 계속되면:
```bash
flutter clean
flutter pub get
```

---

### 오류 2: "core library desugaring"

**증상:**
```
Dependency requires core library desugaring to be enabled
```

**해결:**
이미 설정되어 있습니다! 다음 내용이 `android/app/build.gradle`에 있습니다:
```gradle
compileOptions {
    coreLibraryDesugaringEnabled true
}

dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'
}
```

---

### 오류 3: Gradle 동기화 실패

**해결:**
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run
```

---

### 오류 4: "SDK location not found"

**해결:**
```bash
flutter pub get  # local.properties 자동 생성
```

수동으로 생성하려면 `android/local.properties`:
```properties
sdk.dir=C:\\Users\\사용자명\\AppData\\Local\\Android\\sdk
flutter.sdk=C:\\src\\flutter
```

---

### 오류 5: 권한 오류

**증상:**
앱 실행 후 "Permission denied"

**해결:**
1. 앱 설정 열기
2. 권한 → 카메라 허용
3. 권한 → 알림 허용
4. 앱 재시작

---

## 📱 기기별 테스트 가이드

### 실제 Android 기기 (권장)

1. **USB 디버깅 활성화**
   - 설정 → 휴대전화 정보 → 빌드 번호 7번 탭
   - 설정 → 개발자 옵션 → USB 디버깅 켜기

2. **기기 연결 확인**
   ```bash
   adb devices
   # 기기가 보이는지 확인
   ```

3. **실행**
   ```bash
   flutter run
   ```

### Android 에뮬레이터

**⚠️ 주의**: 카메라 기능이 제한적입니다.

1. **에뮬레이터 생성**
   - Android Studio → Device Manager
   - Create Device → Pixel 6 이상 권장
   - API 34 이상 선택

2. **카메라 설정**
   - Advanced Settings → Camera
   - Front: Webcam 선택 (실제 웹캠 필요)

3. **실행**
   ```bash
   flutter run
   ```

---

## 🎨 첫 실행 후 해야 할 일

### 1. 알림음 추가 (중요!)

현재 더미 파일만 있어서 소리가 나지 않습니다.

**무료 효과음 다운로드:**
- [Freesound.org](https://freesound.org/)
- [Zapsplat.com](https://www.zapsplat.com/)
- [Mixkit.co](https://mixkit.co/)

**파일 교체:**
```
assets/sounds/
├── soft_beep.mp3      (부드러운 경고음, 1-2초)
├── medium_alert.mp3   (중간 강도 경고음, 2-3초)
└── urgent_alarm.mp3   (긴급 알람, 2-4초)
```

다운로드한 파일을 위 경로에 복사 → 앱 재빌드

### 2. 권한 허용

첫 실행 시 다음 권한 허용:
- ✅ 카메라
- ✅ 알림

### 3. 기능 테스트

1. **모니터링 시작** 버튼 클릭
2. 전면 카메라가 얼굴을 감지하는지 확인
3. 눈 감아서 졸음 감지 테스트
4. 고개 숙여서 휴대전화 사용 감지 테스트

---

## 📊 성능 최적화 팁

### 배터리 소모 줄이기

`lib/utils/constants.dart` 수정:
```dart
static const Map<String, int> POLLING_RATES = {
  'high_battery': 2,    // 1→2초 (배터리 절약)
  'medium_battery': 3,  // 2→3초
  'low_battery': 5,     // 유지
};
```

### 감지 민감도 조정

졸음 감지가 너무 민감하다면:
```dart
static const double EAR_THRESHOLD = 0.20;  // 0.25→0.20
static const int DROWSY_CONSECUTIVE_FRAMES = 25;  // 20→25
```

---

## 📚 추가 문서

자세한 정보는 다음 문서를 참고하세요:

- **README.md** - 프로젝트 개요
- **INSTALL.md** - 상세 설치 가이드
- **ANDROID_BUILD.md** - Android 빌드 문제 해결
- **TROUBLESHOOTING.md** - 일반 문제 해결
- **VERSION.md** - 버전 정보 및 체인지로그

---

## ✅ 체크리스트

빌드 전 확인:
- [ ] Flutter SDK 설치 (`flutter --version`)
- [ ] Android SDK 36 설치
- [ ] JDK 17 이상 설치
- [ ] Android 기기 연결 (또는 에뮬레이터)
- [ ] USB 디버깅 활성화
- [ ] `flutter pub get` 실행 완료
- [ ] 인터넷 연결 확인 (첫 빌드 시)

---

## 🎉 완료!

모든 설정이 완료되었습니다. 이제 앱을 실행해보세요!

```bash
flutter run
```

문제가 있나요? **TROUBLESHOOTING.md** 또는 **ANDROID_BUILD.md**를 확인하세요.

**안전 운전하세요!** 🚗💨
