# V2.0 → V2.1 기준선 이전 검증 (2026-10-05)

## 결론과 근거

V2.1.0은 V2.0.0의 같은 앱/DB를 사용하는 후속 소스입니다. GitHub 기준 commit `536bce9c10439b1f1e15be01ff43a4f434b1e7a5`에는 V2.0 소스 없이 문서 3개만 있었습니다. 따라서 GitHub 소스와의 diff가 아니라 Drive V2.0 ZIP과 V2.1 ZIP을 직접 비교했습니다. 두 ZIP에는 Git 이력이 없으므로 커밋 계보는 증명할 수 없습니다.

V2.0 ZIP은 2026-09-14, V2.1 ZIP은 2026-09-28에 Drive에 생성됐습니다. `pubspec.yaml`은 `2.0.0+2000` → `2.1.0+2100`, applicationId는 동일합니다. V2.1 원본 README만 V2.0 표기가 남아 있어 교정했습니다. 전체 파일별 원본 해시와 변경 목록은 SOURCE_MANIFEST.json에 있습니다.

폴더에는 더 늦게 생성된 `Workout-Calendar-3.0.0.apk`도 있습니다. 이번 요청의 Shoulder OS V2.1 source 기준선 범위 밖이며 해당 APK와의 계보·소스 일치는 미검증입니다. 모든 앱 중 최종 버전이라고 단정하지 않습니다.

## 추가·변경 파일과 기능

| 파일 | 변경 |
|---|---|
| `lib/features/exercises/rehab_session_screen.dart` (추가) | 이미지·목적·순서·큐·실수·통증 기준, 단계/세트 진행, 시간형 타이머, 선택적 종료 통증 |
| `lib/features/shared/tennis_editor.dart` (추가) | 날짜·10~180분·강도·연습/게임/레슨·서브·선택 통증·메모 편집 |
| `lib/app/app.dart` | 위젯 BEST 진입을 재활 안내로 연결 |
| `lib/core/app_database.dart` | 테니스 이벤트 필드 노출, 메모 저장, updateTennis/deleteTennis |
| `lib/features/calendar/calendar_screen.dart` | 테니스 추가·수정·삭제, 날짜 이동 후 선택일 갱신 |
| `lib/features/exercises/live_workout_screen.dart` | 통증 건너뛰기 값을 null로 저장 |
| `lib/features/routines/routines_screen.dart` | 재활 루틴의 안내형 실행 연결 |
| `lib/features/shared/ui.dart` | 재활 실행 라우팅, 선택적 통증 기록 |
| `lib/features/today/today_screen.dart` | BEST/테니스 새 흐름 연결 |
| `pubspec.yaml` | 버전 2.1.0+2100 |
| `test/database_flow_test.dart` | 테니스 메모·날짜 이동·수정·삭제 assertion 추가 |

추가 2개, 유효 변경 9개, 삭제 0개입니다. ZIP 전체 비교는 변경 16개이며 나머지 7개는 Gradle 캐시/로컬 경로입니다. 동일 파일 112개에는 이미지 59개, NanumGothic 폰트, seed JSON, pubspec.lock, Android 위젯 네이티브 구현이 포함됩니다. 위젯 변경은 Dart 진입 경로 변경입니다.

## GitHub 반영 범위 (확정)

포함: lib/, test/, assets/ 전체, Android 앱/위젯/Kotlin/리소스/manifest/Gradle 설정, Gradle wrapper jar/실행 스크립트, pubspec.yaml/lock, analysis_options.yaml. 앱은 `projects/shoulder-os/`에서 직접 실행합니다.

제외: android/.gradle/, android/local.properties, IDE .iml, GeneratedPluginRegistrant.java, build·.dart_tool 캐시, APK/ZIP, 서명키, 개인 DB. APK와 원본 ZIP은 Drive에 유지합니다.

정리 변경: 원본 Android ignore가 wrapper를 제외하므로 이를 추적하도록 교정하고 gradlew 실행 권한을 지정했습니다. 루트 .gitignore, .fvmrc, README, 비교/마이그레이션 문서, 원본 보고서, 무결성 검사 도구를 추가합니다. 저장소 루트 README 및 docs/PROJECT_MIGRATION_STATUS.md도 갱신합니다. 과거 V2 문서는 덮어쓰지 않습니다.

