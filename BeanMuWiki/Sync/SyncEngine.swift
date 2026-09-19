import Foundation
import SwiftUI
import Observation
import SwiftData
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Drive appDataFolder의 beanmuwiki.json(스냅샷) + photo-<uuid>.jpg 와 로컬 저장소를 맞춘다.
/// 저장 후 5초 디바운스, 포그라운드 진입, 수동 버튼에서 실행. 한 번에 하나만.
@Observable final class SyncEngine {
    enum State: Equatable { case notConfigured, signedOut, idle, syncing, error(String) }

    private(set) var state: State
    private(set) var lastSyncAt: Date? { didSet { UserDefaults.standard.set(lastSyncAt, forKey: "sync.lastSyncAt") } }
    private var remoteModifiedTime: String? { didSet { UserDefaults.standard.set(remoteModifiedTime, forKey: "sync.remoteModifiedTime") } }
    let auth = GoogleAuth()
    private let context: ModelContext
    private let enabled: Bool
    private let drive: DriveClient
    private var isSyncing = false
    private var observers: [any NSObjectProtocol] = []
    private var debounce: Task<Void, Never>?

    private static let offline: Set<URLError.Code> = [.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost, .dataNotAllowed]

    /// enabled = false(-inMemory UI 테스트)면 네트워크를 전혀 쓰지 않는다
    init(context: ModelContext, enabled: Bool) {
        self.context = context; self.enabled = enabled; drive = DriveClient(auth: auth)
        lastSyncAt = UserDefaults.standard.object(forKey: "sync.lastSyncAt") as? Date
        remoteModifiedTime = UserDefaults.standard.string(forKey: "sync.remoteModifiedTime")
        state = !GoogleConfig.isConfigured ? .notConfigured : auth.isSignedIn ? .idle : .signedOut
    }

    /// 저장 알림 구독(5초 디바운스) + 포그라운드 진입 시 동기화, 그리고 첫 동기화
    func start() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: ModelContext.didSave, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleSync() }
        })
        #if os(macOS)
        let active = NSApplication.didBecomeActiveNotification
        #else
        let active = UIApplication.didBecomeActiveNotification
        #endif
        observers.append(center.addObserver(forName: active, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.requestSync() }
        })
        requestSync()
    }

    private func scheduleSync() {
        guard !isSyncing else { return }   // 동기화 자신의 save는 무시
        debounce?.cancel()
        debounce = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            await self?.syncNow()
        }
    }

    func requestSync() { Task { await syncNow() } }

    func syncNow() async {
        guard enabled, GoogleConfig.isConfigured, auth.isSignedIn, !isSyncing else { return }
        isSyncing = true; state = .syncing
        defer { isSyncing = false }
        do {
            try await sync(retry: true)
            state = .idle
        } catch AuthError.signedOut {
            state = .signedOut
        } catch let error as URLError where Self.offline.contains(error.code) {
            state = .error("오프라인")
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func signIn() async throws {
        try await auth.signIn()
        state = .idle
        requestSync()
    }

    func signOut() async {
        await auth.signOut()
        lastSyncAt = nil; remoteModifiedTime = nil
        state = .signedOut
    }

    /// 목록 → (원격 있으면) 내려받아 병합 → 사진 → (로컬 변경이 있으면) 병합 결과 업로드.
    /// dirty = 마지막 동기화 이후 로컬 변경. 원격만 바뀐 경우는 병합만 하고 올리지 않는다
    private func sync(retry: Bool) async throws {
        let started = Date.now
        let files = try await drive.listAppData()
        let file = files["beanmuwiki.json"]
        let before = try Snapshot.make(from: context)
        let dirty = before.latestChange > (lastSyncAt ?? .distantPast)
        if file?.modifiedTime == remoteModifiedTime, !dirty { return }
        var remote: Snapshot?
        if let file {
            remote = try Snapshot.decode(try await drive.download(file.id))
            _ = try remote!.merge(into: context)
        }
        try await syncPhotos(local: try Snapshot.make(from: context), remote: remote, files: files)
        if dirty || file == nil {
            // 목록 조회 후 다른 기기가 올렸으면 처음부터 한 번 더 (두 번째는 그대로 덮어쓴다)
            if let file, retry, try await drive.modifiedTime(file.id) != file.modifiedTime { return try await sync(retry: false) }
            let data = try Snapshot.make(from: context).encoded()   // 사진 동기화로 바뀐 photoUpdatedAt 반영
            let up = try await drive.upload(name: "beanmuwiki.json", existingID: file?.id, data: data, mimeType: "application/json")
            remoteModifiedTime = up.modifiedTime
        } else {
            remoteModifiedTime = file?.modifiedTime
        }
        lastSyncAt = started
    }

    /// 사진은 photoUpdatedAt LWW. 원격이 더 새로운데 파일이 아직 없으면 건너뛰고 다음에
    // ponytail: 고아 photo-*.jpg는 Drive에 남김
    private func syncPhotos(local: Snapshot, remote: Snapshot?, files: [String: DriveFile]) async throws {
        var changed = false
        for lb in local.beans {
            let rb = remote?.beans.first { $0.uuid == lb.uuid }
            let lt = lb.photoUpdatedAt ?? .distantPast, rt = rb?.photoUpdatedAt ?? .distantPast
            let name = "photo-\(lb.uuid.uuidString).jpg"
            guard lt != rt else { continue }
            let uuid = lb.uuid
            guard let bean = try context.fetch(FetchDescriptor<Bean>(predicate: #Predicate { $0.uuid == uuid })).first else { continue }
            if lt > rt {
                guard lb.hasPhoto, let data = bean.photo else { continue }   // 삭제는 스냅샷의 hasPhoto=false로 전달
                _ = try await drive.upload(name: name, existingID: files[name]?.id, data: data, mimeType: "image/jpeg")
            } else if let rb {
                if rb.hasPhoto {
                    guard let file = files[name] else { continue }
                    bean.photo = try await drive.download(file.id)
                } else {
                    bean.photo = nil
                }
                bean.photoUpdatedAt = rt; changed = true
            }
        }
        if changed { try context.save() }
    }
}

// macOS 26: WindowGroup 콘텐츠 클로저가 App 프로퍼티(엔진)를 참조하면 창이 생성되지 않는다.
// 그래서 씬 수정자 `.environment(\.syncEngine, engine)`로 값 기반 주입만 한다.
extension EnvironmentValues {
    @Entry var syncEngine: SyncEngine? = nil
}
