#!/bin/bash

# SafeDrive AI - 더미 알림음 파일 생성 스크립트
# 실제 개발 시에는 적절한 알림음으로 교체하세요

echo "Creating dummy sound files for testing..."

# sounds 디렉토리 생성
mkdir -p assets/sounds

# 더미 MP3 파일 생성 (테스트용)
# 실제로는 무음 파일이지만 앱 빌드는 가능합니다
touch assets/sounds/soft_beep.mp3
touch assets/sounds/medium_alert.mp3
touch assets/sounds/urgent_alarm.mp3

echo "✅ Dummy sound files created!"
echo ""
echo "⚠️  경고: 이것은 테스트용 빈 파일입니다."
echo "실제 사용을 위해서는 다음 사이트에서 알림음을 다운로드하세요:"
echo "  - https://freesound.org/"
echo "  - https://zapsplat.com/"
echo "  - https://mixkit.co/"
echo ""
echo "권장 설정:"
echo "  - soft_beep.mp3: 부드러운 짧은 삐 소리 (1-2초)"
echo "  - medium_alert.mp3: 중간 강도 경고음 (2-3초)"
echo "  - urgent_alarm.mp3: 강한 긴급 알람 (2-4초)"
