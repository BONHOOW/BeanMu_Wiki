import SwiftUI
import SwiftData

struct BeanListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Bean.createdAt, order: .reverse) private var beans: [Bean]
    @State private var path: [Bean] = []
    @State private var search = ""
    @State private var showingForm = false
    @State private var importError = ""
    @State private var showingImportError = false

    private var filtered: [Bean] {
        guard !search.isEmpty else { return beans }
        return beans.filter { bean in
            [bean.name, bean.roaster, bean.country, bean.region].contains { $0.localizedStandardContains(search) }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(filtered) { bean in
                    NavigationLink(value: bean) { BeanRow(bean: bean) }
                }
                .onDelete { offsets in
                    for i in offsets { context.delete(filtered[i]) }
                }
            }
            .navigationTitle("원두")
            .navigationDestination(for: Bean.self) { BeanDetailView(bean: $0) }
            .searchable(text: $search, prompt: "원두, 로스터리, 산지")
            .overlay {
                if beans.isEmpty {
                    ContentUnavailableView("원두를 추가해보세요", systemImage: "cup.and.saucer",
                                           description: Text("오른쪽 위 + 버튼으로 첫 원두를 기록합니다."))
                }
            }
            .toolbar {
                // ChatGPT가 출력한 📦 BeanMuWiki Import JSON을 클립보드에서 바로 가져온다 (ChatGPT_Prompt.md)
                Button("가져오기", systemImage: "doc.on.clipboard") { importJSON(UIPasteboard.general.string ?? "") }
                Button("추가", systemImage: "plus") { showingForm = true }
            }
            .sheet(isPresented: $showingForm) { BeanFormView() }
            .alert("가져오기 실패", isPresented: $showingImportError) {} message: { Text(importError) }
            .task { migrateLegacyIced() }
            #if DEBUG
            .task { seedIfNeeded() }
            #endif
        }
    }

    private func importJSON(_ pasted: String) {
        // 첫 사용 시 iOS의 붙여넣기 허용 알림이 끼어들면 빈 문자열이 올 수 있다 → 클립보드를 한 번 더 읽어 보완
        let text = pasted.isEmpty ? (UIPasteboard.general.string ?? "") : pasted
        do {
            path = [try BeanImport.parse(text).apply(to: context, existing: beans)]
        } catch {
            importError = "ChatGPT가 출력한 json 블록 전체를 복사했는지 확인하세요.\n\n\(error.localizedDescription)\n\n받은 내용 \(text.count)자: \(text.prefix(80))"
            showingImportError = true
        }
    }
}

private struct BeanRow: View {
    let bean: Bean

    var body: some View {
        HStack(spacing: 12) {
            // ponytail: 행마다 JPEG 디코딩. 원두가 100개를 넘으면 썸네일 캐시 고려
            if let image = bean.photo.flatMap(UIImage.init(data:)) {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(width: 48, height: 48).clipShape(.rect(cornerRadius: 8))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(bean.name).font(.headline)
                let flag = BeanOptions.option(named: bean.country, in: BeanOptions.countries)?.emoji ?? ""
                let origin = [bean.roaster, flag.isEmpty ? bean.country : "\(flag) \(bean.country)", bean.region].filter { !$0.isEmpty }
                if !origin.isEmpty {
                    Text(origin.joined(separator: " · ")).font(.subheadline).foregroundStyle(.secondary)
                }
                if !bean.cupNotes.isEmpty {
                    HStack(spacing: 8) {
                        FlavorDots(tags: bean.cupNotes)
                        Text(bean.cupNotes.prefix(3).joined(separator: ", ")).font(.caption).foregroundStyle(.tertiary).lineLimit(1)
                    }
                }
            }
        }
    }
}

private extension BeanListView {
    /// 0.4.0 이전에 method "V60 ICED"로 저장된 기록을 ICED 서빙으로 옮긴다. 대상이 없으면 아무 일도 안 함.
    func migrateLegacyIced() {
        let legacy = (try? context.fetch(FetchDescriptor<Brew>(predicate: #Predicate { $0.method.contains("ICED") }))) ?? []
        for brew in legacy {
            brew.isIced = true
            brew.method = brew.method.replacingOccurrences(of: "ICED", with: "").trimmingCharacters(in: .whitespaces)
        }
    }
}

#if DEBUG
private extension BeanListView {
    /// `-seed` 런치 인자로 실행하면 시뮬레이터 검증용 샘플 데이터를 넣는다.
    func seedIfNeeded() {
        guard CommandLine.arguments.contains("-seed"), beans.isEmpty else { return }
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
        context.insert(bean)

        let fav = Brew()
        fav.method = "V60"; fav.doseGrams = 15; fav.waterGrams = 240; fav.waterTempC = 92
        fav.grind = "코만단테 24클릭"; fav.time = "2:45"; fav.rating = 5; fav.isFavorite = true
        fav.notes = "40g 블룸 40초 후 3회 분할 푸어. 자스민 향, 레몬 산미, 홍차 피니시."
        fav.steps = [PourStep(atSeconds: 0, grams: 45, note: "블룸 · 스푼 3회 스터링"),
                     PourStep(atSeconds: 45, grams: 120, note: "굵은 물줄기 나선형"),
                     PourStep(atSeconds: 75, grams: 200, note: "동전 크기 나선형"),
                     PourStep(atSeconds: 105, grams: 240, note: "센터 푸어")]
        context.insert(fav); fav.bean = bean

        let iced = Brew()
        iced.isIced = true; iced.doseGrams = 20; iced.waterGrams = 180; iced.iceGrams = 120; iced.waterTempC = 94
        iced.grind = "코만단테 22클릭"; iced.time = "2:15"; iced.rating = 4; iced.isFavorite = true
        iced.steps = [PourStep(atSeconds: 0, grams: 50, note: "블룸"),
                      PourStep(atSeconds: 40, grams: 115, note: ""),
                      PourStep(atSeconds: 80, grams: 180, note: "센터 푸어")]
        context.insert(iced); iced.bean = bean

        let old = Brew()
        old.date = .now.addingTimeInterval(-86_400 * 2)
        old.method = "에어로프레스"; old.doseGrams = 14; old.waterGrams = 200; old.waterTempC = 88
        old.time = "1:30"; old.rating = 3; old.notes = "단맛은 좋은데 향이 덜 남"
        context.insert(old); old.bean = bean
    }
}
#endif

#Preview {
    BeanListView().modelContainer(for: Bean.self, inMemory: true)
}
