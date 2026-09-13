import SwiftUI
import SwiftData

/// 레시피 탭: 원두 × 서빙(HOT/ICED)별 기준 레시피(★, 없으면 그 서빙의 최근 기록) 카드 → 추출 카드
struct RecipesView: View {
    @Query(sort: \Bean.createdAt, order: .reverse) private var beans: [Bean]
    @State private var filter: Bool?   // nil = 전체, false = HOT, true = ICED

    private var servings: [Bool] { filter.map { [$0] } ?? [false, true] }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("서빙 필터", selection: $filter) {
                        Text("전체").tag(Bool?.none)
                        Text("HOT").tag(Bool?.some(false))
                        Text("ICED").tag(Bool?.some(true))
                    }
                    .pickerStyle(.segmented).labelsHidden()
                    .accessibilityIdentifier("recipeFilter")
                    .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                }
                Section {
                    ForEach(beans) { bean in
                        ForEach(servings, id: \.self) { iced in
                            if let brew = bean.favoriteBrew(iced: iced) {
                                NavigationLink { BrewCardView(brew: brew) } label: { RecipeCard(bean: bean, brew: brew) }
                                    .listRowSeparator(.hidden)
                            }
                        }
                    }
                }
            }
            .navigationTitle("레시피")
            .overlay {
                if beans.allSatisfy(\.brews.isEmpty) {
                    ContentUnavailableView("기준 레시피가 없어요", systemImage: "star",
                                           description: Text("원두의 추출 기록에서 ★ 기준 레시피를 지정하면 여기에 모입니다."))
                }
            }
        }
    }
}

private struct RecipeCard: View {
    let bean: Bean
    let brew: Brew

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(bean.name).font(.headline)
                ServingChip(brew: brew)
                Spacer()
                Text(bean.countryText).font(.subheadline).foregroundStyle(.secondary)
            }
            Text(brew.conditionLine).font(.system(.subheadline, design: .rounded)).monospacedDigit()
            let summary = [brew.method, brew.stepsSummary ?? (brew.time.isEmpty ? nil : brew.time)].compactMap { $0 }
            Text(summary.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            if !bean.cupNotes.isEmpty { FlavorDots(tags: bean.cupNotes) }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    RecipesView().modelContainer(for: Bean.self, inMemory: true)
}
