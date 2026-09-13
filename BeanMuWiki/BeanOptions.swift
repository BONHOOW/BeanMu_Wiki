// BeanOptions.swift
// 원두 카드 피커용 카테고리 목록 — 원산지(국기), 품종(계통), 가공 방식, 로스팅 포인트.
//
// Sources
//   품종 계통: World Coffee Research Arabica Variety Catalog https://varieties.worldcoffeeresearch.org
//             (bourbon, typica, sl28, sl34, java, batian, marsellesa, parainema, anacafe-14, centroamericano, milenio, starmaya, t5296)
//             WCR "History of Arabica", coffeereview.com/new-coffee-varieties (Sidra·Chiroso·Pink Bourbon·Wush Wush DNA 결과)
//             Sweet Maria's Coffee Library (wush-wush), Perfect Daily Grind, Royal Coffee (Colombian varieties)
//   가공 방식: gota.cafe/ko/learn/bean/processing (한국어 표기: 워시드·내추럴·허니·무산소 발효·카보닉 마세레이션·열충격·젖산 발효·효모 접종),
//             bwissue.com/tech_rnd/2386547 (무산소 vs 카보닉 마세레이션), Cafe Imports / Sweet Maria's process glossaries
//   로스팅:   SCA/Agtron Roast Color Classification (8 discs, #95 Very Light → #25 Very Dark), Sweet Maria's roast names,
//             bwissue.com/coffeestory/762804, beanoners.com (약배전·중배전·강배전 대응)
//   한국어 표기: terarosalibrary.com/brewing/5455 (티피카·부르봉·카투라·문도노보·카투아이·파카스·마라고지페·파카마라·게이샤),
//             국내 스페셜티 로스터리 상품명 관례 (빌라사르치/비야사르치, 우쉬우쉬/우시우시, 웰리쇼/월리쇼, 게이샤/게샤는 english에 병기)
//
// Contested placements (WCR DNA vs 로스터 관례 — 관례를 따르고 english에 힌트 병기)
//   시드라:     로스터는 "티피카×부르봉 교배"로 표기 → 교배·하이브리드. WCR/RD2 검사는 에티오피아 재래종 계통.
//   핑크 부르봉: 로스터는 부르봉 변이로 표기 → 부르봉 계열. 2023 RD2 Vision 검사는 부르봉·티피카와 무관, 에티오피아 계통.
//   SL34:      로스터는 SL28과 묶어 케냐 부르봉 계열로 표기 → 부르봉 계열. WCR 검사는 티피카 유전 그룹.
//   자바:       로스터는 티피카 계열로 표기 → 티피카 계열. WCR 검사는 에티오피아 재래종(Abyssinia) 선발.
//   치로소·우쉬우쉬: 콜롬비아에서 재배되지만 DNA상 에티오피아 재래종 → 에티오피아 재래종.
//   예멘·하와이·호주: 지리상 아시아·태평양으로 묶음. 하와이 🇺🇸, 윈난 🇨🇳.
//
// Color(hex:)는 FlavorWheel.swift에 정의됨 — 여기서 재정의하지 않음.

import SwiftUI

struct BeanOption: Hashable, Identifiable {
    let name: String       // 한국어 표시명, 고유 키 (같은 목록 안에서 중복 금지)
    let english: String    // 영문/원어 표기 + 검색용 별칭
    let emoji: String      // 국가는 국기 이모지, 나머지는 ""
    let hex: String        // 카테고리 색 또는 항목 고유 색 "#RRGGBB" (로스팅은 실제 원두색)
    var id: String { name }
    var color: Color { Color(hex: hex) }
}

struct BeanOptionGroup: Identifiable {
    let name: String
    let hex: String
    let options: [BeanOption]
    var id: String { name }
    var color: Color { Color(hex: hex) }
}

