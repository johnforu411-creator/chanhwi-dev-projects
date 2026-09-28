# chanhwi-dev-projects

개인 개발 프로젝트의 기준 저장소입니다.

## 현재 상태

- Repository initialized
- Source code: 아직 없음
- Runtime / framework: 아직 미정
- Dependencies: 아직 없음
- Build / test configuration: 아직 없음
- Default branch: `main`

## 개발 관리 원칙

이 저장소의 작업은 다음 원칙으로 관리합니다.

1. 기존에 정상 작동하는 기능을 최대한 보존합니다.
2. 큰 변경 전에는 현재 상태를 Git commit으로 남깁니다.
3. 한 작업 단위가 끝날 때마다 변경 내용을 검증하고 commit합니다.
4. 각 작업 완료 시 다음 내용을 기록합니다.
   - 무엇을 수정했는지
   - 어떤 파일을 수정했는지
   - 테스트 결과
   - 남은 문제
5. 프로젝트 구조, 실행 방법, 의존성 또는 주요 기능이 바뀌면 이 README를 함께 갱신합니다.
6. 비밀번호, API Key, 인증 토큰, 개인정보 등 민감정보는 저장소에 commit하지 않습니다.

## 프로젝트 구조

현재는 초기 상태입니다.

```text
chanhwi-dev-projects/
└── README.md
```

향후 실제 프로젝트가 추가되면 프로젝트별 디렉터리로 분리합니다.

예시:

```text
chanhwi-dev-projects/
├── 01-body-calendar/
├── 02-market-dashboard/
├── 03-tennis-app/
├── docs/
└── README.md
```

## 실행 방법

아직 실행 가능한 애플리케이션이 없습니다.

프로젝트가 추가되면 아래 내용을 프로젝트별로 명시합니다.

- 요구 런타임 및 버전
- 설치 명령
- 환경변수 설정
- 개발 서버 실행 명령
- 빌드 명령
- 테스트 명령

## 의존성

현재 외부 라이브러리 의존성은 없습니다.

## 테스트 상태

현재 테스트할 소스 코드가 없습니다.

## 우선순위

### P0 — 기반 확정
- 첫 실제 개발 프로젝트 선택
- 기술 스택 확정
- 로컬 프로젝트와 GitHub Repository 연결
- 프로젝트별 `.gitignore` 및 환경변수 관리 방식 설정

### P1 — 품질 관리
- lint / format / test 체계 추가
- 실행 및 빌드 명령 문서화
- 정상 동작 기준 정의

### P2 — 자동화
- GitHub Actions를 통한 자동 테스트/빌드
- 릴리스 및 변경 이력 관리 체계 정비

## 작업 기록

Git commit history를 프로젝트 작업 이력의 기준으로 사용합니다.

커밋 메시지는 개발 경험이 없는 사람도 변경 목적을 이해할 수 있도록 작성합니다.
