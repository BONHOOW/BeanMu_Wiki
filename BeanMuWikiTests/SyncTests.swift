import Testing
import Foundation
import SwiftData
@testable import BeanMuWiki

/// 스냅샷 직렬화와 LWW 병합. 날짜는 초 단위 정수로 만들어 인코딩 반올림 영향을 없앤다
@MainActor
struct SyncTests {
    let t0 = Date(timeIntervalSince1970: Date.now.timeIntervalSince1970.rounded() - 3600)   // 90일 tombstone TTL 안쪽

    private func snapshot(beans: [Snapshot.BeanDTO] = [], tombstones: [Snapshot.TombstoneDTO] = []) -> Snapshot {
        Snapshot(device: "test", beans: beans, tombstones: tombstones)
    }

    @Test func snapshotRoundTrip() throws {
        let a = try makeContainer(); let ctxA = a.mainContext
        let bean = Bean(name: "Kenya AA"); bean.roaster = "Fritz"; bean.cupNotes = ["자몽", "흑설탕"]; bean.memo = "m"
        bean.photo = Data([1, 2, 3]); bean.photoUpdatedAt = t0; ctxA.insert(bean)
        let hot = Brew(); hot.date = t0.addingTimeInterval(-100); hot.doseGrams = 15; hot.waterGrams = 240; hot.waterTempC = 93
        hot.steps = [PourStep(atSeconds: 0, grams: 45, note: "블룸"), PourStep(atSeconds: 165, grams: 240, note: "")]
        ctxA.insert(hot); hot.bean = bean
        let iced = Brew(); iced.date = t0; iced.isIced = true; iced.iceGrams = 100; iced.rating = 5; ctxA.insert(iced); iced.bean = bean
        bean.setFavorite(iced)
        let stone = Tombstone(uuid: UUID(), kind: "brew"); ctxA.insert(stone)

        let snap = try Snapshot.decode(try Snapshot.make(from: ctxA).encoded())
        #expect(snap.schemaVersion == 1 && snap.device == "iPhone" && snap.tombstones.count == 1)
        let dto = try #require(snap.beans.first)
        #expect(snap.beans.count == 1 && dto.hasPhoto && dto.brews.map(\.uuid) == [hot.uuid, iced.uuid])   // date 순
        #expect(abs(snap.latestChange.timeIntervalSince(stone.deletedAt)) < 0.001)

        let b = try makeContainer(); let ctxB = b.mainContext
        let report = try snap.merge(into: ctxB)
        #expect(report.beansAdded == 1 && report.brewsAdded == 2 && report.beansUpdated == 0 && report.brewsUpdated == 0)
        let copy = try #require(try ctxB.fetch(FetchDescriptor<Bean>()).first)
        #expect(copy.uuid == bean.uuid && copy.createdAt ~= bean.createdAt && copy.updatedAt ~= bean.updatedAt)
        #expect(copy.name == "Kenya AA" && copy.roaster == "Fritz" && copy.cupNotes == ["자몽", "흑설탕"] && copy.memo == "m")
        #expect(copy.photo == nil && copy.photoUpdatedAt == nil)   // 사진은 엔진이 따로
        let copyHot = try #require(copy.brews.first { $0.uuid == hot.uuid })
        #expect(copyHot.bean === copy && copyHot.steps == hot.steps && copyHot.ratioText == "1:16" && copyHot.waterTempC == 93 && copyHot.date == hot.date)
        let copyIced = try #require(copy.brews.first { $0.uuid == iced.uuid })
        #expect(copyIced.isIced && copyIced.iceGrams == 100 && copyIced.rating == 5 && copyIced.isFavorite && copy.favoriteBrew(iced: true) === copyIced)
        #expect(try ctxB.fetch(FetchDescriptor<Tombstone>()).map(\.uuid) == [stone.uuid])
        #expect(try snap.merge(into: ctxB).summary == "변경 없음")   // 같은 스냅샷 재병합
    }

    @Test func mergeNewerRemoteWins() throws {
        let container = try makeContainer(); let ctx = container.mainContext
        let bean = Bean(name: "old"); bean.updatedAt = t0; ctx.insert(bean)
        var dto = Snapshot.BeanDTO(bean); dto.name = "new"; dto.updatedAt = t0.addingTimeInterval(60)
        let report = try snapshot(beans: [dto]).merge(into: ctx)
        #expect(bean.name == "new" && bean.updatedAt == dto.updatedAt && report.beansUpdated == 1 && report.beansAdded == 0)
    }

    @Test func mergeOlderRemoteIgnored() throws {
        let container = try makeContainer(); let ctx = container.mainContext
        let bean = Bean(name: "local"); bean.updatedAt = t0; ctx.insert(bean)
        var dto = Snapshot.BeanDTO(bean); dto.name = "remote"; dto.updatedAt = t0.addingTimeInterval(-60)
        #expect(try snapshot(beans: [dto]).merge(into: ctx).summary == "변경 없음")
        dto.updatedAt = t0   // 동률도 로컬 유지
        #expect(try snapshot(beans: [dto]).merge(into: ctx).summary == "변경 없음")
        #expect(bean.name == "local" && bean.updatedAt == t0)
    }

