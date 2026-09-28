# chanhwi-dev-projects

개인 개발 프로젝트의 기준 저장소입니다.

## 현재 구조

```text
chanhwi-dev-projects/
├── projects/
│   ├── shoulder-os/
│   │   ├── V2_사전분석_보고서.md
│   │   ├── V2_구현_및_검증_결과.md
│   │   └── README.md
│   └── tennis-vision/
│       ├── tennis_vision_v0.html
│       └── README.md
├── docs/
│   ├── MOBILE_FEEDBACK_SPEC.md
│   └── PROJECT_MIGRATION_STATUS.md
└── README.md
```

## 프로젝트

### Shoulder OS
V2.0.0 source ZIP과 설치 APK는 Google Drive에 보존되어 있습니다. GitHub에는 현재 분석/검증 문서를 이전했고, 다음 단계에서 source ZIP을 파일 단위 프로젝트 구조로 전개합니다.

### Tennis Vision
현재 확보 가능한 V0 HTML 프로토타입을 GitHub에 이전했습니다. Android debug APK는 Google Drive에서 관리합니다.

## APK 설치 파일

Google Drive의 `App Builds - Install` 폴더를 설치 파일의 기준 위치로 사용합니다.

현재:
- `Shoulder-OS-V2.0.0-test-release.apk`
- `TennisVision-v0-debug.apk`

## 개발 관리 원칙

1. 정상 작동 중인 기능을 우선 보존합니다.
2. 큰 변경 전 현재 상태를 commit합니다.
3. 작업 단위가 끝날 때마다 테스트 후 commit합니다.
4. 작업 완료 보고에는 수정 내용, 수정 파일, 테스트 결과, 남은 문제를 기록합니다.
5. 프로젝트 상태/실행 방법/의존성이 바뀌면 README를 갱신합니다.
6. 비밀번호, API key, 인증 token 등 비밀값은 commit하지 않습니다.
7. APK/대형 설치 파일은 Google Drive에서 관리하고 GitHub에는 소스와 문서를 우선 보존합니다.

## 모바일 개선 메모

휴대폰에서 앱을 사용하면서 **음성 또는 텍스트로 개선사항을 즉시 기록**하는 공통 기능을 추가할 계획입니다.

상세 설계: `docs/MOBILE_FEEDBACK_SPEC.md`

```text
음성/텍스트 메모
→ 원문 보존
→ AI 요약·분류
→ 개선 Inbox
→ 검토 후 개발 작업/GitHub Issue로 전환
```

## 실행 방법

### Tennis Vision V0
`projects/tennis-vision/tennis_vision_v0.html` 을 브라우저에서 실행합니다.

### Shoulder OS
현재 GitHub 이전 단계에서는 Google Drive의 V2.0.0 source ZIP이 전체 원본입니다. Flutter 프로젝트 트리 전개 후 빌드 절차를 이 README에 추가합니다.

## 테스트 상태

- Shoulder OS: 당시 기록상 정적 검사 오류 0건, 자동 테스트 4/4, release APK 빌드 성공
- Tennis Vision HTML: 현재 자동 테스트 미구성

과거 테스트 기록은 기준선이며 GitHub 이전 후 재현 테스트가 필요합니다.

## 우선순위

### P0
- Shoulder OS source ZIP 파일 단위 전개
- Tennis Vision 최신 LocalEditor 전체 소스 회수
- Repository Private 전환 검토
- 각 프로젝트 빌드/실행 재현

### P1
- 공통 모바일 개선 메모: 음성/텍스트 + 로컬 Inbox
- AI 요약/분류
- lint / format / test 자동화

### P2
- GitHub Actions
- 개선 메모 → GitHub Issue 전환
- APK 버전/빌드 이력 자동 관리

## 변경 이력

Git commit history를 작업 이력의 기준으로 사용합니다.
