import Testing
import SwiftUI
@testable import BeanMuWiki

/// 로스터 표기(영문·별칭·오타)를 목록 표준 이름으로 되돌리는 canonicalName과 추출 카드 조건 요약
@MainActor
struct CanonicalNameTests {
    @Test(arguments: [
        ("플로럴", "꽃향"), ("Floral", "꽃향"), ("레몬캔디", "레몬"), ("유자", "유자"), ("라벤더", "라벤더"), ("  Lemon ", "레몬"),
    ])
    func flavorCanonicalName(raw: String, expected: String) {
        #expect(FlavorWheel.canonicalName(raw) == expected)
    }

    @Test func flavorUnknownStaysNilButKnownSubstringGetsColor() {
        #expect(FlavorWheel.canonicalName("빈카이브맛") == nil)
        #expect(FlavorWheel.color(for: "레몬캔디") != .gray)
        #expect(FlavorWheel.color(for: "빈카이브맛") == .gray)
    }

    @Test func optionCanonicalName() {
        #expect(BeanOptions.canonicalName("Heirloom", in: BeanOptions.varieties) == "헤어룸")
        #expect(BeanOptions.canonicalName("Washed", in: BeanOptions.processes) == "워시드")
        #expect(BeanOptions.canonicalName("Anaerobic Natural", in: BeanOptions.processes) == "무산소 내추럴")
        #expect(BeanOptions.canonicalName("약배전", in: BeanOptions.roastLevels) == "라이트")
        #expect(BeanOptions.canonicalName("미디엄라이트", in: BeanOptions.roastLevels) == "미디엄 라이트")
        #expect(BeanOptions.canonicalName("Ethiopia", in: BeanOptions.countries) == "에티오피아")
        #expect(BeanOptions.canonicalName("에디오피아", in: BeanOptions.countries) == "에티오피아")
        #expect(BeanOptions.canonicalName("없음", in: BeanOptions.countries) == nil)
    }

    @Test func conditionLineJoinsPresentPartsOnly() {
        let brew = Brew()
        #expect(brew.conditionLine == "")
        brew.doseGrams = 15; brew.waterGrams = 240; brew.waterTempC = 92; brew.grind = "E80 33"
        #expect(brew.conditionLine == "15g · 240g · 92℃ · E80 33 · 1:16")
        brew.waterTempC = nil; brew.grind = ""
        #expect(brew.conditionLine == "15g · 240g · 1:16")
        brew.isIced = true
        #expect(brew.conditionLine == "15g · 240g · 1:16")   // 얼음 없는 ICED는 HOT과 같다
        brew.iceGrams = 120
        #expect(brew.conditionLine == "15g · 240g · 1:16 · 얼음 120g · 최종 1:24")
    }

    @Test func grindSplitsIntoChipsAndNumbersLineOmitsIt() {
        let brew = Brew()
        brew.doseGrams = 20; brew.waterGrams = 180; brew.waterTempC = 94
        brew.grind = "타임모어 C3S 14클릭 · S5 PRO 4.0 · 코만단테 C40 22클릭"
        #expect(brew.grindParts == ["타임모어 C3S 14클릭", "S5 PRO 4.0", "코만단테 C40 22클릭"])
        #expect(brew.conditionLine == "20g · 180g · 94℃ · \(brew.grind) · 1:9")
        #expect(brew.conditionItems.map(\.label) == ["원두", "물", "온도", "비율"])
        #expect(brew.conditionItems.map(\.value) == ["20g", "180g", "94℃", "1:9"])
        brew.isIced = true; brew.iceGrams = 120
        #expect(brew.conditionItems.map(\.label) == ["원두", "물", "얼음", "온도", "비율", "최종"])
        #expect(brew.conditionItems.last?.value == "1:15")
    }

    @Test func flowTargetSplitsOutOfStepNote() {
        func split(_ n: String) -> (String?, String) { let r = PourStep(atSeconds: 0, grams: 0, note: n).flowSplit; return (r.flow, r.rest) }
        #expect(split("4~5 g/s · 가는 나선형") == ("4~5 g/s", "가는 나선형"))
        #expect(split("굵은 나선형 (8g/s)") == ("8 g/s", "굵은 나선형"))
        #expect(split("밸브 열기 · 2.5–3 g/s") == ("2.5–3 g/s", "밸브 열기"))
        #expect(split("센터 푸어") == (nil, "센터 푸어"))
        #expect(canonicalMethod("V60 NEO") == "V60 NEO" && canonicalMethod("하리오 V60 neo") == "V60 NEO" && canonicalMethod("v60") == "V60")
    }
}