## 데이터와 설치 마이그레이션

양쪽 `_createSchema`는 바이트 단위 동일하고 schema version 1, DB 파일명 `shoulder_os_v2.sqlite`가 같습니다. `tennis_sessions.note`는 V2.0에도 존재하므로 ALTER TABLE이나 schema bump는 필요하지 않습니다. 새 CRUD는 기존 테이블을 사용합니다. 이 결과는 정적 호환성 확인이며 V2.0 DB를 V2.1로 실제 열어본 테스트는 아닙니다.

같은 applicationId + 같은 인증서라면 업데이트 설치로 기존 데이터를 유지할 수 있습니다. 설치 전 `apksigner verify --print-certs`로 V2.0/V2.1 APK 인증서를 비교하고, `aapt dump badging`으로 package/version을 확인합니다. 이번 감사에서는 APK 바이너리/서명을 비교하지 않았습니다. 서명 불일치 시 앱 제거로 해결하면 데이터가 삭제되므로 제거하지 말고 기존 키를 확보하거나 백업 복원 경로를 먼저 준비합니다. V2.0으로의 롤백도 versionCode가 낮아 일반 업데이트 설치가 불가능합니다.

## 테스트 상태와 재현 한계

원본 보고서: flutter analyze 오류 없음, 자동 테스트 4/4, Android release APK 빌드 성공. 원본 실행 로그와 APK의 소스 일치 증명은 첨부되지 않았습니다.

테스트 실제 범위: models_test.dart 2개(안내 JSON 모델/세트 복사), database_flow_test.dart 2개(운동 종료·DB reopen·캘린더·분석, 루틴/통증/치료/다음날/테니스 CRUD). 두 번째 테스트는 테니스 수정/삭제 후 DB를 다시 열어 확인하지 않습니다. 재활 화면 widget/integration 테스트와 V2.0 DB 업그레이드 테스트는 없습니다.

이번 재현: Python 무결성 검사, DB schema 동일성, 자산/lockfile 동일성 확인 통과. Flutter/Dart/Android SDK가 없어 analyze/test/build 미실행. README 명령으로 SDK가 있는 환경에서 실행하고 도구 버전·로그·APK SHA256·서명 지문을 기록해야 합니다. `.fvmrc`는 원본 README 버전을 고정했으며 SDK 실제 확보/호환성은 재확인 대상입니다.

## 실기기 미확인 체크리스트

- [ ] V2.0 데이터(운동/테니스/통증/치료/루틴)를 만든 뒤 동일 서명 V2.1 업데이트, 기록 수와 값/통계 보존 및 재시작 확인.
- [ ] 오늘/BEST, 개별 재활, 재활 루틴, 홈 위젯 각각 안내형 화면으로 진입.
- [ ] 세트 시작/완료/운동 이동/마치기/통증 입력·건너뛰기·취소, 캘린더/분석 반영.
- [ ] **타이머 실행 중 이전/다음 운동 이동**: 타이머는 원래 세트값을 캡처하지만 `_completeSet`은 현재 exerciseIndex로 updateSet하므로 다른 운동 세트가 완료될 가능성. 이동 잠금 또는 원래 운동 ID로 완료하는 후속 수정과 회귀 테스트 필요.
- [ ] 타이머 중 마치기 후 통증 창 취소: 취소된 timer가 화면에서 즉시 갱신되지 않을 가능성. 이탈·복귀·회전·프로세스 재시작도 확인.
- [ ] 화면 꺼짐/백그라운드에서 시간 정확도와 알림. 현재 Timer.periodic 기반이며 재활 세션의 백그라운드 알림/복원은 구현 보장 없음.
- [ ] 작은 Galaxy 화면/큰 글꼴/키보드/터치 영역/다크 모드/긴 안내문.
- [ ] 테니스 추가→수정→날짜 이동→삭제 취소/확정→앱 재시작, 캘린더·통계 동기화. 기존 범위 밖 시간값(10~180분)은 편집 시 clamp되는 점 확인.
- [ ] 위젯 추가·월 이동·새로고침·cold start/deep link·데이터 갱신.

통증 기준은 안내문 표시이며 자동 안전 중단 로직이 아닙니다. 중단/재개, 전문가 적합성 검토, 영상 안내, BodyCalendar 가져오기, 모바일 개선 메모는 이번 구현 범위가 아닙니다.