    @Test func tombstoneDeletesWhenNewer() throws {
        let container = try makeContainer(); let ctx = container.mainContext
        let bean = Bean(name: "X"); bean.updatedAt = t0; ctx.insert(bean)
        let brew = Brew(); ctx.insert(brew); brew.bean = bean
        let keep = Bean(name: "K"); keep.updatedAt = t0; ctx.insert(keep)
        let keepBrew = Brew(); keepBrew.updatedAt = t0; ctx.insert(keepBrew); keepBrew.bean = keep
        let report = try snapshot(tombstones: [.init(uuid: bean.uuid, kind: "bean", deletedAt: t0.addingTimeInterval(60)),
                                               .init(uuid: keepBrew.uuid, kind: "brew", deletedAt: t0.addingTimeInterval(60))]).merge(into: ctx)
        #expect(report.beansDeleted == 1 && report.brewsDeleted == 1)
        #expect(try ctx.fetch(FetchDescriptor<Bean>()).map(\.uuid) == [keep.uuid])
        #expect(try ctx.fetchCount(FetchDescriptor<Brew>()) == 0)   // X의 기록은 cascade, K의 기록은 tombstone
        #expect(try ctx.fetchCount(FetchDescriptor<Tombstone>()) == 2)
    }

    @Test func tombstoneLosesToLaterEdit() throws {
        let container = try makeContainer(); let ctx = container.mainContext
        let bean = Bean(name: "X"); bean.updatedAt = t0.addingTimeInterval(60); ctx.insert(bean)
        let report = try snapshot(tombstones: [.init(uuid: bean.uuid, kind: "bean", deletedAt: t0)]).merge(into: ctx)
        #expect(report.beansDeleted == 0)
        #expect(try ctx.fetchCount(FetchDescriptor<Bean>()) == 1)
        #expect(try ctx.fetchCount(FetchDescriptor<Tombstone>()) == 1)   // tombstone은 보관
    }

    @Test func tombstoneBlocksReinsert() throws {
        let container = try makeContainer(); let ctx = container.mainContext
        let bean = Bean(name: "X"); bean.updatedAt = t0
        let dto = Snapshot.BeanDTO(bean)
        let report = try snapshot(beans: [dto], tombstones: [.init(uuid: dto.uuid, kind: "bean", deletedAt: t0.addingTimeInterval(60))]).merge(into: ctx)
        #expect(report.beansAdded == 0)
        #expect(try ctx.fetchCount(FetchDescriptor<Bean>()) == 0)
    }

    @Test func tombstonesDroppedAfter90Days() throws {
        let container = try makeContainer(); let ctx = container.mainContext
        let old = Tombstone(uuid: UUID(), kind: "bean"); old.deletedAt = .now.addingTimeInterval(-91 * 86400); ctx.insert(old)
        let fresh = Tombstone(uuid: UUID(), kind: "bean"); ctx.insert(fresh)
        #expect(try Snapshot.make(from: ctx).tombstones.map(\.uuid) == [fresh.uuid])
        _ = try snapshot().merge(into: ctx)
        #expect(try ctx.fetch(FetchDescriptor<Tombstone>()).map(\.uuid) == [fresh.uuid])
    }

    @Test func brewReparenting() throws {
        let container = try makeContainer(); let ctx = container.mainContext
        let x = Bean(name: "X"); let y = Bean(name: "Y"); ctx.insert(x); ctx.insert(y)
        let brew = Brew(); ctx.insert(brew); brew.bean = x
        var yDTO = Snapshot.BeanDTO(y); yDTO.brews = [Snapshot.BrewDTO(brew)]
        let report = try snapshot(beans: [yDTO]).merge(into: ctx)
        #expect(brew.bean?.uuid == y.uuid && x.brews.isEmpty && y.brews.count == 1)
        #expect(report.summary == "변경 없음")
        #expect(try ctx.fetchCount(FetchDescriptor<Brew>()) == 1)
    }

    @Test func repairIdentityDedupes() throws {
        let container = try makeContainer(); let ctx = container.mainContext
        let shared = UUID()
        let beans = (0..<3).map { i in
            let b = Bean(name: "\(i)"); b.uuid = shared; b.createdAt = t0.addingTimeInterval(Double(i)); ctx.insert(b); return b
        }
        beans[0].photo = Data([1])   // 구버전 사진: photoUpdatedAt 없음
        let brews = (0..<2).map { _ in let b = Brew(); b.uuid = shared; ctx.insert(b); b.bean = beans[1]; return b }
        Snapshot.repairIdentity(in: ctx, force: true)
        #expect(beans[0].uuid == shared && Set(beans.map(\.uuid)).count == 3)   // 첫 항목 유지
        #expect(Set(brews.map(\.uuid)).count == 2)
        #expect(beans[0].photoUpdatedAt == t0 && beans[1].photoUpdatedAt == nil)
    }

    @Test func decodeRejectsFutureSchema() throws {
        var snap = snapshot(); snap.schemaVersion = 2
        let data = try snap.encoded()
        #expect(throws: SnapshotError.self) { try Snapshot.decode(data) }
        #expect(try Snapshot.decode(try snapshot().encoded()).device == "test")
    }

    @Test func mergeReportSummary() {
        var report = MergeReport()
        #expect(report.summary == "변경 없음")
        report.beansAdded = 3; report.beansUpdated = 2; report.brewsAdded = 5
        #expect(report.summary == "원두 3개 추가, 2개 갱신 · 기록 5개 추가")
        report = MergeReport(); report.brewsDeleted = 1
        #expect(report.summary == "기록 1개 삭제")
    }
}

/// 스냅샷 인코딩 정밀도(밀리초) 안에서 같은 시각
private func ~= (a: Date, b: Date) -> Bool { abs(a.timeIntervalSince(b)) < 0.001 }

/// 인메모리 컨테이너. 반환값을 테스트가 끝날 때까지 변수로 잡아 두어야 한다 — 컨테이너가 해제되면 mainContext 사용 시 SIGTRAP.
@MainActor
private func makeContainer() throws -> ModelContainer {
    try ModelContainer(for: Bean.self, Tombstone.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
}
