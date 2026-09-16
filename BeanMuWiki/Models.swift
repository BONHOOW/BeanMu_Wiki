import Foundation
import ImageIO
import SwiftData
import UniformTypeIdentifiers

@Model
final class Bean {
    var name = ""
    var roaster = ""
    var country = ""      // 원산지(국가)
    var region = ""       // 산지 / 재배지
    var farm = ""
    var altitude = ""     // "1,900~2,100m" 같은 범위 표기가 흔해 문자열
    var variety = ""
    var process = ""
    var roastLevel = ""   // 로스팅 포인트
    var url = ""          // 판매 페이지
    @Attribute(.externalStorage) var photo: Data?   // 패키지 사진 (긴 변 1200px JPEG)
    var cupNotes: [String] = []
    var memo = ""
    var createdAt = Date.now
    var uuid = UUID()             // 기기 간 동일성 (동기화)
    var updatedAt = Date.now      // 마지막 수정 시각. LWW 병합 기준 — 필드를 바꾸면 갱신할 것
    var photoUpdatedAt: Date?     // 사진 변경 시각. 사진은 스냅샷과 별도로 동기화
    @Relationship(deleteRule: .cascade, inverse: \Brew.bean) var brews: [Brew] = []

    init(name: String = "") { self.name = name }

    /// HOT 기준 레시피(★) → 아무 서빙의 ★ → 가장 최근 기록
    var favoriteBrew: Brew? {
        brews.first { $0.isFavorite && !$0.isIced } ?? brews.first { $0.isFavorite } ?? brews.max { $0.date < $1.date }
    }

    /// 해당 서빙(HOT/ICED)의 기준 레시피(★), 없으면 그 서빙의 가장 최근 기록
    func favoriteBrew(iced: Bool) -> Brew? {
        let same = brews.filter { $0.isIced == iced }
        return same.first { $0.isFavorite } ?? same.max { $0.date < $1.date }
    }

    /// brew를 ★로. 같은 서빙의 다른 기록만 ★ 해제 (HOT과 ICED는 기준 레시피가 따로 있다)
    func setFavorite(_ brew: Brew) {
        for other in brews where other.isIced == brew.isIced && other !== brew && other.isFavorite {
            other.isFavorite = false; other.updatedAt = .now
        }
        if !brew.isFavorite { brew.isFavorite = true; brew.updatedAt = .now }
    }

    /// "fritz.co.kr/..."처럼 스킴이 없어도 열 수 있게 https를 붙인다.
    var pageURL: URL? {
        let s = url.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }
        return URL(string: s.contains("://") ? s : "https://" + s)
    }

    /// 사진을 긴 변 maxPixel 이하의 JPEG로 줄인다(EXIF 방향 반영). 이미지가 아니면 nil.
    static func compressedPhoto(_ data: Data, maxPixel: Int = 1200) -> Data? {
        let options = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                       kCGImageSourceCreateThumbnailWithTransform: true,
                       kCGImageSourceThumbnailMaxPixelSize: maxPixel] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, thumb, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        return CGImageDestinationFinalize(dest) ? out as Data : nil
    }
}

/// 푸어 한 단계. atSeconds = 타이머 기준 시작 시각, grams = 저울의 누적 목표
struct PourStep: Codable, Hashable {
    var atSeconds: Int
    var grams: Double
    var note: String

    /// "45", "1:15", "01:15", " 2:45 " → 초. 그 외 nil
    static func seconds(from text: String) -> Int? {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: ":", omittingEmptySubsequences: false)
        switch parts.count {
        case 1: return Int(parts[0]).flatMap { $0 >= 0 ? $0 : nil }
        case 2:
            guard let m = Int(parts[0]), let s = Int(parts[1]), m >= 0, (0..<60).contains(s) else { return nil }
            return m * 60 + s
        default: return nil
        }
    }

    /// 45 → "0:45"
    static func timeString(_ seconds: Int) -> String { "\(seconds / 60):" + String(format: "%02d", seconds % 60) }

    var timeText: String { Self.timeString(atSeconds) }
}

