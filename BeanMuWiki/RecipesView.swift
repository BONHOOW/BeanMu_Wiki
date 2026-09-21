import SwiftUI
import SwiftData

/// iPhone/iPad 레시피 탭: 원두 × 서빙(HOT/ICED)별 기준 레시피(★, 없으면 그 서빙의 최근 기록) 카드 → 추출 카드
struct RecipesView: View {
    @Query(sort: \Bean.createdAt, order: .reverse) private var beans: [Bean]
    @State private var filter: Bool?   // nil = 전체, false = HOT, true = ICED
    @State private var selection: Brew?

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                Picker("서빙 필터", selection: $filter) {
                    Text("전체").tag(Bool?.none)
                    Text("HOT").tag(Bool?.some(false))
                    Text("ICED").tag(Bool?.some(true))
                }
                .pickerStyle(.segmented).labelsHidden()
                .accessibilityIdentifier("recipeFilter")
                .padding(.horizontal, Theme.s16).padding(.vertical, Theme.s8)
                .background(Color.canvas)
                RecipeListColumn(beans: beans, filter: filter, selection: $selection)
            }
            .navigationTitle("레시피")
            .navigationSplitViewColumnWidth(min: 300, ideal: 360, max: 480)
            .overlay {
                if beans.allSatisfy(\.brews.isEmpty) {
                    ContentUnavailableView("기준 레시피가 없어요", systemImage: "star",
                                           description: Text("원두의 추출 기록에서 ★ 기준 레시피를 지정하면 여기에 모입니다."))
                }
            }
        } detail: {
            if let selection, !selection.isDeleted {
                BrewCardView(brew: selection).id(selection)
            } else {
                ContentUnavailableView("레시피를 선택하세요", systemImage: "timer")
                    .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.canvas)   // 빈 상세도 크림 캔버스
            }
        }
    }
}

/// 레시피 카드 목록 열. filter nil = 전체, false = HOT, true = ICED. 삭제(컨텍스트 메뉴·⌫)는 그 기록을 지운다.
struct RecipeListColumn: View {
    let beans: [Bean]
    var filter: Bool?
    @Binding var selection: Brew?
    @Environment(\.modelContext) private var context
    @State private var pendingDelete: Brew?

    private var servings: [Bool] { filter.map { [$0] } ?? [false, true] }
    /// (원두, 기록) 쌍 — 원두 순서 유지
    var recipes: [(bean: Bean, brew: Brew)] {
        beans.flatMap { bean in servings.compactMap { iced in bean.favoriteBrew(iced: iced).map { (bean, $0) } } }
    }

    var body: some View {
        List(selection: $selection) {
            ForEach(recipes, id: \.brew.uuid) { bean, brew in
                NavigationLink(value: brew) { RecipeCard(bean: bean, brew: brew) }
                    .contextMenu { Button("기록 삭제", role: .destructive) { pendingDelete = brew } }
                    .cardRow()
            }
        }
        .cardList()
        .deleteCommand { if let selection { pendingDelete = selection } }
        .confirmationDialog("'\(pendingDelete?.bean?.name ?? "")' \(pendingDelete?.servingLabel ?? "") 기록을 삭제할까요?",
                            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible, presenting: pendingDelete) { brew in
            Button("삭제", role: .destructive) {
                if selection == brew { selection = nil }
                context.delete(brew: brew)
            }
        } message: { _ in
            Text("이 추출 기록이 지워지고 동기화된 다른 기기에서도 사라집니다. 원두는 남습니다.")
        }
    }
}

/// 레시피 카드: 원두명 + 서빙 칩 + ★ · 조건 한 줄(숫자) · 방식/단계 요약 · 플레이버 도트
private struct RecipeCard: View {
    let bean: Bean
    let brew: Brew

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.s8) {
                Text(bean.name).font(.headline).foregroundStyle(rowTitle).lineLimit(1)
                Spacer(minLength: 0)
                if brew.isFavorite { Image(systemName: "star.fill").font(.caption).foregroundStyle(Color.cherry) }
                ServingChip(brew: brew)
            }
            Text(brew.conditionLine).font(.subheadline).fontDesign(.rounded).monospacedDigit().foregroundStyle(rowTitle)
            let summary = [bean.countryText.isEmpty ? nil : bean.countryText, brew.method,
                           brew.stepsSummary ?? (brew.time.isEmpty ? nil : brew.time)].compactMap { $0 }
            Text(summary.joined(separator: " · ")).font(.caption).foregroundStyle(rowMeta).lineLimit(1)
            if !bean.cupNotes.isEmpty { FlavorDots(tags: bean.cupNotes) }
        }
    }
}

#Preview {
    RecipesView().modelContainer(for: Bean.self, inMemory: true)
}
