# BeanMuWiki 디자인 방향 (2026-09-13)

브랜드 씨앗 = 앱 아이콘: 크림 종이 위 숲색 커피나무 + 빨간 체리 + 갈색 원두. 아래 모든 토큰은 여기서 뽑았다.

## 1. 진단 — 왜 "메모앱"처럼 보이나

| # | 증상 | 위치 |
|---|---|---|
| 1 | 액센트 색이 없다. `.tint`/AccentColor 미설정 → 시스템 블루 링크·버튼, 컵노트 칩은 `.gray` | `BeanMuWikiApp.swift`, `BeanFormView.swift` 컵노트 섹션 |
| 2 | 목록이 텍스트 3줄 행이다. 사진 48px는 있을 때만, 컵노트는 회색 쉼표 문자열 → 스캔할 시각 단서가 없다 | `BeanListView.swift` `BeanRow` |
| 3 | 상세가 설정앱 구조다. `Section("원산지")` + `LabeledContent` 8줄, 사진은 섹션 하나에 `scaledToFit` — 히어로도 인포박스도 아니다 | `BeanDetailView.swift` |
| 4 | 컵노트에 색이 없다. `ChipRow`는 `.fill.tertiary` 회색 캡슐, 평점은 `★☆` 문자열 → 플레이버가 정체성이 아니라 메타데이터로 읽힌다 | `BeanDetailView.swift` `ChipRow`, `BrewRow` |
| 5 | 폼 두 개가 `Form` 기본형 그대로. 비율 `1:16`처럼 이 앱만의 숫자가 다른 행과 같은 크기로 묻힌다 | `BrewFormView.swift`, `BeanFormView.swift` |

## 2. 진행 방식 세 가지

**(A) iOS 26 네이티브 폴리시** — 공수 1~2일. 컴포넌트는 그대로 두고 토큰·카드 행·플레이버 도트·Liquid Glass 디테일만 얹는다.
- 얻는 것: 다크모드·Dynamic Type·접근성 공짜, 코드 변경 최소. Glass 툴바/시트 배경/스크롤 엣지 효과는 iOS 26이 자동 적용(커스텀 바 배경 넣지 말 것).
- 쓸 API: `.buttonStyle(.glassProminent)` FAB, `.glassEffect(.regular.tint(accent), in: .capsule)` 선택 칩, `.scrollContentBackground(.hidden)` + 크림 캔버스, `.tint(brand)`.
- 한계: 레이아웃 발상은 스스로 해야 한다 → B에서 빌린다.

**(B) 브랜드 DESIGN.md 차용** — 공수 0(이 문서에 추출 완료). 74개 중 실제로 읽은 6개(claude, starbucks, notion, airbnb, apple, linear) 가운데 맞는 건 둘.
- `~/.claude/design-md/design-md/starbucks/DESIGN.md` — 커피 + 그린 + 크림, 가장 직접적.
  - 캔버스 `#f2f0eb`/`#edebe9`(순백 금지), 4단 그린(제목 `#006241` / CTA `#00754A` / 딥밴드 `#1E3932` / 워시 `#d4e9e2`), 카드 12px + 속삭이는 그림자 `0 1px 1px rgba(0,0,0,.24)`, 버튼 전부 필(pill), 56px 원형 플로팅 CTA, 본문 `rgba(0,0,0,.87)`(순흑 금지), 골드는 "리워드 의식"에만.
  - 안티무브: 그린 하나로 다 칠하기, 그라디언트, 무거운 단일 그림자, 쇼핑 플로우에 세리프.
  - SwiftUI 매핑: 4단 그린 → `brand`(제목/선택) · `accent`(FAB/저장) · `leaf`(배지 채움) · `wash`(선택 칩 배경). 원형 CTA → `.glassProminent` FAB. 골드 → 우리는 체리 레드가 "기준 레시피 ★" 의식 색.
- `~/.claude/design-md/design-md/claude/DESIGN.md` — "에디토리얼 위키" 톤.
  - 캔버스 `#faf9f5`, 잉크 `#141413`, 카드 `#efe9de`(캔버스보다 살짝 진한 크림), 헤어라인 `#e6dfd8`, 반지름 위계 8(입력/버튼)·12(카드)·16(히어로)·pill(배지), 간격 4/8/12/16/24/32, 액센트는 "개별 요소엔 인색, 풀블리드 카드엔 후하게", `category-tab`(비활성 투명/활성 카드색) + `badge-pill`.
  - 안티무브: 순백/쿨그레이 캔버스, 액센트 남발, 연속 밴드에 같은 표면.
  - SwiftUI 매핑: 반지름·간격 스케일 그대로, 인포박스 헤더 = `surface-card` 톤, 플레이버 피커 카테고리 탭 = `category-tab`. 세리프 디스플레이는 채택 안 함(§3 안티무브).
