import SwiftUI
import SwiftData

/// iPhone/iPad 원두 탭: 목록 ↔ 문서 2열 (iPhone은 스택). Mac은 MacRootView가 같은 열 뷰를 3열로 조립한다.
struct BeanListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Bean.createdAt, order: .reverse) private var beans: [Bean]
    @State private var selection: Bean?
    @State private var search = ""
    @State private var showingForm = false
    @State private var showingSettings = false
    @State private var importError: String?

    var body: some View {
        NavigationSplitView {
            BeanListColumn(beans: beans, selection: $selection, search: search)
                .navigationTitle("원두")
                .searchable(text: $search, prompt: "원두, 로스터리, 산지")
                .overlay {
                    if beans.isEmpty {
                        ContentUnavailableView("원두를 추가해보세요", systemImage: "cup.and.saucer",
                                               description: Text("오른쪽 위 + 버튼으로 첫 원두를 기록합니다."))
                    }
                }
                .toolbar {
                    Button("설정", systemImage: "gearshape") { showingSettings = true }
                        .accessibilityIdentifier("settingsButton")
                    // ChatGPT가 출력한 📦 BeanMuWiki Import JSON을 클립보드에서 바로 가져온다 (ChatGPT_Prompt.md)
                    Button("가져오기", systemImage: "doc.on.clipboard") {
                        switch ClipboardImport.run(into: context, existing: beans) {
                        case .success(let bean): selection = bean
                        case .failure(let error): importError = error.message
                        }
                    }
                    .keyboardShortcut("v", modifiers: [.command, .shift])
                    Button("추가", systemImage: "plus") { showingForm = true }
                        .keyboardShortcut("n")
                }
                .sheet(isPresented: $showingForm) { BeanFormView() }
                .sheet(isPresented: $showingSettings) { SettingsView() }
                .importErrorAlert($importError)
                .task { context.migrateLegacyIced(); Snapshot.repairIdentity(in: context) }
                #if DEBUG
                .task { context.seedIfNeeded(beansEmpty: beans.isEmpty) }
                #endif
                .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 420)
        } detail: {
            if let selection, !selection.isDeleted {
                NavigationStack { BeanDetailView(bean: selection) }.id(selection)
            } else {
                ContentUnavailableView("원두를 선택하세요", systemImage: "cup.and.saucer")
                    .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.canvas)   // 빈 상세도 크림 캔버스
            }
        }
    }
}

/// 원두 목록 열. `beans`는 이미 사이드바 필터가 적용된 배열, `search`는 이름·로스터리·산지 검색.
/// iOS는 카드 행, macOS는 기본 선택 하이라이트가 있는 평행. 삭제: 컨텍스트 메뉴·⌫(확인 후), iOS 스와이프(즉시).
struct BeanListColumn: View {
    let beans: [Bean]
    @Binding var selection: Bean?
    var search = ""
    @Environment(\.modelContext) private var context
    @State private var pendingDelete: Bean?

    private var filtered: [Bean] {
        guard !search.isEmpty else { return beans }
        return beans.filter { bean in
            [bean.name, bean.roaster, bean.country, bean.region].contains { $0.localizedStandardContains(search) }
        }
    }

    var body: some View {
        List(selection: $selection) {
            ForEach(filtered) { bean in
                NavigationLink(value: bean) { BeanRow(bean: bean) }
                    .contextMenu { Button("삭제", role: .destructive) { pendingDelete = bean } }
                    .cardRow()
            }
            .onDelete { offsets in
                for i in offsets { delete(filtered[i]) }
            }
        }
        .cardList()
        .overlay {
            if !search.isEmpty, filtered.isEmpty { ContentUnavailableView.search(text: search) }
        }
        .deleteCommand { if let selection { pendingDelete = selection } }
        .confirmationDialog("'\(pendingDelete?.name ?? "")' 원두를 삭제할까요?",
                            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible, presenting: pendingDelete) { bean in
            Button("삭제", role: .destructive) { delete(bean) }
        } message: { bean in
            Text("추출 기록 \(bean.brews.count)개도 함께 삭제되며 동기화된 다른 기기에서도 지워집니다.")
        }
    }

    private func delete(_ bean: Bean) {
        if selection == bean { selection = nil }
        context.delete(bean: bean)
    }
}

