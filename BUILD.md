# 빠른 빌드 가이드

## APK 빌드 (테스트용)

```bash
# 1. 의존성 설치
flutter pub get

# 2. APK 빌드
flutter build apk --release --split-per-abi

# 3. 생성된 파일 확인
ls -lh build/app/outputs/flutter-apk/
```

생성되는 파일:
- `app-armeabi-v7a-release.apk` - 32bit 디바이스용
- `app-arm64-v8a-release.apk` - 64bit 디바이스용 (권장)
- `app-x86_64-release.apk` - 에뮬레이터용

## AAB 빌드 (스토어 배포용)

```bash
# 1. 의존성 설치
flutter pub get

# 2. AAB 빌드
flutter build appbundle --release

# 3. 생성된 파일 확인
ls -lh build/app/outputs/bundle/release/
```

생성되는 파일:
- `app-release.aab` - Google Play Store 업로드용

## 빌드 오류 해결

### 캐시 정리 후 재빌드

```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

### Gradle 캐시 정리

```bash
cd android
./gradlew clean
cd ..
flutter build appbundle --release
```

## 서명 정보

- Keystore 파일: `android/safedrive-release-key.jks`
- 설정 파일: `android/key.properties`
- Store Password: `safedrive2024`
- Key Alias: `safedrive`

⚠️ **주의**: 이 정보는 안전하게 보관하세요. 분실 시 앱 업데이트가 불가능합니다.

## 버전 관리

앱 버전은 `pubspec.yaml` 파일에서 관리합니다:

```yaml
version: 1.0.0+1
#        │    │
#        │    └─ 버전 코드 (정수, 증가만 가능)
#        └────── 버전 이름 (사용자에게 표시)
```

업데이트 시 버전 코드를 반드시 증가시켜야 합니다:
```yaml
version: 1.0.1+2  # 다음 업데이트
version: 1.1.0+3  # 기능 추가
version: 2.0.0+4  # 메이저 업데이트
```

## 상세 가이드

전체 배포 절차는 [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)를 참고하세요.