/// 레시피 + 테이스팅 기록. isFavorite = 이 원두의 서빙(HOT/ICED)별 기준 레시피
@Model
final class Brew {
    var date = Date.now
    var method = brewMethods[0]
    var isIced = false        // ICED = 브루잉 워터를 줄이고 서버에 얼음
    var doseGrams: Double?
    var waterGrams: Double?   // 브루잉 워터 총량. steps가 있으면 마지막 단계의 grams와 같다
    var iceGrams: Double?     // ICED만. 서버 얼음. 최종 음료 = waterGrams + iceGrams
    var waterTempC: Int?
    var grind = ""
    var time = ""         // 총 추출 시간 "2:45" 자유 텍스트
    var steps: [PourStep] = []
    var rating = 3        // 0 = 아직 안 마셔봄
    var notes = ""
    var isFavorite = false
    var bean: Bean?
    var uuid = UUID()             // 기기 간 동일성 (동기화)
    var updatedAt = Date.now      // 마지막 수정 시각. LWW 병합 기준 — 필드를 바꾸면 갱신할 것

    /// 레시피 값만 복사. uuid·updatedAt은 새 기록의 것 (새 identity)
    init(template: Brew? = nil) {
        if let template { copyRecipe(from: template) }
    }

    /// 레시피 값만 복사 (날짜·평가·★·노트 제외)
    func copyRecipe(from t: Brew) {
        method = t.method; isIced = t.isIced
        doseGrams = t.doseGrams; waterGrams = t.waterGrams; iceGrams = t.iceGrams; waterTempC = t.waterTempC
        grind = t.grind; time = t.time; steps = t.steps
    }

    var servingLabel: String { isIced ? "ICED" : "HOT" }

    /// 브루 비율 "1:16" (원두 : 브루잉 워터)
    var ratioText: String? { ratioText(water: waterGrams) }

    /// 최종 음료 비율. ICED는 (물+얼음)/원두, HOT은 ratioText와 같다. ICED인데 얼음이 없으면 nil
    var finalRatioText: String? {
        guard isIced else { return ratioText }
        guard let waterGrams, let iceGrams else { return nil }
        return ratioText(water: waterGrams + iceGrams)
    }

    private func ratioText(water: Double?) -> String? {
        guard let doseGrams, let water, doseGrams > 0 else { return nil }
        return "1:" + (water / doseGrams).formatted(.number.precision(.fractionLength(0...1)))
    }

    /// "5단계 · 0:00 45g → 2:45 240g"
    var stepsSummary: String? {
        guard let first = steps.first, let last = steps.last else { return nil }
        let g = { ($0 as Double).formatted(.number.precision(.fractionLength(0...1))) + "g" }
        var text = "\(steps.count)단계 · \(first.timeText) \(g(first.grams))"
        if steps.count > 1 { text += " → \(last.timeText) \(g(last.grams))" }
        return text
    }

    var stars: String {
        String(repeating: "★", count: max(0, min(5, rating))) + String(repeating: "☆", count: max(0, 5 - rating))
    }
}

/// 삭제 기록. 다른 기기에서 같은 항목을 되살리지 않도록 uuid를 남긴다 (90일 후 정리)
@Model
final class Tombstone {
    var uuid: UUID
    var kind: String          // "bean" | "brew"
    var deletedAt = Date.now

    init(uuid: UUID, kind: String) { self.uuid = uuid; self.kind = kind }
}

let brewMethods = ["V60", "칼리타", "오리가미", "하리오 스위치", "에어로프레스", "프렌치프레스", "모카포트", "에스프레소", "콜드브루", "기타"]

/// "레몬, 꿀,  " → ["레몬", "꿀"]. 공백 제거, 빈 항목과 중복(existing 포함) 제외.
func splitCupNotes(_ text: String, excluding existing: [String] = []) -> [String] {
    var seen = Set(existing)
    return text.split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty && seen.insert($0).inserted }
}

// MARK: - ChatGPT JSON 가져오기 (스키마: ChatGPT_Prompt.md의 📦 섹션)