/// 목록 행: 56pt 사진(없으면 원두색 타일 + 첫 글자) · 제목 · 로스터리/원산지/산지 · 플레이버 도트 · 로스팅 배지
struct BeanRow: View {
    let bean: Bean

    var body: some View {
        HStack(alignment: .top, spacing: Theme.s12) {
            thumbnail
            VStack(alignment: .leading, spacing: Theme.s4) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.s8) {
                    Text(bean.name).font(.headline).foregroundStyle(rowTitle).lineLimit(2)
                    Spacer(minLength: 0)
                    if !bean.roastLevel.isEmpty {
                        HStack(spacing: Theme.s4) {
                            OptionBadge(value: bean.roastLevel, groups: BeanOptions.roastLevels, ownColor: true)
                            Text(bean.roastLevel)
                        }
                        .font(.caption).foregroundStyle(rowMeta).lineLimit(1)
                    }
                }
                let origin = [bean.roaster, bean.countryText, bean.region].filter { !$0.isEmpty }
                if !origin.isEmpty {
                    Text(origin.joined(separator: " · ")).font(.subheadline).foregroundStyle(rowMeta).lineLimit(1)
                }
                if !bean.cupNotes.isEmpty {
                    HStack(spacing: Theme.s8) {
                        FlavorDots(tags: bean.cupNotes)
                        Text(bean.cupNotes.prefix(3).joined(separator: ", ")).font(.caption).foregroundStyle(rowMeta).lineLimit(1)
                    }
                }
            }
        }
    }

    @ViewBuilder private var thumbnail: some View {
        // ponytail: 행마다 JPEG 디코딩. 원두가 100개를 넘으면 썸네일 캐시 고려
        if let image = bean.photo.flatMap(Image.init(data:)) {
            image.resizable().scaledToFill()
                .frame(width: 56, height: 56).clipShape(.rect(cornerRadius: Theme.chip))
        } else {
            RoundedRectangle(cornerRadius: Theme.chip).fill(Color.bean.opacity(0.15))
                .frame(width: 56, height: 56)
                .overlay { Text(String(bean.name.prefix(1))).font(.title3.weight(.semibold)).foregroundStyle(Color.bean) }
        }
    }
}

// macOS는 선택 하이라이트(액센트 배경 + 흰 글자)를 따라가야 하므로 고정 잉크색 대신 primary/secondary를 쓴다.
#if os(macOS)
let rowTitle: Color = .primary
let rowMeta: Color = .secondary
#else
let rowTitle: Color = .ink
let rowMeta: Color = .muted
#endif

extension View {
    /// 목록 행 장식. iOS: 캔버스 위 카드(행 배경이 카드라 셰브런까지 카드 안에 들어간다). macOS: 구분선 없는 평행.
    func cardRow() -> some View {
        #if os(iOS)
        listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: Theme.s16, leading: Theme.s16 + Theme.s12, bottom: Theme.s16, trailing: Theme.s16 + Theme.s12))
            .listRowBackground(
                RoundedRectangle(cornerRadius: Theme.card).fill(Color.card)
                    .overlay(RoundedRectangle(cornerRadius: Theme.card).strokeBorder(Color.hairline))
                    .padding(.horizontal, Theme.s16).padding(.vertical, Theme.s4)
            )
        #else
        listRowSeparator(.hidden).padding(.vertical, 6)
        #endif
    }
    /// 목록 컨테이너. iOS: plain + 크림 캔버스. macOS: 기본.
    func cardList() -> some View {
        #if os(iOS)
        listStyle(.plain).canvasBackground()
        #else
        self
        #endif
    }
    /// 가져오기 실패 알림
    func importErrorAlert(_ message: Binding<String?>) -> some View {
        alert("가져오기 실패", isPresented: Binding(get: { message.wrappedValue != nil }, set: { if !$0 { message.wrappedValue = nil } })) {
        } message: { Text(message.wrappedValue ?? "") }
    }
}

/// 클립보드의 ChatGPT Import JSON → 원두 (실패 시 사용자용 문구)
enum ClipboardImport {
    struct Failure: Error { let message: String }

