# Shoulder OS V2.1.0

최신 **소스 기준선은 V2.1.0 (`2.1.0+2100`)** 입니다. Android 실기기 검증 완료 버전이라는 뜻은 아닙니다. 2026-10-05에 Drive의 V2.0/V2.1 ZIP을 바이트 단위 비교하고 V2.1 프로젝트를 전개했습니다.

- Android package: `com.personal.shoulder_os`
- Flutter 3.47.4 / Dart 3.13.3 (원본 README의 도구 버전; `.fvmrc` 고정)
- SQLite / `sqflite` (Drift 아님), DB `shoulder_os_v2.sqlite`, schema version 1
- 오늘 / 운동 / 루틴 / 캘린더 / 분석 5개 탭
- 재활 안내형 세션, 테니스 기록 추가·수정·삭제, 월간 Android 위젯

## 원본과 변경

- [V2.1 source ZIP](https://drive.google.com/file/d/1WCUyy2LQVAonPS33H9aCJI66siT2NcdI/view)
- [V2.1 test release APK](https://drive.google.com/file/d/1a9rjBU7GQ7nLgTOJv52uKOrW7R3fhmBt/view)
- [V2.1 원본 보고서](docs/V2.1_후기기반_개선_및_사용흐름_보고서.md)
- [버전 비교·이전 범위·실기기 체크리스트](docs/MIGRATION_V2_0_TO_V2_1.md)
- [원본 해시 및 파일별 비교 명세](docs/SOURCE_MANIFEST.json)

V2.0 분석/검증 문서는 당시 기록으로 보존합니다. 원본 V2.1 ZIP 안의 README는 여전히 V2.0으로 적혀 있으므로 이 README로 교체했습니다. Dart 기능 소스는 원본 V2.1을 보존했습니다.

## 실행과 재현

Flutter 3.47.4, Dart 3.13.3, JDK 17과 Android SDK를 준비합니다. `android/local.properties`는 로컬 Flutter/Android SDK 경로로 생성해야 합니다. FVM 사용 시 `fvm install` 후 아래 Flutter 명령을 `fvm flutter`로 실행합니다.

```sh
cd projects/shoulder-os
flutter --version
flutter pub get --enforce-lockfile
flutter analyze
flutter test --reporter expanded
flutter build apk --release --build-name 2.1.0 --build-number 2100
python3 tool/verify_import.py
```

Gradle 9.3.1, AGP 9.1.0, Kotlin plugin 2.4.0은 원본 설정 그대로입니다. Wrapper와 `pubspec.lock`을 포함했습니다. 위 명령은 재현 절차이며 이 환경에서 실행 성공을 주장하지 않습니다.

## 검증 상태

| 구분 | 결과 |
|---|---|
| 2026-09-28 원본 보고서 | analyze 오류 없음, 자동 테스트 4/4, Android release 빌드 성공 |
| 2026-10-05 직접 확인 | ZIP 버전/파일 비교, DB 생성 스키마 동일, 자산/lockfile 동일, 소스 무결성 검사 통과 |
| 이번 Flutter 재실행 | 미실행: Flutter/Dart/Android SDK 부재 |
| 실기기·APK 서명 비교 | 미확인 |

테스트는 모델 2개 + DB 흐름 2개입니다. DB 테스트에 테니스 날짜 이동·수정·삭제 검증이 추가됐지만 총 개수는 4개 그대로입니다. 재활 UI/타이머/위젯 테스트는 없습니다.

APK는 개인 테스트용 debug 서명입니다. 로컬에서 다시 빌드하면 기존 APK와 인증서가 다를 수 있습니다. 업데이트 설치 전 서명 확인과 데이터 백업이 필요합니다. 타이머 실행 중 운동 이동 시 잘못된 세트 완료 가능성이 있어 실기기 체크리스트의 우선 확인 항목으로 기록했습니다.
