# Shoulder OS

## 상태

현재 확인된 최신 실행 기준선은 **Shoulder OS V2.0.0** 입니다.

- Android package: `com.personal.shoulder_os`
- Version: `2.0.0 (2000)`
- Flutter 기반 Android 앱
- 로컬 SQLite/Drift 데이터 저장
- 5개 하단 탭: 오늘 / 운동 / 루틴 / 캘린더 / 분석

## 확보된 원본

Google Drive `ShoulderRehab` 폴더:
- `Shoulder-OS-V2.0.0-source.zip` — 전체 소스 원본
- `Shoulder-OS-V2.0.0-test-release.apk` — 설치 APK

GitHub에는 우선 분석/검증 문서를 보존했습니다. 전체 source ZIP은 Google Drive에 안전하게 남아 있으며, 다음 단계에서 프로젝트 파일 단위로 전개해 GitHub에 올립니다.

## 검증된 기준선

당시 기록 기준:
- Flutter 정적 검사 오류 0건
- 자동 테스트 4/4 통과
- DB 재실행 영속성 통과
- Android release APK 빌드 성공
- APK v2 서명 검증

## 다음 작업

1. source ZIP을 프로젝트 디렉터리로 전개
2. 생성물/로컬 경로 파일 제외 및 `.gitignore` 정리
3. Flutter SDK 버전 고정
4. 빌드/테스트 재현
5. 모바일 개선 메모 기능 추가
