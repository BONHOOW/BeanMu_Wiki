#if os(macOS)
import SwiftUI
import SwiftData
import AppKit

/// Mac 루트: 사이드바(색인) · 목록 · 문서 3열. 사이드바가 필터, 가운데가 결과, 오른쪽이 선택한 원두 문서/추출 카드.
struct MacRootView: View {
    enum SidebarItem: Hashable { case beans, recipes(Bool?), roaster(String), country(String) }

    @Environment(\.modelContext) private var context
    @Environment(\.openSettings) private var openSettings
    @Query(sort: \Bean.createdAt, order: .reverse) private var beans: [Bean]
    @State private var item: SidebarItem? = .beans
    @State private var bean: Bean?
    @State private var brew: Brew?
    @State private var search = ""
    @State private var columns = NavigationSplitViewVisibility.all
    @State private var showingForm = false
    @State private var importError: String?

    private var current: SidebarItem { item ?? .beans }
    private var isRecipes: Bool { if case .recipes = current { true } else { false } }
    private var filteredBeans: [Bean] {
        switch current {
        case .roaster(let name): beans.filter { $0.roaster == name }
        case .country(let name): beans.filter { $0.country == name }
        default: beans
        }
    }
    private var title: String {
        switch current {
        case .beans: "전체 원두"
        case .recipes(nil): "레시피"
        case .recipes(let iced?): iced ? "ICED 레시피" : "HOT 레시피"
        case .roaster(let name): name
        case .country(let name): flagged(name)
        }
    }
    /// 이름별 원두 수, 많은 순 → 이름 순
    private func counts(_ key: (Bean) -> String) -> [(name: String, count: Int)] {
        Dictionary(grouping: beans.filter { !key($0).isEmpty }, by: key)
            .map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
    }
    private func flagged(_ country: String) -> String {
        let flag = BeanOptions.option(named: country, in: BeanOptions.countries)?.emoji ?? ""
        return flag.isEmpty ? country : "\(flag) \(country)"
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            sidebar
        } content: {
            content
        } detail: {
            detail
        }
        .sheet(isPresented: $showingForm) { BeanFormView() }
        .importErrorAlert($importError)
        .onChange(of: item) {
            // 필터를 바꿨을 때 선택된 원두가 결과에 없으면 문서를 비운다
            if let bean, !filteredBeans.contains(bean) { self.bean = nil }
        }
        .task {
            context.migrateLegacyIced(); Snapshot.repairIdentity(in: context)
            #if DEBUG
            if let seeded = context.seedIfNeeded(beansEmpty: beans.isEmpty) { bean = seeded }
            await debugHooks()
            #endif
        }
    }

    // MARK: 열

    private var sidebar: some View {
        List(selection: $item) {
            Section("라이브러리") {
                Label("전체 원두", systemImage: "cup.and.saucer").badge(beans.count).tag(SidebarItem.beans)
                Label("레시피", systemImage: "timer").badge(recipeCount(nil)).tag(SidebarItem.recipes(nil))
            }
            Section("서빙") {
                Label("HOT", systemImage: "flame").badge(recipeCount(false)).tag(SidebarItem.recipes(false))
                Label("ICED", systemImage: "snowflake").badge(recipeCount(true)).tag(SidebarItem.recipes(true))
            }
            let roasters = counts(\.roaster)
            if !roasters.isEmpty {
                Section("로스터리") {
                    ForEach(roasters, id: \.name) { Label($0.name, systemImage: "storefront").badge($0.count).tag(SidebarItem.roaster($0.name)) }
                }
            }
            let countries = counts(\.country)
            if !countries.isEmpty {
                Section("원산지") {
                    ForEach(countries, id: \.name) { Text(flagged($0.name)).badge($0.count).tag(SidebarItem.country($0.name)) }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 280)
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: Theme.s8) {
                SyncStatusView()
                SettingsLink { Label("설정", systemImage: "gearshape") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }
            .font(.caption)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.s12)
        }
    }

    private func recipeCount(_ iced: Bool?) -> Int {
        let servings: [Bool] = iced.map { [$0] } ?? [false, true]
        return beans.reduce(0) { total, bean in total + servings.filter { bean.favoriteBrew(iced: $0) != nil }.count }
    }

    @ViewBuilder private var content: some View {
        if case .recipes(let iced) = current {
            RecipeListColumn(beans: beans, filter: iced, selection: $brew)
                .navigationTitle(title)
                .navigationSubtitle("\(recipeCount(iced))개 레시피")
                .overlay {
                    if recipeCount(iced) == 0 {
                        ContentUnavailableView("기준 레시피가 없어요", systemImage: "star",
                                               description: Text("원두 문서의 추출 기록에서 ★ 기준 레시피를 지정하면 여기에 모입니다."))
                    }
                }
                .navigationSplitViewColumnWidth(min: 300, ideal: 360, max: 480)
        } else {
            BeanListColumn(beans: filteredBeans, selection: $bean, search: search)
                .searchable(text: $search, prompt: "원두, 로스터리, 산지")
                .navigationTitle(title)
                .navigationSubtitle("\(filteredBeans.count)개 원두")
                .overlay {
                    if beans.isEmpty {
                        ContentUnavailableView("원두를 추가해보세요", systemImage: "cup.and.saucer",
                                               description: Text("⌘N 또는 툴바 + 로 첫 원두를 기록합니다."))
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button("가져오기", systemImage: "doc.on.clipboard") { importClipboard() }
                            .keyboardShortcut("v", modifiers: [.command, .shift])
                            .help("클립보드의 ChatGPT JSON 가져오기 (⇧⌘V)")
                        Button("추가", systemImage: "plus") { showingForm = true }
                            .keyboardShortcut("n")
                            .help("새 원두 (⌘N)")
                    }
                }
                .navigationSplitViewColumnWidth(min: 300, ideal: 360, max: 480)
        }
    }

    private var detail: some View {
        Group {
            if isRecipes {
                if let brew, !brew.isDeleted {
                    BrewCardView(brew: brew).id(brew)
                } else {
                    ContentUnavailableView("레시피를 선택하세요", systemImage: "timer")
                    .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.canvas)   // 빈 상세도 크림 캔버스
                }
            } else if let bean, !bean.isDeleted {
                NavigationStack { BeanDetailView(bean: bean) }.id(bean)
            } else {
                ContentUnavailableView("원두를 선택하세요", systemImage: "cup.and.saucer")
                    .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.canvas)   // 빈 상세도 크림 캔버스
            }
        }
        // 상세 열에 항목이 하나는 있어야 가운데 열의 +/가져오기가 그 열 위에 고정된다 (없으면 macOS가 오른쪽으로 합쳐 버림)
        .toolbar { ToolbarItem(placement: .automatic) { SyncStatusView(compact: true) } }
    }

    private func importClipboard() {
        switch ClipboardImport.run(into: context, existing: beans) {
        case .success(let imported): item = .beans; bean = imported
        case .failure(let error): importError = error.message
        }
    }

    #if DEBUG
    /// 접근성 권한 없이 스크린샷 검증용: -debugWindow 1000x640 · -debugSidebar recipes · -debugSettings
    private func debugHooks() async {
        let args = CommandLine.arguments
        try? await Task.sleep(for: .milliseconds(600))
        if let i = args.firstIndex(of: "-debugWindow"), i + 1 < args.count {
            let parts = args[i + 1].split(separator: "x").compactMap { Double($0) }
            if parts.count == 2, let window = NSApp.windows.first(where: { $0.isVisible }) {
                window.setContentSize(NSSize(width: parts[0], height: parts[1]))
            }
        }
        if let i = args.firstIndex(of: "-debugSidebar"), i + 1 < args.count, args[i + 1] == "recipes" {
            item = .recipes(nil)
            brew = beans.first?.favoriteBrew(iced: false)
        }
        if args.contains("-debugSettings") { openSettings() }
    }
    #endif
}