enum BeanOptions {
    // MARK: 원산지
    static let countries: [BeanOptionGroup] = [
        BeanOptionGroup(name: "아프리카", hex: "#C0673A", options: [
            BeanOption(name: "에티오피아", english: "Ethiopia", emoji: "🇪🇹", hex: "#C0673A"),
            BeanOption(name: "케냐", english: "Kenya", emoji: "🇰🇪", hex: "#C0673A"),
            BeanOption(name: "르완다", english: "Rwanda", emoji: "🇷🇼", hex: "#C0673A"),
            BeanOption(name: "부룬디", english: "Burundi", emoji: "🇧🇮", hex: "#C0673A"),
            BeanOption(name: "탄자니아", english: "Tanzania", emoji: "🇹🇿", hex: "#C0673A"),
            BeanOption(name: "우간다", english: "Uganda", emoji: "🇺🇬", hex: "#C0673A"),
            BeanOption(name: "콩고민주공화국", english: "DR Congo · Democratic Republic of the Congo", emoji: "🇨🇩", hex: "#C0673A"),
            BeanOption(name: "말라위", english: "Malawi", emoji: "🇲🇼", hex: "#C0673A"),
            BeanOption(name: "잠비아", english: "Zambia", emoji: "🇿🇲", hex: "#C0673A"),
            BeanOption(name: "짐바브웨", english: "Zimbabwe", emoji: "🇿🇼", hex: "#C0673A"),
        ]),
        BeanOptionGroup(name: "중앙아메리카·카리브", hex: "#3F8F6B", options: [
            BeanOption(name: "과테말라", english: "Guatemala", emoji: "🇬🇹", hex: "#3F8F6B"),
            BeanOption(name: "코스타리카", english: "Costa Rica", emoji: "🇨🇷", hex: "#3F8F6B"),
            BeanOption(name: "온두라스", english: "Honduras", emoji: "🇭🇳", hex: "#3F8F6B"),
            BeanOption(name: "엘살바도르", english: "El Salvador", emoji: "🇸🇻", hex: "#3F8F6B"),
            BeanOption(name: "니카라과", english: "Nicaragua", emoji: "🇳🇮", hex: "#3F8F6B"),
            BeanOption(name: "파나마", english: "Panama", emoji: "🇵🇦", hex: "#3F8F6B"),
            BeanOption(name: "멕시코", english: "Mexico", emoji: "🇲🇽", hex: "#3F8F6B"),
            BeanOption(name: "자메이카", english: "Jamaica", emoji: "🇯🇲", hex: "#3F8F6B"),
            BeanOption(name: "도미니카공화국", english: "Dominican Republic", emoji: "🇩🇴", hex: "#3F8F6B"),
            BeanOption(name: "쿠바", english: "Cuba", emoji: "🇨🇺", hex: "#3F8F6B"),
            BeanOption(name: "푸에르토리코", english: "Puerto Rico", emoji: "🇵🇷", hex: "#3F8F6B"),
            BeanOption(name: "아이티", english: "Haiti", emoji: "🇭🇹", hex: "#3F8F6B"),
        ]),
        BeanOptionGroup(name: "남아메리카", hex: "#D6A23A", options: [
            BeanOption(name: "브라질", english: "Brazil", emoji: "🇧🇷", hex: "#D6A23A"),
            BeanOption(name: "콜롬비아", english: "Colombia", emoji: "🇨🇴", hex: "#D6A23A"),
            BeanOption(name: "페루", english: "Peru", emoji: "🇵🇪", hex: "#D6A23A"),
            BeanOption(name: "볼리비아", english: "Bolivia", emoji: "🇧🇴", hex: "#D6A23A"),
            BeanOption(name: "에콰도르", english: "Ecuador", emoji: "🇪🇨", hex: "#D6A23A"),
            BeanOption(name: "베네수엘라", english: "Venezuela", emoji: "🇻🇪", hex: "#D6A23A"),
        ]),
        BeanOptionGroup(name: "아시아·태평양", hex: "#4C7BB0", options: [
            BeanOption(name: "인도네시아", english: "Indonesia", emoji: "🇮🇩", hex: "#4C7BB0"),
            BeanOption(name: "베트남", english: "Vietnam", emoji: "🇻🇳", hex: "#4C7BB0"),
            BeanOption(name: "인도", english: "India", emoji: "🇮🇳", hex: "#4C7BB0"),
            BeanOption(name: "파푸아뉴기니", english: "Papua New Guinea · PNG", emoji: "🇵🇬", hex: "#4C7BB0"),
            BeanOption(name: "예멘", english: "Yemen", emoji: "🇾🇪", hex: "#4C7BB0"),
            BeanOption(name: "중국(윈난)", english: "China · Yunnan", emoji: "🇨🇳", hex: "#4C7BB0"),
            BeanOption(name: "태국", english: "Thailand", emoji: "🇹🇭", hex: "#4C7BB0"),
            BeanOption(name: "미얀마", english: "Myanmar", emoji: "🇲🇲", hex: "#4C7BB0"),
            BeanOption(name: "라오스", english: "Laos", emoji: "🇱🇦", hex: "#4C7BB0"),
            BeanOption(name: "필리핀", english: "Philippines", emoji: "🇵🇭", hex: "#4C7BB0"),
            BeanOption(name: "동티모르", english: "Timor-Leste · East Timor", emoji: "🇹🇱", hex: "#4C7BB0"),
            BeanOption(name: "대만", english: "Taiwan", emoji: "🇹🇼", hex: "#4C7BB0"),
            BeanOption(name: "네팔", english: "Nepal", emoji: "🇳🇵", hex: "#4C7BB0"),
            BeanOption(name: "하와이(미국)", english: "Hawaii · USA · Kona", emoji: "🇺🇸", hex: "#4C7BB0"),
            BeanOption(name: "호주", english: "Australia", emoji: "🇦🇺", hex: "#4C7BB0"),
        ]),
    ]

