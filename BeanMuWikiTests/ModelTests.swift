import Testing
import SwiftData
import UIKit
@testable import BeanMuWiki

@MainActor
struct ModelTests {
    @Test func ratioText() {
        let brew = Brew()
        brew.doseGrams = 15; brew.waterGrams = 240
        #expect(brew.ratioText == "1:16")
        brew.doseGrams = 14; brew.waterGrams = 200
        #expect(brew.ratioText == "1:14.3")
        brew.doseGrams = 0
        #expect(brew.ratioText == nil)
        brew.doseGrams = nil
        #expect(brew.ratioText == nil)
    }

    @Test func stars() {
        let brew = Brew()
        brew.rating = 0; #expect(brew.stars == "☆☆☆☆☆")
        brew.rating = 3; #expect(brew.stars == "★★★☆☆")
        brew.rating = 5; #expect(brew.stars == "★★★★★")
    }

    @Test func favoriteBrewPrefersStarThenLatest() throws {
        let container = try makeContainer(); let context = container.mainContext
        let bean = Bean(name: "A"); context.insert(bean)
        let old = Brew(); old.date = .now.addingTimeInterval(-3600); context.insert(old); old.bean = bean
        let new = Brew(); context.insert(new); new.bean = bean
        #expect(bean.favoriteBrew === new)
        old.isFavorite = true
        #expect(bean.favoriteBrew === old)
    }

    /// ICED ★를 지정해도 HOT ★는 남는다. 같은 서빙의 ★만 교체된다
    @Test func favoritePerServing() throws {
        let container = try makeContainer(); let context = container.mainContext
        let bean = Bean(name: "A"); context.insert(bean)
        let hot = Brew(); context.insert(hot); hot.bean = bean
        let hot2 = Brew(); context.insert(hot2); hot2.bean = bean
        let iced = Brew(); iced.isIced = true; context.insert(iced); iced.bean = bean
        bean.setFavorite(hot)
        bean.setFavorite(iced)
        #expect(hot.isFavorite && iced.isFavorite)
        #expect(bean.favoriteBrew(iced: true) === iced && bean.favoriteBrew(iced: false) === hot && bean.favoriteBrew === hot)
        bean.setFavorite(hot2)
        #expect(!hot.isFavorite && hot2.isFavorite && iced.isFavorite)
        #expect(bean.favoriteBrew === hot2)
    }

    @Test func templateCopiesRecipeButNotEvaluation() {
        let src = Brew()
        src.method = "칼리타"; src.doseGrams = 20; src.waterGrams = 300; src.waterTempC = 90
        src.grind = "22"; src.time = "3:00"; src.rating = 5; src.notes = "x"; src.isFavorite = true
        src.isIced = true; src.iceGrams = 100
        src.steps = [PourStep(atSeconds: 0, grams: 60, note: "블룸")]
        let copy = Brew(template: src)
        #expect(copy.method == "칼리타" && copy.doseGrams == 20 && copy.waterGrams == 300)
        #expect(copy.waterTempC == 90 && copy.grind == "22" && copy.time == "3:00" && copy.steps == src.steps)
        #expect(copy.isIced && copy.iceGrams == 100)
        #expect(copy.rating == 3 && copy.notes == "" && copy.isFavorite == false)
    }

    @Test func finalRatioText() {
        let brew = Brew()
        brew.doseGrams = 20; brew.waterGrams = 180
        #expect(brew.finalRatioText == "1:9" && brew.servingLabel == "HOT")   // HOT은 ratioText와 같다
        brew.isIced = true
        #expect(brew.finalRatioText == nil && brew.servingLabel == "ICED")     // 얼음 없는 ICED
        brew.iceGrams = 120
        #expect(brew.ratioText == "1:9" && brew.finalRatioText == "1:15")
    }

    @Test func pourStepTimeParsing() {
        #expect(PourStep.seconds(from: "45") == 45)
        #expect(PourStep.seconds(from: "1:15") == 75)
        #expect(PourStep.seconds(from: "01:15") == 75)
        #expect(PourStep.seconds(from: " 2:45 ") == 165)
        #expect(PourStep.seconds(from: "1:") == nil && PourStep.seconds(from: "1:75") == nil && PourStep.seconds(from: "") == nil)
        #expect(PourStep.timeString(45) == "0:45" && PourStep.timeString(165) == "2:45")
    }

    @Test func stepsSummary() {
        let brew = Brew()
        #expect(brew.stepsSummary == nil)
        brew.steps = [PourStep(atSeconds: 0, grams: 45, note: "블룸"), PourStep(atSeconds: 165, grams: 240, note: "")]
        #expect(brew.stepsSummary == "2단계 · 0:00 45g → 2:45 240g")
        brew.steps = [PourStep(atSeconds: 0, grams: 45.5, note: "")]
        #expect(brew.stepsSummary == "1단계 · 0:00 45.5g")   // 한 단계면 화살표 없음
    }