struct BeanImport: Decodable {
    struct BeanDTO: Decodable {
        var name: String
        var roaster, country, region, farm, altitude, variety, process, roastLevel, url, memo: String?
        var cupNotes: [String]?
    }
    struct StepDTO: Decodable {
        var at: String?       // "m:ss" 또는 초. 숫자로 와도 문자열로 받는다
        var grams: Double?
        var note: String?

        private enum CodingKeys: CodingKey { case at, grams, note }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            at = (try? c.decode(String.self, forKey: .at)) ?? (try? c.decode(Double.self, forKey: .at)).map { String(Int($0)) }
            grams = try? c.decode(Double.self, forKey: .grams)
            note = try? c.decode(String.self, forKey: .note)
        }
    }
    struct BrewDTO: Decodable {
        var method, grind, time, notes: String?
        var doseGrams, waterGrams, iceGrams, waterTempC: Double?
        var rating: Int?
        var isFavorite, iced: Bool?
        var steps: [StepDTO]?
    }
    var bean: BeanDTO
    var brews: [BrewDTO]?

    /// 코드블록·설명이 섞여 있어도 첫 `{`부터 마지막 `}`까지만 파싱한다.
    static func parse(_ text: String) throws -> BeanImport {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "JSON 객체가 없습니다"))
        }
        let result = try JSONDecoder().decode(BeanImport.self, from: Data(text[start...end].utf8))
        guard !result.bean.name.isEmpty else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "bean.name이 비어 있습니다"))
        }
        return result
    }

    /// 같은 이름의 원두가 있으면 기록만 추가(모드 B), 없으면 새 원두 생성(모드 A). 반환: 대상 원두
    @discardableResult
    func apply(to context: ModelContext, existing: [Bean]) -> Bean {
        let target = existing.first { $0.name == bean.name } ?? makeBean(in: context)
        for dto in brews ?? [] {
            let brew = Brew()
            // 구 스키마 호환: "V60 ICED" → ICED + "V60"
            let method = (dto.method ?? "").replacingOccurrences(of: "ICED", with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespaces)
            brew.method = method.isEmpty ? brewMethods[0] : method
            brew.isIced = dto.iced == true || dto.method?.localizedCaseInsensitiveContains("ICED") == true
            brew.iceGrams = brew.isIced ? dto.iceGrams : nil
            brew.doseGrams = dto.doseGrams
            brew.steps = (dto.steps ?? []).compactMap { s in
                s.grams.map { PourStep(atSeconds: PourStep.seconds(from: s.at ?? "") ?? 0, grams: $0, note: s.note ?? "") }
            }
            brew.waterGrams = dto.waterGrams ?? brew.steps.last?.grams
            brew.waterTempC = dto.waterTempC.map { Int($0.rounded()) }
            brew.grind = dto.grind ?? ""
            brew.time = dto.time ?? ""
            brew.notes = dto.notes ?? ""
            brew.rating = dto.rating ?? 0
            if dto.isFavorite ?? false { target.setFavorite(brew) }
            context.insert(brew)
            brew.bean = target
        }
        return target
    }

    private func makeBean(in context: ModelContext) -> Bean {
        let b = Bean(name: bean.name)
        b.roaster = bean.roaster ?? ""
        b.country = canonical(bean.country, in: BeanOptions.countries)
        b.region = bean.region ?? ""
        b.farm = bean.farm ?? ""
        b.altitude = bean.altitude ?? ""
        b.variety = canonical(bean.variety, in: BeanOptions.varieties)
        b.process = canonical(bean.process, in: BeanOptions.processes)
        b.roastLevel = canonical(bean.roastLevel, in: BeanOptions.roastLevels)
        b.url = bean.url ?? ""
        var seen = Set<String>()
        b.cupNotes = (bean.cupNotes ?? []).map { FlavorWheel.canonicalName($0) ?? $0 }.filter { seen.insert($0).inserted }
        b.memo = bean.memo ?? ""
        context.insert(b)
        return b
    }

    /// 로스터 표기("Washed", "약배전")를 목록 표준 이름으로. 목록에 없으면 원문 유지.
    private func canonical(_ raw: String?, in groups: [BeanOptionGroup]) -> String {
        raw.map { BeanOptions.canonicalName($0, in: groups) ?? $0 } ?? ""
    }
}