    // MARK: 품종
    static let varieties: [BeanOptionGroup] = [
        BeanOptionGroup(name: "에티오피아 재래종", hex: "#B8465A", options: [
            BeanOption(name: "게이샤", english: "Geisha · Gesha · 게샤", emoji: "", hex: "#B8465A"),
            BeanOption(name: "헤어룸", english: "Heirloom · Landrace · 에어룸 · 재래종", emoji: "", hex: "#B8465A"),
            BeanOption(name: "74110", english: "JARC 74110", emoji: "", hex: "#B8465A"),
            BeanOption(name: "74158", english: "JARC 74158", emoji: "", hex: "#B8465A"),
            BeanOption(name: "74112", english: "JARC 74112", emoji: "", hex: "#B8465A"),
            BeanOption(name: "웰리쇼", english: "Wolisho · Welicho · 월리쇼", emoji: "", hex: "#B8465A"),
            BeanOption(name: "쿠루메", english: "Kurume", emoji: "", hex: "#B8465A"),
            BeanOption(name: "데가", english: "Dega", emoji: "", hex: "#B8465A"),
            BeanOption(name: "우쉬우쉬", english: "Wush Wush · 우시우시 · 웨시웨시", emoji: "", hex: "#B8465A"),
            BeanOption(name: "치로소", english: "Chiroso", emoji: "", hex: "#B8465A"),
        ]),
        BeanOptionGroup(name: "티피카 계열", hex: "#7A9B57", options: [
            BeanOption(name: "티피카", english: "Typica", emoji: "", hex: "#7A9B57"),
            BeanOption(name: "마라고지페", english: "Maragogipe · Maragogype · 마라고지피", emoji: "", hex: "#7A9B57"),
            BeanOption(name: "블루마운틴", english: "Blue Mountain · 블루 마운틴", emoji: "", hex: "#7A9B57"),
            BeanOption(name: "코나", english: "Kona · Guatemalan Typica", emoji: "", hex: "#7A9B57"),
            BeanOption(name: "자바", english: "Java · Abyssinia", emoji: "", hex: "#7A9B57"),
            BeanOption(name: "크리오요", english: "Criollo", emoji: "", hex: "#7A9B57"),
            BeanOption(name: "산 라몬", english: "San Ramon · 산라몬", emoji: "", hex: "#7A9B57"),
        ]),
        BeanOptionGroup(name: "부르봉 계열", hex: "#C64C3B", options: [
            BeanOption(name: "부르봉", english: "Bourbon · 버번", emoji: "", hex: "#C64C3B"),
            BeanOption(name: "레드 부르봉", english: "Red Bourbon", emoji: "", hex: "#C64C3B"),
            BeanOption(name: "옐로 부르봉", english: "Yellow Bourbon · 옐로우 부르봉", emoji: "", hex: "#C64C3B"),
            BeanOption(name: "오렌지 부르봉", english: "Orange Bourbon", emoji: "", hex: "#C64C3B"),
            BeanOption(name: "핑크 부르봉", english: "Pink Bourbon · 핑크부르봉", emoji: "", hex: "#C64C3B"),
            BeanOption(name: "카투라", english: "Caturra · 까뚜라", emoji: "", hex: "#C64C3B"),
            BeanOption(name: "파카스", english: "Pacas", emoji: "", hex: "#C64C3B"),
            BeanOption(name: "빌라사르치", english: "Villa Sarchi · 비야사르치 · 빌라 사르치", emoji: "", hex: "#C64C3B"),
            BeanOption(name: "SL28", english: "SL28 · SL-28", emoji: "", hex: "#C64C3B"),
            BeanOption(name: "SL34", english: "SL34 · SL-34", emoji: "", hex: "#C64C3B"),
            BeanOption(name: "테키식", english: "Tekisic · Tekisik · 테키시크", emoji: "", hex: "#C64C3B"),
            BeanOption(name: "라우리나", english: "Laurina · Bourbon Pointu · 부르봉 포인투", emoji: "", hex: "#C64C3B"),
            BeanOption(name: "잭슨", english: "Jackson", emoji: "", hex: "#C64C3B"),
            BeanOption(name: "미비리지", english: "Mibirizi", emoji: "", hex: "#C64C3B"),
        ]),
        BeanOptionGroup(name: "교배·하이브리드", hex: "#5B7FA6", options: [
            BeanOption(name: "문도노보", english: "Mundo Novo · 문도 노보", emoji: "", hex: "#5B7FA6"),
            BeanOption(name: "카투아이", english: "Catuai · Catuaí · 까뚜아이", emoji: "", hex: "#5B7FA6"),
            BeanOption(name: "아카이아", english: "Acaiá · Acaia", emoji: "", hex: "#5B7FA6"),
            BeanOption(name: "카투카이", english: "Catucaí · Catucai", emoji: "", hex: "#5B7FA6"),
            BeanOption(name: "아라라", english: "Arara", emoji: "", hex: "#5B7FA6"),
            BeanOption(name: "파카마라", english: "Pacamara", emoji: "", hex: "#5B7FA6"),
            BeanOption(name: "마라카투라", english: "Maracaturra · Maracatu", emoji: "", hex: "#5B7FA6"),
            BeanOption(name: "시드라", english: "Sidra · Typica Mejorado · 시드라 부르봉", emoji: "", hex: "#5B7FA6"),
            BeanOption(name: "티모르 하이브리드", english: "Timor Hybrid · HdT · 티모르", emoji: "", hex: "#5B7FA6"),
            BeanOption(name: "카티모르", english: "Catimor · 까띠모르", emoji: "", hex: "#5B7FA6"),
            BeanOption(name: "사치모르", english: "Sarchimor · 사르치모르", emoji: "", hex: "#5B7FA6"),
            BeanOption(name: "카스티요", english: "Castillo · 까스티요", emoji: "", hex: "#5B7FA6"),
            BeanOption(name: "콜롬비아", english: "Colombia (variety) · Variedad Colombia", emoji: "", hex: "#5B7FA6"),
            BeanOption(name: "세니카페 1", english: "Cenicafé 1 · Cenicafe 1", emoji: "", hex: "#5B7FA6"),
            BeanOption(name: "마르셀레사", english: "Marsellesa · 마르세예사", emoji: "", hex: "#5B7FA6"),
            BeanOption(name: "오바타", english: "Obatã · Obata", emoji: "", hex: "#5B7FA6"),
            BeanOption(name: "파라이네마", english: "Parainema", emoji: "", hex: "#5B7FA6"),
            BeanOption(name: "루이루 11", english: "Ruiru 11", emoji: "", hex: "#5B7FA6"),
            BeanOption(name: "바티안", english: "Batian", emoji: "", hex: "#5B7FA6"),
            BeanOption(name: "S795", english: "S795 · Selection 795 · Jember", emoji: "", hex: "#5B7FA6"),
            BeanOption(name: "센트로아메리카노", english: "Centroamericano · H1 · F1 Hybrid", emoji: "", hex: "#5B7FA6"),
            BeanOption(name: "밀레니오", english: "Milenio · H10 · F1 Hybrid", emoji: "", hex: "#5B7FA6"),
            BeanOption(name: "스타마야", english: "Starmaya · F1 Hybrid", emoji: "", hex: "#5B7FA6"),
            BeanOption(name: "아나카페 14", english: "Anacafe 14 · Anacafé 14", emoji: "", hex: "#5B7FA6"),
        ]),
        BeanOptionGroup(name: "기타 종", hex: "#8A7565", options: [
            BeanOption(name: "로부스타", english: "Robusta · Coffea canephora · 카네포라", emoji: "", hex: "#8A7565"),
            BeanOption(name: "리베리카", english: "Liberica · Coffea liberica", emoji: "", hex: "#8A7565"),
            BeanOption(name: "엑셀사", english: "Excelsa · Coffea excelsa", emoji: "", hex: "#8A7565"),
            BeanOption(name: "유게니오이데스", english: "Eugenioides · Coffea eugenioides", emoji: "", hex: "#8A7565"),
            BeanOption(name: "블렌드", english: "Blend · Mixed varieties · 아라비카 블렌드", emoji: "", hex: "#8A7565"),
            BeanOption(name: "미상", english: "Unknown · Various · 아라비카 미상", emoji: "", hex: "#8A7565"),
        ]),
    ]