- 참고만: airbnb(정사각 사진 카드 14px, 그림자 1단계만, 디스플레이 500/600 무게), apple(액센트 하나 + 눌림 `scale(0.95)`). notion(보라/파스텔), linear(다크 온리)은 부적합.

**(C) Claude Design 캔버스로 목업 먼저** — 공수 반나절 + 반복 1회. `/design`으로 목록·상세·원두 폼·플레이버 피커 4 아트보드를 한 캔버스에 뽑고 클릭으로 다듬은 뒤 코딩.
- 얻는 것: 코드 갈아엎기 전에 "이게 원하는 느낌인가"를 눈으로 확정. 색·간격을 시각적으로 비교.
- 비용: HTML 목업 → SwiftUI 번역이 한 번 더 들어감. 4화면 중 3개는 폼/리스트라 목업의 정보량이 낮다.

**추천(하나만): A를 몸통으로, B의 토큰을 `Theme.swift` 한 파일에 굳히고, C는 플레이버 피커 1장만.**
이유: 진단 5개가 전부 "토큰이 안 입혀졌다"이지 "레이아웃이 틀렸다"가 아니다. 네이티브 컴포넌트 + 토큰이면 AI 어시스턴트와 하루면 80%가 바뀌고 다크모드·접근성이 따라온다. 목업은 기성 컴포넌트가 없는 화면(피커)에서만 본전을 뽑는다. 빈카이브의 민트를 베끼지 않고 아이콘 그린을 쓰는 것이 차별점.

## 3. 제안 토큰 세트 (`Theme.swift` + Asset Catalog 색상 세트)

| 토큰 | 라이트 | 다크 | 역할 · 대비(크림 위) |
|---|---|---|---|
| `canvas` | `#FBF4E6` | `#1A1512` | 화면 배경(아이콘 종이 / 에스프레소) |
| `card` | `#FFFFFF` | `#241D18` | 카드·인포박스 본문 |
| `cardTint` | `#EEDCC0` | `#362C24` | 인포박스 헤더, 선택 안 된 칩, 헤어라인(60%) |
| `ink` | `#2A2118` | `#F3E9D8` | 본문. 순흑 금지 |
| `muted` | `#7A6A58` | `#A89680` | 메타·캡션 |
| `brand` | `#2F6B45` | `#55A96F` | 제목 강조·탭 선택·링크. 5.7:1 텍스트 OK |
| `accent` | `#3E8A5A` | `#6DBB84` | FAB·저장·토글 채움(흰 글자). 3.8:1 → 작은 글자 금지 |
| `leaf` | `#55A96F` | `#7FCB96` | 배지·도트 채움 전용(신선도 D+N 배지 예약) |
| `cherry` | `#D84343` | `#E25A5A` | 기준 레시피 ★, 평점 채움. 텍스트 금지 |
| `bean` | `#6B4423` | `#A9754A` | 로스팅 바 진한 끝, 3차 텍스트 |

**타입 롤** — 폰트는 시스템(SF Pro; 한글은 Apple SD Gothic Neo 자동 폴백). 고정 pt 대신 텍스트 스타일을 쓴다.

| 롤 | 스타일 | 기본 pt | 비고 |
|---|---|---|---|
| 화면 제목 | `.largeTitle` bold | 34 | 네비게이션 기본 |
| 카드/행 제목 | `.headline` | 17 semibold | ink |
| 메타 | `.subheadline` | 15 | muted, `·` 구분 |
| 캡션/배지 | `.caption` medium | 12 | 대문자 트래킹 없음(한글) |
| 숫자 데이터 | `.title2` + `.fontDesign(.rounded)` + `.monospacedDigit()` | 22 | 비율 `1:16`, 고도, 온도, 평점 — SF Pro Rounded는 숫자·라틴만 바뀌고 한글은 그대로라 안전 |