    @Test func pageURLAddsScheme() {
        let bean = Bean()
        #expect(bean.pageURL == nil)
        bean.url = " fritz.co.kr/kenya "
        #expect(bean.pageURL?.absoluteString == "https://fritz.co.kr/kenya")
        bean.url = "http://example.com"
        #expect(bean.pageURL?.absoluteString == "http://example.com")
    }

    @Test func splitCupNotesTrimsAndDedupes() {
        #expect(splitCupNotes(" 레몬, 꿀 ,, 레몬 ", excluding: ["꿀"]) == ["레몬"])
        #expect(splitCupNotes("") == [])
    }

    @Test func compressedPhotoShrinksToMax1200KeepingAspect() throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let big = UIGraphicsImageRenderer(size: CGSize(width: 2400, height: 1600), format: format)
            .jpegData(withCompressionQuality: 0.9) { ctx in
                UIColor.red.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 2400, height: 1600))
            }
        let small = try #require(Bean.compressedPhoto(big))
        let image = try #require(UIImage(data: small))
        #expect(image.size.width <= 1200 && image.size.height <= 1200)
        #expect(abs(image.size.width / image.size.height - 1.5) < 0.01)
        #expect(Bean.compressedPhoto(Data("not an image".utf8)) == nil)
    }
}

@MainActor
struct ImportTests {
    /// ChatGPT가 코드블록 안에 출력한 형태 그대로
    let json = """
    ```json
    {
      "bean": { "name": "Kenya AA", "roaster": "Fritz", "url": "fritz.co.kr/kenya", "roastLevel": "약배전", "cupNotes": ["자몽", "흑설탕"] },
      "brews": [ { "method": "V60", "doseGrams": 15, "waterGrams": 240, "waterTempC": 93.4,
                   "grind": "홀츠클로츠 E80 33 Step (약 743 μm)", "time": "2:30", "notes": "블룸 45g", "isFavorite": true } ]
    }
    ```
    """

    @Test func parseIgnoresSurroundingText() throws {
        let imported = try BeanImport.parse("설명 텍스트\n" + json + "\n끝")
        #expect(imported.bean.name == "Kenya AA")
        #expect(imported.brews?.count == 1)
    }

    @Test func parseRejectsGarbageAndEmptyName() {
        #expect(throws: DecodingError.self) { _ = try BeanImport.parse("no json here") }
        #expect(throws: DecodingError.self) { _ = try BeanImport.parse("{\"bean\":{\"name\":\"\"}}") }
    }

    @Test func applyCreatesBeanAndBrew() throws {
        let container = try makeContainer(); let context = container.mainContext
        let bean = try BeanImport.parse(json).apply(to: context, existing: [])
        #expect(bean.roaster == "Fritz" && bean.roastLevel == "라이트" && bean.cupNotes == ["자몽", "흑설탕"])   // 약배전 → 라이트
        #expect(bean.pageURL?.absoluteString == "https://fritz.co.kr/kenya")
        let brew = try #require(bean.brews.first)
        #expect(brew.waterTempC == 93 && brew.ratioText == "1:16" && brew.rating == 0 && brew.isFavorite)
        #expect(try context.fetchCount(FetchDescriptor<Bean>()) == 1)
    }