    // MARK: 가공 방식
    static let processes: [BeanOptionGroup] = [
        BeanOptionGroup(name: "워시드", hex: "#4A90C2", options: [
            BeanOption(name: "워시드", english: "Washed · Wet Process · 수세식", emoji: "", hex: "#4A90C2"),
            BeanOption(name: "풀리 워시드", english: "Fully Washed", emoji: "", hex: "#4A90C2"),
            BeanOption(name: "케냐식 더블 워시드", english: "Kenya Double Washed · Double Fermentation Washed · 켄야식", emoji: "", hex: "#4A90C2"),
            BeanOption(name: "세미 워시드", english: "Semi-Washed · Ecopulped · Mechanical Demucilage", emoji: "", hex: "#4A90C2"),
            BeanOption(name: "웻 헐드", english: "Wet Hulled · Giling Basah · 길링 바사", emoji: "", hex: "#4A90C2"),
            BeanOption(name: "웻 폴리시드", english: "Wet Polished", emoji: "", hex: "#4A90C2"),
        ]),
        BeanOptionGroup(name: "내추럴", hex: "#D9873A", options: [
            BeanOption(name: "내추럴", english: "Natural · Dry Process · 건식", emoji: "", hex: "#D9873A"),
            BeanOption(name: "드라이 프로세스", english: "Dry Process · Unwashed", emoji: "", hex: "#D9873A"),
            BeanOption(name: "선 드라이드", english: "Sun-dried · 선드라이", emoji: "", hex: "#D9873A"),
            BeanOption(name: "패치 드라이드", english: "Patio Dried", emoji: "", hex: "#D9873A"),
        ]),
        BeanOptionGroup(name: "허니·펄프드 내추럴", hex: "#D4A83C", options: [
            BeanOption(name: "허니", english: "Honey Process · 하니", emoji: "", hex: "#D4A83C"),
            BeanOption(name: "펄프드 내추럴", english: "Pulped Natural", emoji: "", hex: "#D4A83C"),
            BeanOption(name: "화이트 허니", english: "White Honey", emoji: "", hex: "#D4A83C"),
            BeanOption(name: "옐로 허니", english: "Yellow Honey · Golden Honey · 골든 허니", emoji: "", hex: "#D4A83C"),
            BeanOption(name: "레드 허니", english: "Red Honey", emoji: "", hex: "#D4A83C"),
            BeanOption(name: "블랙 허니", english: "Black Honey", emoji: "", hex: "#D4A83C"),
        ]),
        BeanOptionGroup(name: "발효·실험적", hex: "#8E5AA8", options: [
            BeanOption(name: "무산소 발효", english: "Anaerobic · Anaerobic Fermentation · 애너에어로빅", emoji: "", hex: "#8E5AA8"),
            BeanOption(name: "무산소 워시드", english: "Anaerobic Washed", emoji: "", hex: "#8E5AA8"),
            BeanOption(name: "무산소 내추럴", english: "Anaerobic Natural", emoji: "", hex: "#8E5AA8"),
            BeanOption(name: "무산소 허니", english: "Anaerobic Honey", emoji: "", hex: "#8E5AA8"),
            BeanOption(name: "카보닉 마세레이션", english: "Carbonic Maceration · CM · 탄산 침용", emoji: "", hex: "#8E5AA8"),
            BeanOption(name: "써멀 쇼크", english: "Thermal Shock · 열충격", emoji: "", hex: "#8E5AA8"),
            BeanOption(name: "이스트 접종", english: "Yeast Inoculated · 효모 접종", emoji: "", hex: "#8E5AA8"),
            BeanOption(name: "락틱", english: "Lactic · Lactic Fermentation · 젖산 발효", emoji: "", hex: "#8E5AA8"),
            BeanOption(name: "코퍼먼트", english: "Co-ferment · Co-fermentation · 코퍼멘테이션", emoji: "", hex: "#8E5AA8"),
            BeanOption(name: "인퓨즈드", english: "Infused · 인퓨전", emoji: "", hex: "#8E5AA8"),
            BeanOption(name: "배럴 에이지드", english: "Barrel Aged · 배럴 에이징", emoji: "", hex: "#8E5AA8"),
            BeanOption(name: "익스텐디드 퍼먼테이션", english: "Extended Fermentation · 장기 발효", emoji: "", hex: "#8E5AA8"),
            BeanOption(name: "더블 퍼먼테이션", english: "Double Fermentation · 이중 발효", emoji: "", hex: "#8E5AA8"),
        ]),
        BeanOptionGroup(name: "기타", hex: "#7D8A8F", options: [
            BeanOption(name: "몬순드", english: "Monsooned · Monsoon Malabar · 몬순 말라바르", emoji: "", hex: "#7D8A8F"),
            BeanOption(name: "디카페인", english: "Decaf · Decaffeinated", emoji: "", hex: "#7D8A8F"),
            BeanOption(name: "디카페인 스위스 워터", english: "Swiss Water Decaf · SWP", emoji: "", hex: "#7D8A8F"),
            BeanOption(name: "디카페인 슈가케인(EA)", english: "Sugarcane Decaf · Ethyl Acetate · EA", emoji: "", hex: "#7D8A8F"),
            BeanOption(name: "디카페인 CO2", english: "CO2 Decaf · Supercritical CO2", emoji: "", hex: "#7D8A8F"),
            BeanOption(name: "디카페인 마운틴 워터", english: "Mountain Water Decaf · MWP", emoji: "", hex: "#7D8A8F"),
            BeanOption(name: "와인 프로세스", english: "Wine Process · Winey", emoji: "", hex: "#7D8A8F"),
            BeanOption(name: "미상", english: "Unknown", emoji: "", hex: "#7D8A8F"),
        ]),
    ]