**반지름** 8(칩·입력) / 12(카드) / 16(사진 히어로·시트) / capsule(배지·FAB). **간격** 4 · 8 · 12 · 16 · 24 · 32. **그림자** 카드에 없음 또는 `0 1 1 rgba(0,0,0,.08)` 하나; 띄우는 건 FAB뿐(glass가 처리).

**시그니처 무브 3**
1. **플레이버 도트** — 컵노트 → 7 카테고리 색. 행에는 도트 5개 + `+N`, 상세는 색 캡슐, 피커는 카테고리 탭. 정체성 요소.
   꽃 `#D98CB3` · 시트러스 `#E9B949` · 과일/베리 `#C4587A` · 단맛 `#D89A4E` · 초콜릿/견과 `#8A5A3C` · 홍차/허브 `#8FA34A` · 향신료/스모키 `#A0563A` · 직접입력 `muted`
2. **위키 인포박스** — 원산지 8개 필드를 `cardTint` 헤더 + 2열 헤어라인 표 카드로. 숫자(고도)는 Rounded. 나무위키/위키백과 문법을 앱으로.
3. **로스팅 바** — `roastLevel`을 5칸 바(`cardTint` → `bean`)로. 행에는 제목 아래 얇게, 상세는 인포박스 첫 줄. 문자열이 약/중약/중/중강/강에 안 맞으면 텍스트만.

**안티무브 3** — ① 순백 캔버스·시스템 블루(크림이 브랜드). ② 그린 하나로 배경까지 칠하기(4단 그린은 역할별, 큰 면에는 절대 안 씀). ③ 세리프 디스플레이·그라디언트·무거운 그림자(`.fontDesign(.serif)`는 한글에 폴백이 없어 라틴/한글이 갈라진다).

## 4. 화면별 적용 메모

- **목록** `BeanListView` — 행을 카드로: 64px 정사각 사진(없으면 `bean` 타일 + 첫 글자) · 제목 · 로스터리·산지 메타 · 플레이버 도트 · 로스팅 바. `List` 유지 + `.listRowBackground(.clear)` + `.scrollContentBackground(.hidden)` + `canvas`. 툴바 `+` → 우하단 `accent` `.glassProminent` FAB. 탭바는 색인/통계(ROADMAP 3·9)가 생기면 그때 `TabView`.
- **상세** `BeanDetailView` — 사진을 4:3 히어로(r16)로 올리고, 원산지 `Section` → 인포박스, `ChipRow` → 색 캡슐, 기준 레시피 기록은 `cherry` ★ + `brand` 테두리 카드.
- **원두 폼** `BeanFormView` — `Form` 유지. 컵노트 가로 스크롤 → "플레이버 선택 (4)" 행 + 시트 피커(카테고리 탭 + 색 칩 그리드). 사진은 맨 위 큰 점선 타일.
- **기록 폼** `BrewFormView` — `Form` 유지. 맨 위에 `1:16 · 92℃ · 2:45` Rounded 숫자 헤더 카드(`accent` 배경, 실시간 갱신). 별점 `cherry`, 기준 레시피 토글 `.tint(accent)`.

## 5. 다음 단계

1. **토큰 붙이기(1시간, 전 화면 즉시 변화)** — Asset Catalog에 위 색상 세트(라이트/다크) 추가, `Theme.swift`에 `Color.canvas…` 확장 + 반지름/간격 상수, `BeanMuWikiApp`에 `.tint(.brand)`, 두 List/Form에 크림 캔버스, ★와 평점을 `cherry`로.
2. **목록 카드 + 플레이버 도트(반나절)** — `Models.swift`에 `FlavorCategory`(이름 → 색 매핑), `FlavorDots` 뷰, `BeanRow` 카드화, FAB.
3. **상세 인포박스 + 히어로 + 색 칩(반나절)** — `ChipRow`가 카테고리 색을 받도록 확장, `RoastBar` 뷰.
4. **플레이버 피커(1일)** — `/design`으로 피커 1장(+ 카드 행 1장) 아트보드 뽑아 한 번 다듬고 `FlavorPickerView` 구현, `BeanFormView`에 연결.
5. **기록 폼 숫자 헤더 + 다크모드 검수(반나절)** — 시뮬레이터 라이트/다크 스크린샷, `accent`/`leaf`가 작은 글자에 쓰이지 않았는지 대비 점검, 신선도 배지(ROADMAP 1)에 `leaf` 예약 확인.
