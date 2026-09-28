# Mobile Improvement Memo Specification

앱을 실제 휴대폰에서 테스트하다가 발견한 불편, 버그, 아이디어를 즉시 남길 수 있는 공통 기능입니다.

## 목표

```text
앱 사용 중 개선점 발견
→ 마이크 또는 메모 버튼
→ 말하거나 입력
→ 원문 저장
→ AI가 개발 작업 형태로 정리
→ 검토 후 개발 backlog로 전환
```

## UX

- 마이크 버튼: 음성 메모
- 키보드 버튼: 일반 텍스트 메모
- 저장 직전 원문 수정 가능
- 현재 화면 이름과 앱 버전 자동 첨부
- 사용자가 선택한 경우에만 스크린샷 첨부

## 저장 데이터

- memo_id
- created_at
- app_name
- app_version
- current_screen
- input_type: voice / text
- raw_text
- ai_summary
- category
- priority
- reproduction_steps
- proposed_change
- status: inbox / reviewed / planned / done
- optional_attachment

## AI 정리

원문을 유지한 채 별도 구조화 결과를 생성합니다.

- 한 줄 제목
- 분류: bug / feature / UI-UX / performance / data / question
- 문제 요약
- 재현 방법
- 기대 동작
- 수정 제안
- 추가 확인 항목

## GPT 수준 처리 방식

API key를 APK에 직접 넣지 않습니다.

```text
Android app
  ↓
음성 → 텍스트
  ↓
로컬 메모 저장
  ↓
보안된 서버/프록시
  ↓
AI 구조화
  ↓
앱에 결과 저장
```

오프라인에서는 원문만 로컬 큐에 저장하고 네트워크 복구 후 AI 정리를 수행합니다.

## GitHub 연동

검토된 메모만 GitHub Issue 또는 개발 backlog로 전환합니다.

예:
```text
[BUG] 운동 종료 후 통증 입력 지연
앱: Shoulder OS
버전: 2.0.0
화면: Live Workout
원문: ...
재현: ...
기대 동작: ...
```

## 보안

- API key/token 하드코딩 금지
- 민감한 화면/파일 자동 첨부 금지
- 스크린샷/첨부는 사용자 선택
- 메모는 로컬 우선 저장
- 공개 GitHub 전송 전 내용 검토

## 우선순위

### P0
- 텍스트 메모
- 음성 → 텍스트
- 로컬 저장
- 앱 버전/현재 화면 자동 첨부

### P1
- AI 요약 및 분류
- 메모 Inbox
- 수정/삭제/완료 처리

### P2
- GitHub Issue 전환
- 스크린샷 선택 첨부
- 앱별/버전별 개선 통계
