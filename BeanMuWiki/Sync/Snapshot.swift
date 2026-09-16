import Foundation
import SwiftData
import SwiftUI            // FileDocument
import UniformTypeIdentifiers

/// 전체 데이터의 JSON 스냅샷. 기기 간 동기화 = 스냅샷을 교환하고 LWW(updatedAt이 늦은 쪽)로 병합
struct Snapshot: Codable {
    var schemaVersion = 1
    var exportedAt = Date.now
    var device: String
    var beans: [BeanDTO]
    var tombstones: [TombstoneDTO]

    struct BeanDTO: Codable, Equatable {
        var uuid: UUID; var createdAt: Date; var updatedAt: Date
        var name, roaster, country, region, farm, altitude, variety, process, roastLevel, url, memo: String
        var cupNotes: [String]
        var hasPhoto: Bool; var photoUpdatedAt: Date?
        var brews: [BrewDTO]

        init(_ bean: Bean, includeBrews: Bool = true) {
            uuid = bean.uuid; createdAt = bean.createdAt; updatedAt = bean.updatedAt
            name = bean.name; roaster = bean.roaster; country = bean.country; region = bean.region; farm = bean.farm
            altitude = bean.altitude; variety = bean.variety; process = bean.process; roastLevel = bean.roastLevel
            url = bean.url; memo = bean.memo; cupNotes = bean.cupNotes
            hasPhoto = bean.photo != nil; photoUpdatedAt = bean.photoUpdatedAt
            brews = includeBrews ? bean.brews.sorted { $0.date < $1.date }.map { BrewDTO($0) } : []
        }

        /// 모든 필드 적용. uuid·createdAt·updatedAt·photo·photoUpdatedAt·brews 제외
        func apply(to bean: Bean) {
            bean.name = name; bean.roaster = roaster; bean.country = country; bean.region = region; bean.farm = farm
            bean.altitude = altitude; bean.variety = variety; bean.process = process; bean.roastLevel = roastLevel
            bean.url = url; bean.memo = memo; bean.cupNotes = cupNotes
        }
    }

    struct BrewDTO: Codable, Equatable {
        var uuid: UUID; var updatedAt: Date; var date: Date
        var method: String; var isIced: Bool
        var doseGrams, waterGrams, iceGrams: Double?; var waterTempC: Int?
        var grind, time, notes: String; var rating: Int; var isFavorite: Bool
        var steps: [PourStep]

        init(_ brew: Brew) {
            uuid = brew.uuid; updatedAt = brew.updatedAt; date = brew.date
            method = brew.method; isIced = brew.isIced
            doseGrams = brew.doseGrams; waterGrams = brew.waterGrams; iceGrams = brew.iceGrams; waterTempC = brew.waterTempC
            grind = brew.grind; time = brew.time; notes = brew.notes; rating = brew.rating; isFavorite = brew.isFavorite
            steps = brew.steps
        }

        /// uuid·updatedAt 제외
        func apply(to brew: Brew) {
            brew.date = date; brew.method = method; brew.isIced = isIced
            brew.doseGrams = doseGrams; brew.waterGrams = waterGrams; brew.iceGrams = iceGrams; brew.waterTempC = waterTempC
            brew.grind = grind; brew.time = time; brew.notes = notes; brew.rating = rating; brew.isFavorite = isFavorite
            brew.steps = steps
        }
    }

    struct TombstoneDTO: Codable { var uuid: UUID; var kind: String; var deletedAt: Date }

    static let tombstoneTTL: TimeInterval = 90 * 86400

    static var deviceName: String {
        #if os(macOS)
        "Mac"
        #else
        "iPhone"
        #endif
    }

    /// 로컬에서 가장 최근 변경 시각 (updatedAt · photoUpdatedAt · deletedAt 중 최대). "동기화 후 바뀐 게 있나" 판단용
    var latestChange: Date {
        let dates = beans.flatMap { [$0.updatedAt, $0.photoUpdatedAt ?? .distantPast] + $0.brews.map(\.updatedAt) } + tombstones.map(\.deletedAt)
        return dates.max() ?? .distantPast
    }

    /// beans는 createdAt 순, brews는 date 순. 90일 지난 tombstone 제외
    static func make(from context: ModelContext, device: String = Snapshot.deviceName) throws -> Snapshot {
        let beans = try context.fetch(FetchDescriptor<Bean>(sortBy: [SortDescriptor(\.createdAt)]))
        let cutoff = Date.now.addingTimeInterval(-tombstoneTTL)
        let stones = try context.fetch(FetchDescriptor<Tombstone>(sortBy: [SortDescriptor(\.deletedAt)])).filter { $0.deletedAt >= cutoff }
        return Snapshot(device: device, beans: beans.map { BeanDTO($0) },
                        tombstones: stones.map { TombstoneDTO(uuid: $0.uuid, kind: $0.kind, deletedAt: $0.deletedAt) })
    }