    /// steps의 at은 "m:ss"·숫자 모두 허용, grams 없는 항목은 제외, waterGrams가 없으면 마지막 단계에서 채운다
    @Test func applyMapsStepsAndFillsWaterFromLastStep() throws {
        let container = try makeContainer(); let context = container.mainContext
        let json = """
        {"bean": {"name": "B"}, "brews": [{"method": "V60", "doseGrams": 15, "steps": [
          {"at": "0:00", "grams": 45, "note": "블룸"}, {"at": 45, "grams": 120}, {"at": "1:15", "note": "no grams"}, {"at": "2:45", "grams": 240, "note": "드리퍼 제거"} ]}]}
        """
        let brew = try #require(BeanImport.parse(json).apply(to: context, existing: []).brews.first)
        #expect(brew.steps == [PourStep(atSeconds: 0, grams: 45, note: "블룸"), PourStep(atSeconds: 45, grams: 120, note: ""),
                               PourStep(atSeconds: 165, grams: 240, note: "드리퍼 제거")])
        #expect(brew.waterGrams == 240 && brew.ratioText == "1:16")
    }

    @Test func applyAppendsToExistingBeanAndSwapsFavorite() throws {
        let container = try makeContainer(); let context = container.mainContext
        let existing = Bean(name: "Kenya AA"); existing.roaster = "원래 로스터리"; context.insert(existing)
        let old = Brew(); old.isFavorite = true; context.insert(old); old.bean = existing

        let target = try BeanImport.parse(json).apply(to: context, existing: [existing])
        #expect(target === existing)
        #expect(existing.roaster == "원래 로스터리")   // 기존 원두 정보는 덮어쓰지 않음
        #expect(existing.brews.count == 2)
        #expect(old.isFavorite == false)
        #expect(existing.brews.filter(\.isFavorite).count == 1)
        #expect(try context.fetchCount(FetchDescriptor<Bean>()) == 1)
    }

    /// 구 스키마 "V60 ICED"는 ICED + method "V60"으로, 새 스키마는 iced/iceGrams로. HOT의 iceGrams는 버린다
    @Test func importIcedLegacyMethodAndNewFlag() throws {
        let container = try makeContainer(); let context = container.mainContext
        let json = """
        {"bean": {"name": "I"}, "brews": [
          {"method": "V60 ICED", "doseGrams": 20, "waterGrams": 180, "isFavorite": true},
          {"method": "V60", "iced": true, "iceGrams": 120, "doseGrams": 20, "waterGrams": 180, "isFavorite": true},
          {"method": "V60", "iced": false, "iceGrams": 120, "doseGrams": 15, "waterGrams": 240, "isFavorite": true} ]}
        """
        let bean = try BeanImport.parse(json).apply(to: context, existing: [])
        let legacy = try #require(bean.brews.first { $0.isIced && $0.iceGrams == nil })
        #expect(legacy.method == "V60" && legacy.finalRatioText == nil)
        let iced = try #require(bean.brews.first { $0.iceGrams == 120 })
        #expect(iced.isIced && iced.method == "V60" && iced.ratioText == "1:9" && iced.finalRatioText == "1:15")
        let hot = try #require(bean.brews.first { !$0.isIced })
        #expect(hot.iceGrams == nil && hot.finalRatioText == "1:16")
        // ★는 서빙별로 하나: ICED 둘 중 나중 것, HOT 하나
        #expect(!legacy.isFavorite && iced.isFavorite && hot.isFavorite)
        #expect(bean.favoriteBrew(iced: true) === iced && bean.favoriteBrew === hot)
    }

    /// 구 스키마 "V60 ICED"와 새 스키마 iced:false가 함께 오면 method 표기가 이긴다 (ICED, iceGrams 유지)
    @Test func importLegacyIcedMethodBeatsIcedFalse() throws {
        let container = try makeContainer(); let context = container.mainContext
        let json = #"{"bean": {"name": "L"}, "brews": [{"method": "V60 ICED", "iced": false, "iceGrams": 120, "doseGrams": 20, "waterGrams": 180}]}"#
        let brew = try #require(BeanImport.parse(json).apply(to: context, existing: []).brews.first)
        #expect(brew.isIced && brew.method == "V60" && brew.iceGrams == 120 && brew.finalRatioText == "1:15")
    }

    /// 로스터 표기(영문·약배전·플로럴)는 목록 표준 이름으로, 같은 이름으로 합쳐지는 컵노트는 하나만 남긴다
    @Test func applyNormalizesRoasterWording() throws {
        let container = try makeContainer(); let context = container.mainContext
        let json = """
        {"bean": {"name": "N", "country": "Ethiopia", "variety": "Heirloom", "process": "Washed", "roastLevel": "약배전",
                  "cupNotes": ["플로럴", "레몬캔디", "유자", "라벤더", "복숭아", "Floral"]}}
        """
        let bean = try BeanImport.parse(json).apply(to: context, existing: [])
        #expect(bean.country == "에티오피아" && bean.variety == "헤어룸" && bean.process == "워시드" && bean.roastLevel == "라이트")
        #expect(bean.cupNotes == ["꽃향", "레몬", "유자", "라벤더", "복숭아"])
    }

    /// 목록에 없는 값은 원문 그대로 남긴다 (회색 칩으로 표시)
    @Test func applyKeepsUnknownValues() throws {
        let container = try makeContainer(); let context = container.mainContext
        let json = #"{"bean": {"name": "U", "variety": "루비", "cupNotes": ["빈카이브맛"]}}"#
        let bean = try BeanImport.parse(json).apply(to: context, existing: [])
        #expect(bean.variety == "루비" && bean.cupNotes == ["빈카이브맛"])
    }
}

/// 인메모리 컨테이너. 반환값을 테스트가 끝날 때까지 변수로 잡아 두어야 한다 — 컨테이너가 해제되면 mainContext 사용 시 SIGTRAP.
@MainActor
private func makeContainer() throws -> ModelContainer {
    try ModelContainer(for: Bean.self, Tombstone.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
}
