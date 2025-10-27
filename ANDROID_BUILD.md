# Android 빌드 오류 해결 가이드

## 🔧 Gradle 빌드 오류 수정

프로젝트의 Android 설정 파일들이 최신 Flutter Gradle 플러그인 방식으로 업데이트되었습니다.

### 변경된 파일들

```
android/
├── build.gradle                              ✅ 새로 추가
├── settings.gradle                           ✅ 새로 추가
├── gradle.properties                         ✅ 새로 추가
├── gradle/wrapper/gradle-wrapper.properties  ✅ 새로 추가
└── app/
    ├── build.gradle                          ✅ 업데이트
    └── src/main/kotlin/com/safedrive/ai/
        └── MainActivity.kt                   ✅ 새로 추가
```

### 주요 변경 사항

#### 1. Flutter Gradle Plugin 방식 변경

**이전 방식 (더 이상 지원 안 됨):**
```gradle
apply from: "$flutterRoot/packages/flutter_tools/gradle/flutter.gradle"
```

**새로운 방식:**
```gradle
plugins {
    id "dev.flutter.flutter-gradle-plugin"
}
```

#### 2. Gradle 버전 업데이트
- Gradle: 8.7 (Flutter 권장 최소 버전)
- Android Gradle Plugin: 8.6.0 (Flutter 최소 요구)
- Kotlin: 2.1.0 (Flutter 최소 요구)
- Core Library Desugaring: 2.0.4 (flutter_local_notifications 요구사항)

#### 3. compileSdk 명시적 지정
```gradle
android {
    namespace "com.safedrive.ai"
    compileSdk 36  // ← Android SDK 36으로 업그레이드 (플러그인 요구사항)
    
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
        coreLibraryDesugaringEnabled true  // ← Core library desugaring 활성화
    }
    ...
}

dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'
}
```

## 🚀 빌드 방법

### 0. Android SDK 요구사항 ⚠️

**중요**: 이 프로젝트는 Android SDK 36이 필요합니다.

#### SDK 버전
- **compileSdk**: 36 (일부 플러그인 요구사항)
- **targetSdk**: 36
- **minSdk**: 21 (Android 5.0 Lollipop)

#### 왜 SDK 36인가?

다음 플러그인들이 Android SDK 36을 컴파일 요구합니다:
- `camera_android`
- `flutter_plugin_android_lifecycle`
- `geolocator_android`
- `path_provider_android`
- `shared_preferences_android`
- `sqflite_android`

**걱정하지 마세요!** Android SDK는 하위 호환되므로, SDK 36으로 빌드해도 Android 5.0 이상 모든 기기에서 작동합니다.

#### Core Library Desugaring

`flutter_local_notifications`가 요구하는 설정입니다 (이미 설정됨):

```gradle
android {
    compileOptions {
        coreLibraryDesugaringEnabled true
    }
}

dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'
}
```

이 설정은 Java 8+ API를 구형 Android 기기에서도 사용 가능하게 합니다.

### 1. 기존 빌드 캐시 정리

```bash
# Flutter 캐시 정리
flutter clean

# Gradle 캐시 정리 (Windows)
cd android
.\gradlew clean
cd ..

# 또는 (macOS/Linux)
cd android
./gradlew clean
cd ..
```

### 2. 의존성 재설치

```bash
flutter pub get
```

### 3. 빌드 실행

```bash
# 디버그 모드
flutter run

# 또는 Release APK 빌드
flutter build apk --release
```

## ⚠️ 문제 해결

### 오류 1: "flutter.sdk not set in local.properties"

**해결:**
```bash
# Flutter가 자동으로 local.properties 생성
flutter pub get
```

수동으로 생성하려면:
```properties
# android/local.properties
sdk.dir=C:\\Users\\사용자명\\AppData\\Local\\Android\\sdk
flutter.sdk=C:\\src\\flutter
```

### 오류 2: "Gradle sync failed"

**해결:**
```bash
# 1. Gradle wrapper 삭제 후 재생성
rm -rf android/.gradle
rm -rf android/app/.gradle

# 2. Flutter 클린
flutter clean

# 3. 다시 빌드
flutter pub get
flutter run
```

