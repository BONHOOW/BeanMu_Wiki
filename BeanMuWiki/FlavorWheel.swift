// FlavorWheel.swift
// SCA/WCR Coffee Taster's Flavor Wheel (2016) — 9 categories, all tier-2/tier-3 descriptors, official segment colors.
//
// Names:  fschlz/coffee-flavor-api  https://github.com/fschlz/coffee-flavor-api/blob/master/resources/sca_coffee_flavors.json
//         hc-oss/coffee-flavor-wheel https://github.com/hc-oss/coffee-flavor-wheel/blob/master/coffee-flavors.ts
// Colors: primary = ECharts-style SCA sampling (widely copied, e.g. blackberry #3E0317, jasmine #F7F1BD)
//           https://github.com/VisActor/VGrammar/blob/develop/docs/dev-demos/src/data/coffee.json
//           https://github.com/takum1-me/takum1-me/blob/main/src/data/coffee-flavor.ts
//         cross-check = independent sampling in hc-oss/coffee-flavor-wheel (above).
// Verified = primary and hc-oss agree within 32/255 per RGB channel (8 of 9 categories, 72 of 97 flavors).
// Approximated (samplings disagree, primary kept; 24 flavors): 꽃(category), 블랙베리, 장미, 자스민, 건포도, 코코넛, 체리, 사과, 시큼한 향, 부티르산, 발효,
//   진한 녹색 채소, 묵은내, 골판지, 종이, 나무, 쓴맛, 고무, 파이프 담배, 시리얼, 코코아, 다크초콜릿, 흑설탕, 메이플 시럽, 꿀.
// Adjusted for visibility: 종이 (#FEFEF4 → #D9D0C1), 짠맛 (#DEF2FD → #CED2CA, hc-oss value).
// Korean: common Korean coffee usage; category/tier-2 terms cross-checked with terarosalibrary.com/brewing/18986 (갈색 향신료, 톡 쏘는, 정향, 아니스).
// Tier-2 group names that are not tasting words (Other fruit, Alcohol/Fermented, Papery/Musty, Chemical) are omitted.
// 빈카이브(Beanchive, com.nunkoib.beanchive) has no public source or data; its list is this wheel.
//
// Non-SCA additions (32, appended at the end of each category; colors approximated to the segment) = words Korean specialty
// roasters (프릳츠·모모스·커피리브레·나무사이로·헬카페·테라로사·빈브라더스) print on bags but the 2016 wheel lacks:
//   과일 유자·청포도·리치·망고·살구·자두·무화과·패션프루트·멜론·수박·크랜베리·귤, 신맛/발효 럼·요거트, 향신료 생강·카다멈,
//   견과/코코아 밀크초콜릿·카카오닙스·마카다미아·피칸·호두, 구운 현미, 단맛 흑당·조청·토피·누가·크리미·버터·콜라, 꽃 라벤더·얼그레이·히비스커스.
// `english` also carries spelling/alias variants separated by " · " (플로럴, 카라멜, 재스민, 백도 …); search and canonicalName(_:) match them.

import SwiftUI

struct Flavor: Hashable, Identifiable {
    let name: String      // 한국어 표시명, 앱 내 고유 키 (중복 금지)
    let english: String   // SCA 영문명 + " · " 구분 별칭 (영문 변형, 한국어 표기 변형)
    let hex: String       // "#RRGGBB"
    var id: String { name }
    var color: Color { Color(hex: hex) }
}

struct FlavorCategory: Identifiable {
    let name: String      // 과일, 신맛/발효, 녹색/채소, 기타, 구운, 향신료, 견과/코코아, 단맛, 꽃
    let hex: String       // 카테고리 대표색
    let flavors: [Flavor] // tier-2 그룹명 먼저, 이어서 tier-3 항목 (휠 순서), 마지막에 비SCA 추가 항목
    var id: String { name }
    var color: Color { Color(hex: hex) }
}

