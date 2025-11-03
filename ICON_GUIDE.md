# 앱 아이콘 적용 가이드

## 📱 앱 아이콘 준비

SafeDrive AI 앱의 아이콘을 적용하는 방법입니다.

---

## 1️⃣ 아이콘 파일 준비

### 권장 사양

- **해상도**: 1024 x 1024 픽셀 (최소)
- **형식**: PNG (투명 배경 권장)
- **파일 위치**: `assets/icon/icon.png`
- **디자인**:
  - 둥근 모서리는 자동으로 처리됨
  - 중요한 요소는 중앙에 배치
  - 가장자리 100px 여백 권장

### 디자인 팁

✅ **권장사항:**
- 단순하고 명확한 디자인
- 고대비 색상 사용
- 작은 크기에서도 인식 가능한 형태
- 앱의 정체성을 나타내는 심볼

❌ **피해야 할 것:**
- 너무 복잡한 디테일
- 작은 텍스트
- 얇은 선
- 너무 많은 색상

### SafeDrive AI 추천 디자인 요소

- 🚗 자동차 심볼
- 👁️ 눈 또는 시선 추적
- 🛡️ 방패 (안전)
- 📍 GPS 핀
- 💚 녹색 계열 (안전, 친환경)

---

## 2️⃣ 아이콘 파일 배치

아이콘 파일을 준비했다면:

```bash
# 1. 아이콘 파일을 지정된 위치에 복사
cp /path/to/your/icon.png assets/icon/icon.png

# 2. 파일 확인
ls -lh assets/icon/icon.png
```

---

## 3️⃣ 아이콘 생성

### Step 1: 패키지 설치

```bash
flutter pub get
```

### Step 2: 아이콘 생성 실행

```bash
flutter pub run flutter_launcher_icons
```

### 예상 출력:

```
Creating icons for platforms: android, ios

Android: Building adaptive icons
Foreground: assets/icon/icon.png
Background: #FFFFFF

Android: Building standard icons

iOS: Generating icons...

✓ Successfully generated launcher icons
```

---

## 4️⃣ 생성된 아이콘 확인

### Android

생성된 아이콘 위치:
```
android/app/src/main/res/
├── mipmap-hdpi/
├── mipmap-mdpi/
├── mipmap-xhdpi/
├── mipmap-xxhdpi/
└── mipmap-xxxhdpi/
```

### iOS (선택사항)

생성된 아이콘 위치:
```
ios/Runner/Assets.xcassets/AppIcon.appiconset/
```

---

## 5️⃣ 앱 테스트

### 디버그 빌드로 확인

```bash
# Android
flutter run

# 앱을 빌드하고 설치한 후 홈 화면에서 아이콘 확인
```

### 아이콘이 적용되지 않는 경우

```bash
# 1. 앱 완전히 삭제
# 2. 캐시 정리
flutter clean

# 3. 다시 설치
flutter run
```

---

## 6️⃣ Release 빌드

아이콘 확인이 완료되면 Release 빌드:

```bash
# AAB (Play Store용)
flutter build appbundle --release

# APK (테스트용)
flutter build apk --release --split-per-abi
```

---

## 🎨 다양한 아이콘 설정 (고급)

### 배경색 변경

`pubspec.yaml`에서:

```yaml
flutter_launcher_icons:
  adaptive_icon_background: "#4CAF50"  # 녹색 배경
```

### Foreground 전용 아이콘 사용

투명 배경의 아이콘을 사용하는 경우:

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon/icon.png"

  # Adaptive Icon (Android 8.0+)
  adaptive_icon_background: "#FFFFFF"
  adaptive_icon_foreground: "assets/icon/icon_foreground.png"
```

### iOS 전용 아이콘

Android와 iOS에 다른 아이콘 사용:

```yaml
flutter_launcher_icons:
  android: "launcher_icon"
  ios: true
  image_path_android: "assets/icon/android_icon.png"
  image_path_ios: "assets/icon/ios_icon.png"
```

---

## 🔧 문제 해결

### 1. 아이콘이 깨져 보이는 경우

**원인**: 해상도가 낮음

**해결**:
- 최소 1024x1024 PNG 사용
- 고해상도 원본 파일 준비

### 2. 아이콘이 적용되지 않는 경우

**해결 방법**:

```bash
# 1. 앱 완전 삭제
adb uninstall com.safedrive.ai

# 2. 캐시 정리
flutter clean

# 3. 패키지 재설치
flutter pub get

# 4. 아이콘 재생성
flutter pub run flutter_launcher_icons

# 5. 다시 빌드
flutter run
```

### 3. Adaptive icon이 이상하게 보이는 경우

**원인**: Foreground 이미지가 배경에 맞지 않음

**해결**:
- Foreground 이미지 주변에 충분한 여백 추가
- 배경색 변경
- 별도의 foreground 전용 이미지 준비

---

## 📋 체크리스트

아이콘 적용 전:

- [ ] 1024x1024 PNG 아이콘 준비
- [ ] `assets/icon/icon.png` 위치에 배치
- [ ] `flutter pub get` 실행
- [ ] `flutter pub run flutter_launcher_icons` 실행
- [ ] 디버그 빌드로 확인
- [ ] 홈 화면에서 아이콘 확인
- [ ] 다양한 배경에서 아이콘 가독성 확인
- [ ] Release 빌드 테스트

---

## 🎯 현재 설정 요약

SafeDrive AI의 현재 아이콘 설정:

```yaml
파일 위치: assets/icon/icon.png
해상도: 1024 x 1024 권장
배경색: #FFFFFF (흰색)
플랫폼: Android, iOS
Adaptive Icon: 활성화 (Android 8.0+)
```

---

## 🖼️ 무료 아이콘 디자인 도구

아이콘 제작에 도움이 되는 무료 도구:

- **Canva**: https://www.canva.com (템플릿 제공)
- **Figma**: https://www.figma.com (전문가용)
- **Photopea**: https://www.photopea.com (웹 기반 포토샵)
- **GIMP**: https://www.gimp.org (무료 데스크탑 앱)

### 아이콘 리소스

- **Material Icons**: https://fonts.google.com/icons
- **Flaticon**: https://www.flaticon.com
- **Icons8**: https://icons8.com
- **Noun Project**: https://thenounproject.com

---

## 🚀 다음 단계

아이콘 적용 완료 후:

1. **스크린샷 준비**: 앱 스토어용 스크린샷
2. **Feature Graphic**: 1024 x 500 배너 이미지
3. **Play Store 등록**: `DEPLOYMENT_GUIDE.md` 참조

---

**작성일**: 2025-01-03
**대상**: SafeDrive AI v1.0.0