/// 동기화 상태. compact = 툴바 아이콘(툴팁에 상세), 아니면 사이드바 푸터 한 줄. 클릭하면 지금 동기화. notConfigured면 숨김.
struct SyncStatusView: View {
    @Environment(\.syncEngine) private var engine
    var compact = false

    var body: some View {
        if let engine, engine.state != .notConfigured {
            if compact {
                Button { engine.requestSync() } label: {
                    if engine.state == .syncing { ProgressView().controlSize(.small) } else { Label(text(engine), systemImage: icon(engine)) }
                }
                .labelStyle(.iconOnly)
                .help("\(text(engine)) — 클릭하면 지금 동기화")
                .disabled(engine.state == .syncing || engine.state == .signedOut)
            } else {
                Button { engine.requestSync() } label: {
                    HStack(spacing: 6) {
                        if engine.state == .syncing { ProgressView().controlSize(.small) } else { Image(systemName: icon(engine)) }
                        Text(text(engine)).lineLimit(1)
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("클릭하면 지금 동기화")
                .disabled(engine.state == .syncing || engine.state == .signedOut)
            }
        }
    }

    private func icon(_ engine: SyncEngine) -> String {
        if case .error = engine.state { "exclamationmark.triangle" } else { "arrow.triangle.2.circlepath" }
    }

    private func text(_ engine: SyncEngine) -> String {
        switch engine.state {
        case .syncing: "동기화 중…"
        case .idle: engine.lastSyncAt.map { "동기화됨 · " + $0.relativeKorean } ?? "아직 동기화 안 됨"
        case .signedOut: "로그인 필요"
        case .error(let message): compact ? "동기화 오류: " + message : message
        case .notConfigured: ""
        }
    }
}
#endif