enum FlavorWheel {
    static let categories: [FlavorCategory] = [
        FlavorCategory(name: "과일", hex: "#DA1D23", flavors: [
            Flavor(name: "베리", english: "Berry · 베리류", hex: "#DD4C51"),
            Flavor(name: "건과일", english: "Dried fruit · 말린 과일 · 드라이 프루트", hex: "#C94A44"),
            Flavor(name: "시트러스", english: "Citrus fruit · Citrus · 감귤류 · 시트러스향", hex: "#F7A128"),
            Flavor(name: "블랙베리", english: "Blackberry", hex: "#3E0317"),
            Flavor(name: "라즈베리", english: "Raspberry", hex: "#E62969"),
            Flavor(name: "블루베리", english: "Blueberry", hex: "#6569B0"),
            Flavor(name: "딸기", english: "Strawberry · 스트로베리", hex: "#EF2D36"),
            Flavor(name: "건포도", english: "Raisin · 레이즌", hex: "#B53B54"),
            Flavor(name: "말린 자두", english: "Prune · 프룬", hex: "#A5446F"),
            Flavor(name: "코코넛", english: "Coconut", hex: "#F2684B"),
            Flavor(name: "체리", english: "Cherry", hex: "#E73451"),
            Flavor(name: "석류", english: "Pomegranate", hex: "#E65656"),
            Flavor(name: "파인애플", english: "Pineapple", hex: "#F89A1C"),
            Flavor(name: "포도", english: "Grape · 그레이프", hex: "#AEB92C"),
            Flavor(name: "사과", english: "Apple · 애플", hex: "#4EB849"),
            Flavor(name: "복숭아", english: "Peach · 피치 · 백도 · 황도 · 천도", hex: "#F68A5C"),
            Flavor(name: "배", english: "Pear · 페어 · 배향", hex: "#BAA635"),
            Flavor(name: "자몽", english: "Grapefruit · 그레이프프루트", hex: "#F26355"),
            Flavor(name: "오렌지", english: "Orange", hex: "#E2631E"),
            Flavor(name: "레몬", english: "Lemon", hex: "#FDE404"),
            Flavor(name: "라임", english: "Lime", hex: "#7EB138"),
            Flavor(name: "유자", english: "Yuzu · Citron", hex: "#F2D045"),
            Flavor(name: "청포도", english: "Green grape · Muscat · 머스캣 · 머스켓 · 샤인머스캣", hex: "#A9C83A"),
            Flavor(name: "리치", english: "Lychee · Litchi · 라이치", hex: "#EE7A8E"),
            Flavor(name: "망고", english: "Mango", hex: "#F9B233"),
            Flavor(name: "살구", english: "Apricot · 애프리콧", hex: "#F5A56C"),
            Flavor(name: "자두", english: "Plum · 플럼", hex: "#9B3F7A"),
            Flavor(name: "무화과", english: "Fig", hex: "#8A5170"),
            Flavor(name: "패션프루트", english: "Passion fruit · 패션후르츠 · 백향과", hex: "#E58E26"),
            Flavor(name: "멜론", english: "Melon · 허니듀", hex: "#B5D66B"),
            Flavor(name: "수박", english: "Watermelon · 워터멜론", hex: "#F46B7A"),
            Flavor(name: "크랜베리", english: "Cranberry", hex: "#B3183A"),
            Flavor(name: "귤", english: "Tangerine · Mandarin · 감귤 · 탠저린 · 만다린 · 밀감", hex: "#F58C2A"),
        ]),
        FlavorCategory(name: "신맛/발효", hex: "#EBB40F", flavors: [
            Flavor(name: "산미", english: "Sour · 사우어 · 신맛", hex: "#E1C315"),
            Flavor(name: "시큼한 향", english: "Sour aromatics", hex: "#9EA718"),
            Flavor(name: "아세트산", english: "Acetic acid", hex: "#94A76F"),
            Flavor(name: "부티르산", english: "Butyric acid", hex: "#D0B24F"),
            Flavor(name: "이소발레르산", english: "Isovaleric acid", hex: "#8EB646"),
            Flavor(name: "구연산", english: "Citric acid", hex: "#FAEF07"),
            Flavor(name: "사과산", english: "Malic acid", hex: "#C1BA07"),
            Flavor(name: "와인", english: "Winey · Wine · 와이니", hex: "#8F1C53"),
            Flavor(name: "위스키", english: "Whiskey · Whisky", hex: "#B34039"),
            Flavor(name: "발효", english: "Fermented · 퍼먼티드 · 펑키", hex: "#BA9232"),
            Flavor(name: "과숙", english: "Overripe · 오버라이프", hex: "#8B6439"),
            Flavor(name: "럼", english: "Rum · 럼주", hex: "#9E4A2E"),
            Flavor(name: "요거트", english: "Yogurt · Yoghurt · 요구르트", hex: "#E8D98A"),
        ]),
        FlavorCategory(name: "녹색/채소", hex: "#187A2F", flavors: [
            Flavor(name: "올리브 오일", english: "Olive oil", hex: "#A2B029"),
            Flavor(name: "날것", english: "Raw", hex: "#718933"),
            Flavor(name: "풋내", english: "Green/Vegetative · 그리니", hex: "#3AA255"),
            Flavor(name: "콩비린내", english: "Beany", hex: "#5E9A80"),
            Flavor(name: "덜 익은 과일", english: "Under-ripe", hex: "#A2BB2B"),
            Flavor(name: "완두콩 깍지", english: "Peapod", hex: "#62AA3C"),
            Flavor(name: "풋풋함", english: "Fresh", hex: "#03A653"),
            Flavor(name: "진한 녹색 채소", english: "Dark green", hex: "#038549"),
            Flavor(name: "채소", english: "Vegetative", hex: "#28B44B"),
            Flavor(name: "건초", english: "Hay-like", hex: "#A3A830"),
            Flavor(name: "허브", english: "Herb-like · 허벌", hex: "#7AC141"),
        ]),
        FlavorCategory(name: "기타", hex: "#0AA3B5", flavors: [
            Flavor(name: "묵은내", english: "Stale", hex: "#8B8C90"),
            Flavor(name: "골판지", english: "Cardboard", hex: "#BEB276"),
            Flavor(name: "종이", english: "Papery", hex: "#D9D0C1"),
            Flavor(name: "나무", english: "Woody · 우디", hex: "#744E03"),
            Flavor(name: "곰팡내", english: "Moldy/Damp", hex: "#A3A36F"),
            Flavor(name: "먼지", english: "Musty/Dusty", hex: "#C9B583"),
            Flavor(name: "흙내", english: "Musty/Earthy · 어시", hex: "#978847"),
            Flavor(name: "동물성", english: "Animalic", hex: "#9D977F"),
            Flavor(name: "육수", english: "Meaty/Brothy", hex: "#CC7B6A"),
            Flavor(name: "페놀", english: "Phenolic", hex: "#DB646A"),
            Flavor(name: "쓴맛", english: "Bitter", hex: "#80A89D"),
            Flavor(name: "짠맛", english: "Salty", hex: "#CED2CA"),
            Flavor(name: "약품", english: "Medicinal", hex: "#7A9BAE"),
            Flavor(name: "석유", english: "Petroleum", hex: "#039FB8"),
            Flavor(name: "스컹크", english: "Skunky", hex: "#5E777B"),
            Flavor(name: "고무", english: "Rubber", hex: "#120C0C"),
        ]),
        FlavorCategory(name: "구운", hex: "#C94930", flavors: [
            Flavor(name: "파이프 담배", english: "Pipe tobacco", hex: "#CAA465"),
            Flavor(name: "담배", english: "Tobacco · 토바코", hex: "#DFBD7E"),
            Flavor(name: "탄내", english: "Burnt · 번트", hex: "#BE8663"),
            Flavor(name: "시리얼", english: "Cereal · 그래놀라", hex: "#DDAF61"),
            Flavor(name: "매캐함", english: "Acrid", hex: "#B9A449"),
            Flavor(name: "재", english: "Ashy", hex: "#899893"),
            Flavor(name: "스모키", english: "Smoky · 스모크 · 훈연", hex: "#A1743B"),
            Flavor(name: "브라운 로스트", english: "Brown roast · 로스티", hex: "#894810"),
            Flavor(name: "곡물", english: "Grain · 그레인 · 보리차 · 구운 보리", hex: "#B7906F"),
            Flavor(name: "몰트", english: "Malt · 맥아 · 몰티", hex: "#EB9D5F"),
            Flavor(name: "현미", english: "Brown rice · 누룽지", hex: "#C4A26B"),
        ]),
        FlavorCategory(name: "향신료", hex: "#AD213E", flavors: [
            Flavor(name: "톡 쏘는 향", english: "Pungent", hex: "#794752"),
            Flavor(name: "후추", english: "Pepper · 페퍼 · 블랙페퍼", hex: "#CC3D41"),
            Flavor(name: "갈색 향신료", english: "Brown spice · 스파이스 · 스파이시 · 향신료", hex: "#B14D57"),
            Flavor(name: "아니스", english: "Anise", hex: "#C78936"),
            Flavor(name: "넛맥", english: "Nutmeg · 육두구", hex: "#8C292C"),
            Flavor(name: "시나몬", english: "Cinnamon · 계피", hex: "#E5762E"),
            Flavor(name: "정향", english: "Clove · 클로브", hex: "#A16C5A"),
            Flavor(name: "생강", english: "Ginger · 진저", hex: "#D89A3E"),
            Flavor(name: "카다멈", english: "Cardamom · 카다몬 · 카르다몸", hex: "#B07A5A"),
        ]),
        FlavorCategory(name: "견과/코코아", hex: "#A87B64", flavors: [
            Flavor(name: "견과", english: "Nutty · 너티 · 견과류 · 넛츠", hex: "#C78869"),
            Flavor(name: "코코아", english: "Cocoa · 카카오", hex: "#BB764C"),
            Flavor(name: "땅콩", english: "Peanuts · Peanut · 피넛", hex: "#D4AD12"),
            Flavor(name: "헤이즐넛", english: "Hazelnut · 헤이즐넛 · 헤이즐럿", hex: "#9D5433"),
            Flavor(name: "아몬드", english: "Almond", hex: "#C89F83"),
            Flavor(name: "초콜릿", english: "Chocolate · 초콜렛 · 쵸콜릿", hex: "#692A19"),
            Flavor(name: "다크초콜릿", english: "Dark chocolate · 다크초콜렛", hex: "#470604"),
            Flavor(name: "밀크초콜릿", english: "Milk chocolate · 밀크초콜렛", hex: "#8B5A3C"),
            Flavor(name: "카카오닙스", english: "Cacao nibs · 카카오닙", hex: "#5A2E1B"),
            Flavor(name: "마카다미아", english: "Macadamia", hex: "#D9B98A"),
            Flavor(name: "피칸", english: "Pecan", hex: "#8F5B3A"),
            Flavor(name: "호두", english: "Walnut · 월넛", hex: "#A67B5B"),
        ]),
        FlavorCategory(name: "단맛", hex: "#E65832", flavors: [
            Flavor(name: "흑설탕", english: "Brown sugar · 브라운 슈가 · 황설탕", hex: "#D45A59"),
            Flavor(name: "바닐라", english: "Vanilla", hex: "#F89A80"),
            Flavor(name: "바닐린", english: "Vanillin", hex: "#F37674"),
            Flavor(name: "전체적 단맛", english: "Overall sweet · 스위트 · 단맛", hex: "#E75B68"),
            Flavor(name: "달콤한 향", english: "Sweet aromatics", hex: "#D0545F"),
            Flavor(name: "당밀", english: "Molasses · 몰라세스", hex: "#310D0F"),
            Flavor(name: "메이플 시럽", english: "Maple syrup · Maple · 메이플", hex: "#AE341F"),
            Flavor(name: "캐러멜", english: "Caramelized · Caramel · 카라멜 · 캬라멜 · 카라멜라이즈", hex: "#D78823"),
            Flavor(name: "꿀", english: "Honey · 허니 · 꿀향 · 아카시아 꿀", hex: "#DA5C1F"),
            Flavor(name: "흑당", english: "Black sugar · Muscovado · 무스코바도", hex: "#7A3020"),
            Flavor(name: "조청", english: "Rice syrup · 물엿", hex: "#C86A2C"),
            Flavor(name: "토피", english: "Toffee · 태피", hex: "#B9662A"),
            Flavor(name: "누가", english: "Nougat · 누갓", hex: "#EFB694"),
            Flavor(name: "크리미", english: "Creamy · 크림 · 연유 · 밀키 · 우유", hex: "#F5C6B0"),
            Flavor(name: "버터", english: "Butter · Buttery", hex: "#F0C070"),
            Flavor(name: "콜라", english: "Cola", hex: "#8C3A2A"),
        ]),
        FlavorCategory(name: "꽃", hex: "#DA0D68", flavors: [
            Flavor(name: "홍차", english: "Black tea · 블랙티", hex: "#975E6D"),
            Flavor(name: "꽃향", english: "Floral · 플로럴 · 플로랄 · 플라워 · 꽃", hex: "#E0719C"),
            Flavor(name: "캐모마일", english: "Chamomile · 카모마일 · 카밀레", hex: "#F99E1C"),
            Flavor(name: "장미", english: "Rose · 로즈", hex: "#EF5A78"),
            Flavor(name: "자스민", english: "Jasmine · 재스민 · 쟈스민", hex: "#F7F1BD"),
            Flavor(name: "라벤더", english: "Lavender", hex: "#B08BC9"),
            Flavor(name: "얼그레이", english: "Earl Grey · 베르가못 · 베르가모트", hex: "#7E5A6E"),
            Flavor(name: "히비스커스", english: "Hibiscus", hex: "#C2185B"),
        ]),
    ]

