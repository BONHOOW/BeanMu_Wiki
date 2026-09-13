import UIKit
import SwiftData

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
    @Relationship(deleteRule: .cascade, inverse: \Brew.bean) var brews: [Brew] = []

    init(name: String = "") { self.name = name }

    /// 기준 레시피(★), 없으면 가장 최근 기록
    var favoriteBrew: Brew? {
        brews.first { $0.isFavorite } ?? brews.max { $0.date < $1.date }
    }

    /// "fritz.co.kr/..."처럼 스킴이 없어도 열 수 있게 https를 붙인다.
    var pageURL: URL? {
        let s = url.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }
        return URL(string: s.contains("://") ? s : "https://" + s)
    }

    /// 사진을 긴 변 maxPixel 이하의 JPEG로 줄인다. 이미지가 아니면 nil.
    static func compressedPhoto(_ data: Data, maxPixel: CGFloat = 1200) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let scale = min(1, maxPixel / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return image.preparingThumbnail(of: size)?.jpegData(compressionQuality: 0.8)
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

/// 레시피 + 테이스팅 기록. isFavorite = 이 원두의 기준 레시피
@Model
final class Brew {
    var date = Date.now
    var method = brewMethods[0]
    var doseGrams: Double?
    var waterGrams: Double?   // 총량. steps가 있으면 마지막 단계의 grams와 같다
    var waterTempC: Int?
    var grind = ""
    var time = ""         // 총 추출 시간 "2:45" 자유 텍스트
    var steps: [PourStep] = []
    var rating = 3        // 0 = 아직 안 마셔봄
    var notes = ""
    var isFavorite = false
    var bean: Bean?

    init(template: Brew? = nil) {
        guard let template else { return }
        method = template.method
        doseGrams = template.doseGrams
        waterGrams = template.waterGrams
        waterTempC = template.waterTempC
        grind = template.grind
        time = template.time
        steps = template.steps
    }

    var ratioText: String? {
        guard let doseGrams, let waterGrams, doseGrams > 0 else { return nil }
        return "1:" + (waterGrams / doseGrams).formatted(.number.precision(.fractionLength(0...1)))
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
        var doseGrams, waterGrams, waterTempC: Double?
        var rating: Int?
        var isFavorite: Bool?
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
            brew.method = dto.method ?? brewMethods[0]
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
            brew.isFavorite = dto.isFavorite ?? false
            if brew.isFavorite { target.brews.forEach { $0.isFavorite = false } }
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
