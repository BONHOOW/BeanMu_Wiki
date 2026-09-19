import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 설정 시트: Google 동기화 + JSON 백업(내보내기·공유·가져오기)
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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    googleRows
                } header: {
                    Text("Google 동기화")
                } footer: {
                    Text("원두·기록·사진이 이 Google 계정의 Drive 앱 데이터 영역(사용자에게 보이지 않는 공간)에 저장되고, 다른 기기에서 같은 계정으로 로그인하면 자동으로 맞춰집니다.")
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
                    Text("원두·기록 전체를 JSON 파일로 저장하거나 불러옵니다. 가져오기는 같은 항목이면 더 최근에 수정된 쪽을 남깁니다. 사진은 백업 파일에 포함되지 않습니다.")
                }
            }
            .navigationTitle("설정")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("완료") { dismiss() } }
            }
            .fileExporter(isPresented: $exporting, document: exportDoc, contentType: .json,
                          defaultFilename: "BeanMuWiki-\(dateStamp)") { result in
                if case .failure(let error) = result { message = "내보내기 실패: \(error.localizedDescription)" }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { importFile($0) }
            .alert("설정", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            } message: { Text(message ?? "") }
            .task { prepareShareURL() }
            .formSheet()
        }
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
            LabeledContent("계정", value: engine.auth.email ?? "")
            LabeledContent("마지막 동기화", value: engine.lastSyncAt?.formatted(.relative(presentation: .named)) ?? "없음")
            if engine.state == .syncing {
                HStack { ProgressView(); Text("동기화 중…").foregroundStyle(.secondary) }
            } else if case .error(let text) = engine.state {
                Text(text).foregroundStyle(.red)
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

    /// AirDrop·공유용 임시 파일. 시트를 열 때 한 번 만든다.
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
