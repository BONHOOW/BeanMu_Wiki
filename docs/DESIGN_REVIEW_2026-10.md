# 디자인 리뷰 2회차 (2026-10-09) — UI 레퍼런스 MCP 5종 + 로고 리디자인

## 1. 연결한 MCP (사용자 설정, `claude mcp list`)

| MCP | 무엇을 하나 | 엔드포인트 | 접근 조건 | 상태 |
|---|---|---|---|---|
| **Mobbin** | 실제 출시 앱·웹의 화면·플로우·섹션 검색 (`search_screens` / `search_flows` / `search_sections`). 레퍼런스 양과 큐레이션이 가장 큼 | `https://api.mobbin.com/mcp` | Mobbin 계정 OAuth, **Pro 이상 유료** | 등록됨 · 인증 필요 |
| **Nicelydone** | SaaS 제품 21만 화면·8천 플로우. 패턴(모달·폼·네비·테이블)·컴포넌트·앱 카테고리 탐색, 컬렉션 정리 (12개 도구) | `https://mcp.nicelydone.club/mcp` | OAuth 2.1, **프리미엄 유료** | 등록됨 · 인증 필요 |
| **Refero** | 15만 실제 앱 화면·플로우 + `styles.refero.design`의 디자인 시스템(DESIGN.md) 카탈로그 | `https://api.refero.design/mcp` | OAuth 또는 토큰, **Pro/Team/Lifetime 유료** (커뮤니티 npx 버전은 403으로 막힘) | 등록됨 · 인증 필요 |
| **Lazyweb** | 28만 화면·1.5만 플로우/회사 페이지의 시맨틱 검색. 공개 엔드포인트는 계정·키 없이 동작 | `https://www.lazyweb.com/mcp/public` | 무료 (Pro는 전체 리포트) | **연결됨** |
| **InspoAI** | 20만 실제 화면을 근거로 UI 화면을 **생성**(React+Tailwind), 디자인→Figma 변환, UI·아이콘·서체 레퍼런스 검색 | `https://app.inspoai.io/mcp` | OAuth (요금제 확인 필요) | 등록됨 · 인증 필요 |

인증이 필요한 4개는 새 세션에서 `/mcp` → 해당 서버 → **Authenticate**로 브라우저 로그인하면 됩니다. Mobbin·Nicelydone·Refero는 유료 플랜이 있어야 도구가 응답합니다(결제는 사용자 판단).

## 2. 이번에 참고한 레퍼런스 (Lazyweb 공개 검색)

- **Crouton — Follow cooking steps / Open recipe**: 레시피 상세 → 단계 화면에서 한 단계만 크게, 체크 가능, 타이머 내장. → 추출 카드의 "지금 단계" 강조와 같은 구조.
- **Numbies — 세션 타이머**: 화면에 큰 숫자 하나(세션 시간)와 현재 항목, 다음 동작 버튼. → 다음 푸어까지 남은 초를 큰 숫자로.
- **Beli — Taste Profile**: 취향을 색·태그로 요약한 프로필. → 원두의 로스팅 포인트를 바(bar)로 즉시 읽히게, 플레이버 도트와 짝.
- 커피 전용 앱(Beanconqueror, 빈카이브 등)은 Lazyweb 공개 인덱스에 없어 Mobbin/Nicelydone 인증 후 2차 리뷰 대상.

## 3. 반영한 수정

1. **추출 카드 타이머**: 다음 푸어까지 남은 초를 34pt 숫자로(5초 이하 체리색), 그 옆에 시각·목표 g, 아래에 현재 단계 진행 바. 경과 시간(56pt)과 함께 "지금 / 다음" 두 숫자만 보면 되게.
2. **로스팅 바**: 로스팅 포인트 7단계를 5칸 바로(칸 색 = 그 단계 원두색). 목록 행 오른쪽 위와 문서 헤더 배지에 표시. `RoastBar` (FlavorViews.swift).
3. 이전 라운드에서 들어간 것: 레시피 변형 배지, 컵 피커, 블렌드 배지.

## 4. 2차 리뷰에서 볼 것 (MCP 인증 후)

- Mobbin: "coffee brew timer", "tasting notes" 플로우 — 추출 카드의 단계 전환 애니메이션·햅틱 타이밍, 기록 폼의 별점 UI.
- Nicelydone: 테이블·폼 패턴 — Mac 기록 표와 그룹 폼 밀도.
- Refero: 디자인 시스템 카탈로그 — 크림 캔버스 계열 스타일과 토큰 비교(`Theme.swift`).
- InspoAI: 빈 상태·온보딩 화면 생성 시안.

## 5. 로고 리디자인 (logo-design 스킬, 1차 컨셉)

현재 아이콘: 에메랄드 그라디언트 타일 + 흰 원두 + 새싹. 유지할 자산은 **초록 계열**과 **원두 실루엣**. 컨셉 시안 `docs/logo/concepts-round1.png`, SVG `docs/logo/concept-*.svg`.

- **A · Sapling Bean (추천)** — 원두의 틈이 묘목으로 자란다. Bean + 나무(위키)를 한 형태로, 기존 새싹 아이콘의 진화. 16px에서도 읽힘.
- **B · Bookmark Bean** — 원두에 책갈피 리본. "저장된 항목"이라는 위키 성격. 16px에서 리본이 약해짐.
- **C · Bracketed Bean** — 위키 링크 `[[ ]]` 사이의 원두. 타이포그래픽하고 또렷하지만 원두 자체는 작아짐.

방향이 정해지면 색(브랜드 그린 단색·크림 반전), 소형 컷, 앱 아이콘·파비콘 세트, 사용 가이드를 만든다.