    // 날짜는 밀리초까지 남긴다 — 기본 .iso8601은 초 단위로 잘려 LWW 비교가 흐려진다. 읽을 때는 소수점 없는 값도 허용
    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var c = encoder.singleValueContainer()
            try c.encode(date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
        }
        return try encoder.encode(self)
    }

    /// schemaVersion이 더 크면 SnapshotError.newerSchema
    static func decode(_ data: Data) throws -> Snapshot {
        struct Header: Decodable { var schemaVersion: Int }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer(); let text = try c.decode(String.self)
            guard let date = (try? Date(text, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
                    ?? (try? Date(text, strategy: Date.ISO8601FormatStyle())) else {
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "날짜 형식이 아닙니다: \(text)")
            }
            return date
        }
        if try decoder.decode(Header.self, from: data).schemaVersion > 1 { throw SnapshotError.newerSchema }
        return try decoder.decode(Snapshot.self, from: data)
    }

    /// LWW 병합. tombstone → 삭제 → 원두/기록 upsert → 오래된 tombstone 정리 → save
    func merge(into context: ModelContext) throws -> MergeReport {
        var report = MergeReport()
        var beans = Dictionary(try context.fetch(FetchDescriptor<Bean>()).map { ($0.uuid, $0) }, uniquingKeysWith: { a, _ in a })
        var brews = Dictionary(try context.fetch(FetchDescriptor<Brew>()).map { ($0.uuid, $0) }, uniquingKeysWith: { a, _ in a })
        var stones = Dictionary(try context.fetch(FetchDescriptor<Tombstone>()).map { ($0.uuid, $0) }, uniquingKeysWith: { a, _ in a })

        for t in tombstones {
            if let local = stones[t.uuid] { local.deletedAt = max(local.deletedAt, t.deletedAt) }
            else { let s = Tombstone(uuid: t.uuid, kind: t.kind); s.deletedAt = t.deletedAt; context.insert(s); stones[t.uuid] = s }
        }
        for s in stones.values {
            if s.kind == "bean", let bean = beans[s.uuid], s.deletedAt > bean.updatedAt {
                for brew in bean.brews { brews[brew.uuid] = nil }   // cascade
                context.delete(bean); beans[s.uuid] = nil; report.beansDeleted += 1
            } else if s.kind == "brew", let brew = brews[s.uuid], s.deletedAt > brew.updatedAt {
                context.delete(brew); brews[s.uuid] = nil; report.brewsDeleted += 1
            }
        }
        for dto in self.beans {
            if let s = stones[dto.uuid], s.deletedAt > dto.updatedAt { continue }
            let bean: Bean
            if let local = beans[dto.uuid] {
                bean = local
                if dto.updatedAt > local.updatedAt { dto.apply(to: local); local.updatedAt = dto.updatedAt; report.beansUpdated += 1 }
            } else {
                bean = Bean(); bean.uuid = dto.uuid; bean.createdAt = dto.createdAt; bean.updatedAt = dto.updatedAt
                dto.apply(to: bean); context.insert(bean); beans[dto.uuid] = bean; report.beansAdded += 1
            }
            for b in dto.brews {
                if let s = stones[b.uuid], s.deletedAt > b.updatedAt { continue }
                if let local = brews[b.uuid] {
                    if b.updatedAt > local.updatedAt { b.apply(to: local); local.updatedAt = b.updatedAt; report.brewsUpdated += 1 }
                    if local.bean?.uuid != bean.uuid { local.bean = bean }
                } else {
                    let brew = Brew(); brew.uuid = b.uuid; brew.updatedAt = b.updatedAt; b.apply(to: brew)
                    context.insert(brew); brew.bean = bean; brews[b.uuid] = brew; report.brewsAdded += 1
                }
            }
        }
        let cutoff = Date.now.addingTimeInterval(-Self.tombstoneTTL)
        for s in stones.values where s.deletedAt < cutoff { context.delete(s) }
        try context.save()
        return report
    }

    /// 경량 마이그레이션은 기존 행 전부에 같은 기본 UUID를 준다 → 중복 uuid를 새로 발급(첫 항목 유지).
    /// 사진이 있는데 photoUpdatedAt이 없으면 createdAt으로. 한 번만 실행 (force로 무시)
    static func repairIdentity(in context: ModelContext, force: Bool = false) {
        let key = "sync.identityRepaired"
        guard force || !UserDefaults.standard.bool(forKey: key),
              let beans = try? context.fetch(FetchDescriptor<Bean>(sortBy: [SortDescriptor(\.createdAt)])),
              let brews = try? context.fetch(FetchDescriptor<Brew>(sortBy: [SortDescriptor(\.date)])) else { return }
        var seen = Set<UUID>()
        for bean in beans {
            if !seen.insert(bean.uuid).inserted { bean.uuid = UUID() }
            if bean.photoUpdatedAt == nil, bean.photo != nil { bean.photoUpdatedAt = bean.createdAt }
        }
        seen.removeAll()
        for brew in brews where !seen.insert(brew.uuid).inserted { brew.uuid = UUID() }
        if (try? context.save()) != nil { UserDefaults.standard.set(true, forKey: key) }
    }
}

nonisolated enum SnapshotError: LocalizedError {
    case newerSchema
    var errorDescription: String? { "새 버전의 앱에서 만든 파일입니다" }
}

struct MergeReport {
    var beansAdded = 0, beansUpdated = 0, beansDeleted = 0, brewsAdded = 0, brewsUpdated = 0, brewsDeleted = 0

    /// "원두 3개 추가, 2개 갱신 · 기록 5개 추가". 0인 항목 생략, 전부 0이면 "변경 없음"
    var summary: String {
        func part(_ label: String, _ counts: [(Int, String)]) -> String? {
            let items = counts.filter { $0.0 > 0 }.map { "\($0.0)개 \($0.1)" }
            return items.isEmpty ? nil : label + " " + items.joined(separator: ", ")
        }
        let parts = [part("원두", [(beansAdded, "추가"), (beansUpdated, "갱신"), (beansDeleted, "삭제")]),
                     part("기록", [(brewsAdded, "추가"), (brewsUpdated, "갱신"), (brewsDeleted, "삭제")])].compactMap { $0 }
        return parts.isEmpty ? "변경 없음" : parts.joined(separator: " · ")
    }
}

/// fileExporter/fileImporter용 래퍼. FileDocument는 Sendable이라 기본 MainActor 격리에서 빼야 한다
nonisolated struct SnapshotDocument: FileDocument {
    static let readableContentTypes = [UTType.json]
    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        data = contents
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