### 오류 3: "Could not resolve all files for configuration"

**해결:**
인터넷 연결 확인 후:
```bash
cd android
./gradlew clean build --refresh-dependencies
cd ..
flutter pub get
```

### 오류 4: "Execution failed for task ':app:checkDebugAarMetadata'"

**증상:**
```
Execution failed for task ':app:checkDebugAarMetadata'.
```

**해결:**
```bash
# android/gradle.properties에 추가 (이미 포함됨)
android.enableJetifier=true
android.useAndroidX=true
```

### 오류 5: "Manifest merger failed"

**증상:**
```
Attribute service@exported value=(false) from (unknown)
is also present at [:flutter_background_service_android] value=(true).
```

**해결:**
이미 수정되어 있습니다! 다음 파일들이 설정됨:

1. `android/app/src/main/AndroidManifest.xml`:
```xml
<manifest xmlns:tools="http://schemas.android.com/tools">
    <service
        android:name="id.flutter.flutter_background_service.BackgroundService"
        android:exported="true"
        tools:replace="android:exported" />
```

2. `android/app/src/debug/AndroidManifest.xml` (자동 생성됨)

---

## 📱 Android Studio에서 빌드

1. **프로젝트 열기**
   - Android Studio에서 `android` 폴더 열기

2. **Gradle 동기화**
   - File → Sync Project with Gradle Files

3. **빌드**
   - Build → Make Project

## 🔍 빌드 로그 확인

상세한 오류 정보를 보려면:

```bash
# 스택 트레이스와 함께 빌드
flutter run --verbose

# 또는 Gradle에서 직접
cd android
./gradlew assembleDebug --stacktrace --info
```

## ✅ 빌드 성공 확인

빌드가 성공하면 다음과 같은 메시지가 나타납니다:

```
✓ Built build/app/outputs/flutter-apk/app-debug.apk
Launching lib/main.dart on sdk gphone64 x86 64 in debug mode...
Running Gradle task 'assembleDebug'...
✓ Built build/app/outputs/flutter-apk/app-debug.apk (57.1MB)
```

## 📋 체크리스트

빌드 전 확인사항:

- [ ] Flutter SDK 설치 완료 (`flutter doctor` 실행)
- [ ] Android SDK 설치 완료
- [ ] Android 기기 또는 에뮬레이터 연결
- [ ] `flutter clean` 실행
- [ ] `flutter pub get` 실행
- [ ] 인터넷 연결 확인 (첫 빌드 시 필요)

## 🛠️ 권장 환경

- **Flutter**: 3.16.0 이상
- **Dart**: 3.2.0 이상
- **Android Studio**: 2023.1 이상
- **Gradle**: 8.7 (Flutter 요구사항)
- **Android Gradle Plugin**: 8.3.0 이상
- **Kotlin**: 1.9.22
- **Java**: JDK 17 이상

## 💡 추가 팁

### Gradle 빌드 속도 향상

`android/gradle.properties`에 다음 추가 (이미 포함됨):
```properties
org.gradle.jvmargs=-Xmx4G
org.gradle.parallel=true
org.gradle.caching=true
```

### 빌드 변형 선택

```bash
# Debug (기본값)
flutter build apk

# Release
flutter build apk --release

# Profile (성능 측정용)
flutter build apk --profile
```

## 🆘 여전히 문제가 있다면

1. **Flutter 업그레이드**
   ```bash
   flutter upgrade
   ```

2. **Android SDK 업데이트**
   - Android Studio → SDK Manager → SDK Tools 업데이트

3. **캐시 완전 삭제**
   ```bash
   flutter clean
   rm -rf android/.gradle
   rm -rf android/app/build
   rm -rf build
   flutter pub get
   ```

4. **프로젝트 재생성**
   ```bash
   # 최후의 수단 (데이터 백업 필수)
   flutter create --org com.safedrive --project-name safedrive_ai .
   ```

---

문제가 지속되면 오류 메시지 전체를 복사해서 검색하거나, Flutter 커뮤니티에 문의하세요.
