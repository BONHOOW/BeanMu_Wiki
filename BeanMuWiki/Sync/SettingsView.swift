import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 설정: Google 동기화 + JSON 백업(내보내기·공유·가져오기). iOS는 시트, macOS는 설정 창(⌘,).
struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.syncEngine) private var engine
    @Environment(\.dismiss) private var dismiss
    @State private var exportDoc: SnapshotDocument?
    @State private var exporting = false
    @State private var importing = false
    @State private var shareURL: URL?
    @State private var message: String?

    /// 파일명용 yyyyMMdd (현지 시간대)
    private var dateStamp: String { Date.now.formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day().dateSeparator(.omitted)) }
    private var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        return "BeanMuWiki \(info["CFBundleShortVersionString"] ?? "") (\(info["CFBundleVersion"] ?? ""))"
    }

    var body: some View {
        #if os(macOS)
        form.formStyle(.grouped).frame(width: 480, height: 600).navigationTitle("설정")
        #else
        NavigationStack {
            form
                .navigationTitle("설정")
                .toolbarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("완료") { dismiss() } } }
        }
        #endif
    }

    private var form: some View {
        Form {
            Section {
                googleRows
            } header: {
                Text("Google 동기화")
            } footer: {
                Text("원두·기록·사진을 이 계정의 Drive 앱 데이터 영역에 저장해 같은 계정으로 로그인한 기기끼리 맞춥니다.")
            }
            Section {
                Button("내보내기…", systemImage: "square.and.arrow.down") { export() }
                    .accessibilityIdentifier("exportBackup")
                if let shareURL {
                    ShareLink(item: shareURL) { Label("AirDrop / 공유", systemImage: "square.and.arrow.up") }
                }
                Button("백업 파일 가져오기…", systemImage: "square.and.arrow.down.on.square") { importing = true }
                    .accessibilityIdentifier("importBackup")
            } header: {
                Text("JSON 백업")
            } footer: {
                VStack(alignment: .leading, spacing: Theme.s12) {
                    Text("원두·기록 전체를 JSON 파일로 저장하거나 불러옵니다. 같은 항목은 더 최근 수정본이 남고, 사진은 포함되지 않습니다.")
                    Text(version)
                }
            }
        }
        .fileExporter(isPresented: $exporting, document: exportDoc, contentType: .json,
                      defaultFilename: "BeanMuWiki-\(dateStamp)") { result in
            if case .failure(let error) = result { message = "내보내기 실패: \(error.localizedDescription)" }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { importFile($0) }
        .alert("설정", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
        } message: { Text(message ?? "") }
        .task { prepareShareURL() }
    }

    @ViewBuilder private var googleRows: some View {
        if let engine { rows(for: engine) } else { Text("동기화 엔진을 사용할 수 없습니다.").foregroundStyle(.secondary) }
    }

    @ViewBuilder private func rows(for engine: SyncEngine) -> some View {
        switch engine.state {
        case .notConfigured:
            Text("Google 클라이언트 ID가 설정되지 않았습니다. GoogleAuth.swift의 GoogleConfig.clientID에 콘솔에서 만든 iOS 클라이언트 ID를 넣으세요.")
                .foregroundStyle(.secondary)
        case .signedOut:
            Button("Google 계정으로 로그인", systemImage: "person.crop.circle") {
                Task { do { try await engine.signIn() } catch AuthError.cancelled {} catch { message = error.localizedDescription } }
            }
            .accessibilityIdentifier("googleSignIn")
        default:
            LabeledContent("계정") {
                Label(engine.auth.email ?? "", systemImage: "person.crop.circle").labelStyle(.titleAndIcon)
            }
            LabeledContent("마지막 동기화", value: engine.lastSyncAt?.relativeKorean ?? "없음")
            LabeledContent("상태") {
                switch engine.state {
                case .syncing: HStack(spacing: 6) { ProgressView().controlSize(.small); Text("동기화 중…") }.foregroundStyle(.secondary)
                case .error(let text): Text(text).foregroundStyle(.red)
                default: Text("동기화됨").foregroundStyle(.secondary)
                }
            }
            Button("지금 동기화", systemImage: "arrow.triangle.2.circlepath") { engine.requestSync() }
                .disabled(engine.state == .syncing)
                .accessibilityIdentifier("syncNow")
            Button("로그아웃", role: .destructive) { Task { await engine.signOut() } }
        }
    }

    private func export() {
        do {
            exportDoc = SnapshotDocument(data: try Snapshot.make(from: context).encoded())
            exporting = true
        } catch { message = "내보내기 실패: \(error.localizedDescription)" }
    }

    /// AirDrop·공유용 임시 파일. 화면을 열 때 한 번 만든다.
    private func prepareShareURL() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("BeanMuWiki-\(dateStamp).json")
        if let data = try? Snapshot.make(from: context).encoded(), (try? data.write(to: url, options: .atomic)) != nil {
            shareURL = url
        }
    }

    private func importFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            guard url.startAccessingSecurityScopedResource() else { throw CocoaError(.fileReadNoPermission) }
            defer { url.stopAccessingSecurityScopedResource() }
            let report = try Snapshot.decode(Data(contentsOf: url)).merge(into: context)
            message = "가져오기 완료: \(report.summary)"
        } catch {
            message = "가져오기 실패: \(error.localizedDescription)"
        }
    }
}

extension Date {
    /// "17분 전" — 앱 문구가 모두 한국어라 시스템 로캘과 무관하게 한국어로 고정
    var relativeKorean: String { formatted(.relative(presentation: .named).locale(Locale(identifier: "ko_KR"))) }
}
