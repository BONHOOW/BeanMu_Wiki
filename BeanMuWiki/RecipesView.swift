import SwiftUI
import SwiftData

/// 레시피 탭: 원두별 기준 레시피(★, 없으면 최근 기록) 카드 → 추출 카드
struct RecipesView: View {
    @Query(sort: \Bean.createdAt, order: .reverse) private var beans: [Bean]

    var body: some View {
        NavigationStack {
            List {
                ForEach(beans) { bean in
                    if let brew = bean.favoriteBrew {
                        NavigationLink { BrewCardView(brew: brew) } label: { RecipeCard(bean: bean, brew: brew) }
                            .listRowSeparator(.hidden)
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
