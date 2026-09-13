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

import SwiftUI

struct Flavor: Hashable, Identifiable {
    let name: String      // 한국어 표시명, 앱 내 고유 키 (중복 금지)
    let english: String   // SCA 영문명
    let hex: String       // "#RRGGBB"
    var id: String { name }
    var color: Color { Color(hex: hex) }
}

struct FlavorCategory: Identifiable {
    let name: String      // 과일, 신맛/발효, 녹색/채소, 기타, 구운, 향신료, 견과/코코아, 단맛, 꽃
    let hex: String       // 카테고리 대표색
    let flavors: [Flavor] // tier-2 그룹명 먼저, 이어서 tier-3 항목 (휠 순서)
    var id: String { name }
    var color: Color { Color(hex: hex) }
}

enum FlavorWheel {
    static let categories: [FlavorCategory] = [
        FlavorCategory(name: "과일", hex: "#DA1D23", flavors: [
            Flavor(name: "베리", english: "Berry", hex: "#DD4C51"),
            Flavor(name: "건과일", english: "Dried fruit", hex: "#C94A44"),
            Flavor(name: "시트러스", english: "Citrus fruit", hex: "#F7A128"),
            Flavor(name: "블랙베리", english: "Blackberry", hex: "#3E0317"),
            Flavor(name: "라즈베리", english: "Raspberry", hex: "#E62969"),
            Flavor(name: "블루베리", english: "Blueberry", hex: "#6569B0"),
            Flavor(name: "딸기", english: "Strawberry", hex: "#EF2D36"),
            Flavor(name: "건포도", english: "Raisin", hex: "#B53B54"),
            Flavor(name: "말린 자두", english: "Prune", hex: "#A5446F"),
            Flavor(name: "코코넛", english: "Coconut", hex: "#F2684B"),
            Flavor(name: "체리", english: "Cherry", hex: "#E73451"),
            Flavor(name: "석류", english: "Pomegranate", hex: "#E65656"),
            Flavor(name: "파인애플", english: "Pineapple", hex: "#F89A1C"),
            Flavor(name: "포도", english: "Grape", hex: "#AEB92C"),
            Flavor(name: "사과", english: "Apple", hex: "#4EB849"),
            Flavor(name: "복숭아", english: "Peach", hex: "#F68A5C"),
            Flavor(name: "배", english: "Pear", hex: "#BAA635"),
            Flavor(name: "자몽", english: "Grapefruit", hex: "#F26355"),
            Flavor(name: "오렌지", english: "Orange", hex: "#E2631E"),
            Flavor(name: "레몬", english: "Lemon", hex: "#FDE404"),
            Flavor(name: "라임", english: "Lime", hex: "#7EB138"),
        ]),
        FlavorCategory(name: "신맛/발효", hex: "#EBB40F", flavors: [
            Flavor(name: "산미", english: "Sour", hex: "#E1C315"),
            Flavor(name: "시큼한 향", english: "Sour aromatics", hex: "#9EA718"),
            Flavor(name: "아세트산", english: "Acetic acid", hex: "#94A76F"),
            Flavor(name: "부티르산", english: "Butyric acid", hex: "#D0B24F"),
            Flavor(name: "이소발레르산", english: "Isovaleric acid", hex: "#8EB646"),
            Flavor(name: "구연산", english: "Citric acid", hex: "#FAEF07"),
            Flavor(name: "사과산", english: "Malic acid", hex: "#C1BA07"),
            Flavor(name: "와인", english: "Winey", hex: "#8F1C53"),
            Flavor(name: "위스키", english: "Whiskey", hex: "#B34039"),
            Flavor(name: "발효", english: "Fermented", hex: "#BA9232"),
            Flavor(name: "과숙", english: "Overripe", hex: "#8B6439"),
        ]),
        FlavorCategory(name: "녹색/채소", hex: "#187A2F", flavors: [
            Flavor(name: "올리브 오일", english: "Olive oil", hex: "#A2B029"),
            Flavor(name: "날것", english: "Raw", hex: "#718933"),
            Flavor(name: "풋내", english: "Green/Vegetative", hex: "#3AA255"),
            Flavor(name: "콩비린내", english: "Beany", hex: "#5E9A80"),
            Flavor(name: "덜 익은 과일", english: "Under-ripe", hex: "#A2BB2B"),
            Flavor(name: "완두콩 깍지", english: "Peapod", hex: "#62AA3C"),
            Flavor(name: "풋풋함", english: "Fresh", hex: "#03A653"),
            Flavor(name: "진한 녹색 채소", english: "Dark green", hex: "#038549"),
            Flavor(name: "채소", english: "Vegetative", hex: "#28B44B"),
            Flavor(name: "건초", english: "Hay-like", hex: "#A3A830"),
            Flavor(name: "허브", english: "Herb-like", hex: "#7AC141"),
        ]),
        FlavorCategory(name: "기타", hex: "#0AA3B5", flavors: [
            Flavor(name: "묵은내", english: "Stale", hex: "#8B8C90"),
            Flavor(name: "골판지", english: "Cardboard", hex: "#BEB276"),
            Flavor(name: "종이", english: "Papery", hex: "#D9D0C1"),
            Flavor(name: "나무", english: "Woody", hex: "#744E03"),
            Flavor(name: "곰팡내", english: "Moldy/Damp", hex: "#A3A36F"),
            Flavor(name: "먼지", english: "Musty/Dusty", hex: "#C9B583"),
            Flavor(name: "흙내", english: "Musty/Earthy", hex: "#978847"),
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
            Flavor(name: "담배", english: "Tobacco", hex: "#DFBD7E"),
            Flavor(name: "탄내", english: "Burnt", hex: "#BE8663"),
            Flavor(name: "시리얼", english: "Cereal", hex: "#DDAF61"),
            Flavor(name: "매캐함", english: "Acrid", hex: "#B9A449"),
            Flavor(name: "재", english: "Ashy", hex: "#899893"),
            Flavor(name: "스모키", english: "Smoky", hex: "#A1743B"),
            Flavor(name: "브라운 로스트", english: "Brown roast", hex: "#894810"),
            Flavor(name: "곡물", english: "Grain", hex: "#B7906F"),
            Flavor(name: "몰트", english: "Malt", hex: "#EB9D5F"),
        ]),
        FlavorCategory(name: "향신료", hex: "#AD213E", flavors: [
            Flavor(name: "톡 쏘는 향", english: "Pungent", hex: "#794752"),
            Flavor(name: "후추", english: "Pepper", hex: "#CC3D41"),
            Flavor(name: "갈색 향신료", english: "Brown spice", hex: "#B14D57"),
            Flavor(name: "아니스", english: "Anise", hex: "#C78936"),
            Flavor(name: "넛맥", english: "Nutmeg", hex: "#8C292C"),
            Flavor(name: "시나몬", english: "Cinnamon", hex: "#E5762E"),
            Flavor(name: "정향", english: "Clove", hex: "#A16C5A"),
        ]),
        FlavorCategory(name: "견과/코코아", hex: "#A87B64", flavors: [
            Flavor(name: "견과", english: "Nutty", hex: "#C78869"),
            Flavor(name: "코코아", english: "Cocoa", hex: "#BB764C"),
            Flavor(name: "땅콩", english: "Peanuts", hex: "#D4AD12"),
            Flavor(name: "헤이즐넛", english: "Hazelnut", hex: "#9D5433"),
            Flavor(name: "아몬드", english: "Almond", hex: "#C89F83"),
            Flavor(name: "초콜릿", english: "Chocolate", hex: "#692A19"),
            Flavor(name: "다크초콜릿", english: "Dark chocolate", hex: "#470604"),
        ]),
        FlavorCategory(name: "단맛", hex: "#E65832", flavors: [
            Flavor(name: "흑설탕", english: "Brown sugar", hex: "#D45A59"),
            Flavor(name: "바닐라", english: "Vanilla", hex: "#F89A80"),
            Flavor(name: "바닐린", english: "Vanillin", hex: "#F37674"),
            Flavor(name: "전체적 단맛", english: "Overall sweet", hex: "#E75B68"),
            Flavor(name: "달콤한 향", english: "Sweet aromatics", hex: "#D0545F"),
            Flavor(name: "당밀", english: "Molasses", hex: "#310D0F"),
            Flavor(name: "메이플 시럽", english: "Maple syrup", hex: "#AE341F"),
            Flavor(name: "캐러멜", english: "Caramelized", hex: "#D78823"),
            Flavor(name: "꿀", english: "Honey", hex: "#DA5C1F"),
        ]),
        FlavorCategory(name: "꽃", hex: "#DA0D68", flavors: [
            Flavor(name: "홍차", english: "Black tea", hex: "#975E6D"),
            Flavor(name: "꽃향", english: "Floral", hex: "#E0719C"),
            Flavor(name: "캐모마일", english: "Chamomile", hex: "#F99E1C"),
            Flavor(name: "장미", english: "Rose", hex: "#EF5A78"),
            Flavor(name: "자스민", english: "Jasmine", hex: "#F7F1BD"),
        ]),
    ]

    static let all: [Flavor] = categories.flatMap(\.flavors)

    static func flavor(named name: String) -> Flavor? { all.first { $0.name == name } }

    static func color(for name: String) -> Color { flavor(named: name)?.color ?? .gray }
}

extension Color {
    /// "#RRGGBB" 또는 "RRGGBB"
    init(hex: String) {
        var h = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
        let v = UInt64(h, radix: 16) ?? 0x808080
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}
