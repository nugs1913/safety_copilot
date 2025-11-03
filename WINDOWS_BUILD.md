# Windows 환경 빌드 가이드

## 🔐 Keystore 생성 (Windows)

Windows 환경에서 앱을 빌드하려면 Keystore를 생성해야 합니다.

### Step 1: Keystore 생성

**명령 프롬프트(CMD) 또는 PowerShell에서 실행:**

```cmd
cd C:\code\Car\safety_copilot\android

keytool -genkey -v -keystore safedrive-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias safedrive
```

**입력 정보:**
- Keystore 비밀번호: `safedrive2024`
- Key 비밀번호: `safedrive2024`
- 이름: SafeDrive AI
- 조직: SafeDrive
- 도시: Seoul
- 국가: KR

**또는 자동 생성 (한 줄 명령어):**

```cmd
cd C:\code\Car\safety_copilot\android

keytool -genkey -v -keystore safedrive-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias safedrive -storepass safedrive2024 -keypass safedrive2024 -dname "CN=SafeDrive AI, OU=Development, O=SafeDrive, L=Seoul, ST=Seoul, C=KR"
```

### Step 2: key.properties 파일 확인/생성

`android/key.properties` 파일이 있는지 확인하고, 없으면 생성:

**파일 위치:** `C:\code\Car\safety_copilot\android\key.properties`

**내용:**
```properties
storePassword=safedrive2024
keyPassword=safedrive2024
keyAlias=safedrive
storeFile=safedrive-release-key.jks
```

### Step 3: 파일 확인

```cmd
dir C:\code\Car\safety_copilot\android\safedrive-release-key.jks
dir C:\code\Car\safety_copilot\android\key.properties
```

두 파일이 모두 존재해야 합니다.

---

## 🚀 빌드 실행

### 정상 빌드

```cmd
cd C:\code\Car\safety_copilot

flutter clean
flutter pub get
flutter build appbundle --release
```

### 빌드 성공 시

생성 위치:
```
C:\code\Car\safety_copilot\build\app\outputs\bundle\release\app-release.aab
```

---

## 🔧 문제 해결

### 1. "keytool is not recognized" 오류

Java가 설치되어 있지 않거나 PATH에 없는 경우입니다.

**해결방법:**

1. **Java 설치 확인:**
   ```cmd
   java -version
   ```

2. **Android Studio의 Java 사용:**
   ```cmd
   set JAVA_HOME=C:\Program Files\Android\Android Studio\jbdk
   set PATH=%JAVA_HOME%\bin;%PATH%
   ```

3. **다시 keytool 실행:**
   ```cmd
   keytool -version
   ```

### 2. "Keystore file not found" 오류

**원인:** key.properties의 경로가 잘못되었습니다.

**해결방법:**

`android/key.properties` 파일을 열어 다음을 확인:

```properties
storeFile=safedrive-release-key.jks
```

**또는 절대 경로 사용:**

```properties
storeFile=C:/code/Car/safety_copilot/android/safedrive-release-key.jks
```

⚠️ **주의:** Windows에서도 슬래시(/)를 사용하거나, 백슬래시를 두 번(\\) 사용해야 합니다.

### 3. R8 Minification 오류

이미 ProGuard 규칙이 추가되어 있습니다. 그래도 오류가 발생하면:

**임시 해결 (테스트용):**

`android/app/build.gradle` 파일에서:

```gradle
buildTypes {
    release {
        signingConfig signingConfigs.release
        minifyEnabled false  // 임시로 비활성화
        shrinkResources false
        // proguardFiles 줄 주석 처리
    }
}
```

⚠️ **주의:** 최종 배포 시에는 다시 활성화하는 것을 권장합니다.

---

## 📋 빌드 전 체크리스트

- [ ] Java 설치 확인 (`java -version`)
- [ ] Flutter 설치 확인 (`flutter --version`)
- [ ] Keystore 파일 존재 (`android/safedrive-release-key.jks`)
- [ ] key.properties 파일 존재 (`android/key.properties`)
- [ ] 의존성 설치 완료 (`flutter pub get`)

---

## 🎯 빠른 전체 절차

```cmd
# 1. Keystore 생성
cd C:\code\Car\safety_copilot\android
keytool -genkey -v -keystore safedrive-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias safedrive -storepass safedrive2024 -keypass safedrive2024 -dname "CN=SafeDrive AI, OU=Development, O=SafeDrive, L=Seoul, ST=Seoul, C=KR"

# 2. key.properties 파일 확인 (없으면 메모장으로 생성)
notepad key.properties

# 3. 빌드
cd C:\code\Car\safety_copilot
flutter clean
flutter pub get
flutter build appbundle --release
```

---

## 📞 추가 도움

더 자세한 내용은 다음 문서 참조:
- [BUILD.md](../BUILD.md): 빌드 가이드
- [DEPLOYMENT_GUIDE.md](../DEPLOYMENT_GUIDE.md): 배포 가이드

---

**작성일**: 2025-01-03