    // MARK: 로스팅 포인트 (밝은 → 어두운 순, hex = 실제 원두색 근사)
    static let roastLevels: [BeanOptionGroup] = [
        BeanOptionGroup(name: "로스팅 포인트", hex: "#7F5A38", options: [
            BeanOption(name: "라이트", english: "Light · 약배전 · 시나몬 · Agtron 75+", emoji: "", hex: "#C9A277"),
            BeanOption(name: "라이트 미디엄", english: "Light Medium · 중약배전 · 뉴잉글랜드 · Agtron 65–75", emoji: "", hex: "#B38A5C"),
            BeanOption(name: "미디엄 라이트", english: "Medium Light · 중약배전 · 시티 초입 · Agtron 60–65", emoji: "", hex: "#9C7247"),
            BeanOption(name: "미디엄", english: "Medium · 중배전 · 시티 · Agtron 55–60", emoji: "", hex: "#7F5A38"),
            BeanOption(name: "미디엄 다크", english: "Medium Dark · 중강배전 · 풀시티 · Agtron 45–55", emoji: "", hex: "#62432A"),
            BeanOption(name: "다크", english: "Dark · 강배전 · 프렌치 · 비엔나 · Agtron 35–45", emoji: "", hex: "#452D1C"),
            BeanOption(name: "베리 다크", english: "Very Dark · 강배전 · 이탈리안 · Agtron 35 이하", emoji: "", hex: "#2A1A10"),
        ]),
    ]

    /// 네 목록 어디서든 이름으로 찾기 (표시용 이모지/색)
    static func option(named name: String, in groups: [BeanOptionGroup]) -> BeanOption? {
        for g in groups { if let o = g.options.first(where: { $0.name == name }) { return o } }
        return nil
    }
}