    static func run(into context: ModelContext, existing: [Bean]) -> Result<Bean, Failure> {
        // 첫 사용 시 iOS의 붙여넣기 허용 알림이 끼어들면 빈 문자열이 올 수 있다 → 한 번 더 읽는다
        var text = pasteboardString ?? ""
        if text.isEmpty { text = pasteboardString ?? "" }
        do {
            return .success(try BeanImport.parse(text).apply(to: context, existing: existing))
        } catch {
            return .failure(Failure(message: "ChatGPT가 출력한 json 블록 전체를 복사했는지 확인하세요.\n\n\(error.localizedDescription)\n\n받은 내용 \(text.count)자: \(text.prefix(80))"))
        }
    }
}

extension ModelContext {
    /// 원두 삭제 + 다른 기기 전파용 Tombstone
    func delete(bean: Bean) {
        insert(Tombstone(uuid: bean.uuid, kind: "bean"))
        delete(bean)
    }
    /// 기록 삭제 + Tombstone
    func delete(brew: Brew) {
        insert(Tombstone(uuid: brew.uuid, kind: "brew"))
        delete(brew)
    }
    /// 0.4.0 이전에 method "V60 ICED"로 저장된 기록을 ICED 서빙으로 옮긴다. 대상이 없으면 아무 일도 안 함.
    func migrateLegacyIced() {
        let legacy = (try? fetch(FetchDescriptor<Brew>(predicate: #Predicate { $0.method.contains("ICED") }))) ?? []
        for brew in legacy {
            brew.isIced = true
            brew.method = brew.method.replacingOccurrences(of: "ICED", with: "").trimmingCharacters(in: .whitespaces)
        }
    }
}

#if DEBUG
extension ModelContext {
    /// `-seed` 런치 인자로 실행하면 시뮬레이터·Mac 검증용 샘플 데이터를 넣고 그 원두를 돌려준다.
    @discardableResult func seedIfNeeded(beansEmpty: Bool) -> Bean? {
        guard CommandLine.arguments.contains("-seed"), beansEmpty else { return nil }
        let bean = Bean(name: "에티오피아 예가체프 G1")
        bean.roaster = "프릳츠"
        bean.country = "에티오피아"
        bean.region = "예가체프 코체레"
        bean.farm = "바나코 워시드 스테이션"
        bean.altitude = "1,900~2,100m"
        bean.variety = "헤어룸"
        bean.process = "워시드"
        bean.roastLevel = "라이트"
        bean.url = "fritz.co.kr"
        bean.cupNotes = ["자스민", "레몬", "홍차", "꿀"]
        insert(bean)

        let fav = Brew()
        fav.method = "V60"; fav.doseGrams = 15; fav.waterGrams = 240; fav.waterTempC = 92
        fav.grind = "코만단테 24클릭"; fav.time = "2:45"; fav.rating = 5; fav.isFavorite = true
        fav.notes = "40g 블룸 40초 후 3회 분할 푸어. 자스민 향, 레몬 산미, 홍차 피니시."
        fav.steps = [PourStep(atSeconds: 0, grams: 45, note: "블룸 · 스푼 3회 스터링"),
                     PourStep(atSeconds: 45, grams: 120, note: "굵은 물줄기 나선형"),
                     PourStep(atSeconds: 75, grams: 200, note: "동전 크기 나선형"),
                     PourStep(atSeconds: 105, grams: 240, note: "센터 푸어")]
        insert(fav); fav.bean = bean

        let iced = Brew()
        iced.isIced = true; iced.doseGrams = 20; iced.waterGrams = 180; iced.iceGrams = 120; iced.waterTempC = 94
        iced.grind = "코만단테 22클릭"; iced.time = "2:15"; iced.rating = 4; iced.isFavorite = true
        iced.steps = [PourStep(atSeconds: 0, grams: 50, note: "블룸"),
                      PourStep(atSeconds: 40, grams: 115, note: ""),
                      PourStep(atSeconds: 80, grams: 180, note: "센터 푸어")]
        insert(iced); iced.bean = bean

        let old = Brew()
        old.date = .now.addingTimeInterval(-86_400 * 2)
        old.method = "에어로프레스"; old.doseGrams = 14; old.waterGrams = 200; old.waterTempC = 88
        old.time = "1:30"; old.rating = 3; old.notes = "단맛은 좋은데 향이 덜 남"
        insert(old); old.bean = bean
        return bean
    }
}
#endif

#Preview {
    BeanListView().modelContainer(for: Bean.self, inMemory: true)
}