    static let all: [Flavor] = categories.flatMap(\.flavors)

    static func flavor(named name: String) -> Flavor? { all.first { $0.name == name } }

    /// 원문(로스터 표기/영문/별칭) → 휠의 표준 이름.
    /// 1) 이름 정확 일치 2) 이름·english 별칭(" · " 분리) 대소문자·공백·하이픈 무시 일치
    /// 3) 원문이 알려진 이름(2자 이상)을 포함하면 그 이름 (가장 긴 것) 4) nil
    static func canonicalName(_ raw: String) -> String? {
        if let f = flavor(named: raw) { return f.name }
        let key = matchKey(raw)
        guard !key.isEmpty else { return nil }
        if let f = all.first(where: { matchKey($0.name) == key || $0.english.components(separatedBy: " · ").contains { matchKey($0) == key } }) {
            return f.name
        }
        return all.map(\.name).filter { $0.count >= 2 && raw.contains($0) }.max { $0.count < $1.count }
    }

    static func color(for name: String) -> Color { canonicalName(name).flatMap { flavor(named: $0) }?.color ?? .gray }
}

/// 대소문자·공백·하이픈을 무시한 비교 키. FlavorWheel·BeanOptions의 canonicalName 공용.
func matchKey(_ s: String) -> String { s.lowercased().filter { !$0.isWhitespace && $0 != "-" && $0 != "–" } }

extension Color {
    /// "#RRGGBB" 또는 "RRGGBB"
    init(hex: String) {
        var h = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
        let v = UInt64(h, radix: 16) ?? 0x808080
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}
