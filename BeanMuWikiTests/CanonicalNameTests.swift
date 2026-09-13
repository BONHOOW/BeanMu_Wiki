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
}
