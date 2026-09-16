import SwiftUI
import SwiftData

struct BeanDetailView: View {
    let bean: Bean
    @Environment(\.modelContext) private var context
    @State private var editing = false
    @State private var addingBrew = false
    @State private var editingBrew: Brew?

    private var brews: [Brew] { bean.brews.sorted { $0.date > $1.date } }
    private func deleteBrew(_ brew: Brew) {
        context.insert(Tombstone(uuid: brew.uuid, kind: "brew"))
        context.delete(brew)
    }

    private var hasOrigin: Bool {
        [bean.roaster, bean.country, bean.region, bean.farm, bean.altitude, bean.variety, bean.process, bean.roastLevel]
            .contains { !$0.isEmpty } || bean.pageURL != nil
    }

    var body: some View {
        List {
            if let image = bean.photo.flatMap(Image.init(data:)) {
                Section {
                    image.resizable().scaledToFit()
                        .frame(maxWidth: .infinity)
                        .listRowInsets(EdgeInsets())
                }
            }
            if hasOrigin {
                Section("원산지") {
                    info("로스터리", bean.roaster)
                    info("원산지", bean.country, in: BeanOptions.countries)
                    info("산지 / 재배지", bean.region)
                    info("농장", bean.farm)
                    info("고도", bean.altitude)
                    info("품종", bean.variety, in: BeanOptions.varieties)
                    info("가공", bean.process, in: BeanOptions.processes)
                    info("로스팅", bean.roastLevel, in: BeanOptions.roastLevels, ownColor: true)
                    if let url = bean.pageURL {
                        Link(destination: url) { Label("판매 페이지 열기", systemImage: "safari") }
                    }
                }
            }
            if !bean.cupNotes.isEmpty {
                Section("컵노트") { FlavorChips(tags: bean.cupNotes) }
            }
            if !bean.memo.isEmpty {
                Section("메모") { Text(bean.memo) }
            }
            Section("추출 기록") {
                // 서빙(HOT/ICED)별 추출 카드 열기
                ForEach([false, true], id: \.self) { iced in
                    if let fav = bean.favoriteBrew(iced: iced) {
                        NavigationLink { BrewCardView(brew: fav) } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(fav.isFavorite ? "★ \(fav.servingLabel) 기준 레시피" : "\(fav.servingLabel) 최근 기록")
                                    Text(fav.conditionLine)
                                        .font(.caption).foregroundStyle(.secondary).monospacedDigit().lineLimit(1)
                                }
                            } icon: {
                                Image(systemName: "timer")
                            }
                        }
                        .accessibilityIdentifier(iced ? "openBrewCardIced" : "openBrewCard")
                    }
                }
                Button("기록 추가", systemImage: "plus") { addingBrew = true }
                ForEach(brews) { brew in
                    Button { editingBrew = brew } label: { BrewRow(brew: brew) }
                        .contextMenu { Button("삭제", role: .destructive) { deleteBrew(brew) } }
                }
                .onDelete { offsets in
                    for i in offsets { deleteBrew(brews[i]) }
                }
            }
        }
        .navigationTitle(bean.name)
        .toolbar {
            Button("편집") { editing = true }
        }
        .sheet(isPresented: $editing) { BeanFormView(bean: bean) }
        .sheet(isPresented: $addingBrew) { BrewFormView(bean: bean) }
        .sheet(item: $editingBrew) { BrewFormView(brew: $0) }
    }

    /// groups를 주면 국기 또는 색 점 배지를 값 앞에 붙인다 (OptionBadge).
    @ViewBuilder
    private func info(_ label: String, _ value: String, in groups: [BeanOptionGroup] = [], ownColor: Bool = false) -> some View {
        if !value.isEmpty {
            LabeledContent(label) {
                HStack(spacing: 6) {
                    OptionBadge(value: value, groups: groups, ownColor: ownColor)
                    Text(value)
                }
            }
        }
    }
}

private struct BrewRow: View {
    let brew: Brew

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(brew.method).font(.headline)
                if brew.isIced { ServingChip(brew: brew) }
                if brew.isFavorite {
                    Image(systemName: "star.fill").font(.caption).foregroundStyle(.yellow)
                }
                Spacer()
                Text(brew.stars).foregroundStyle(.orange)
            }
            let parts: [String?] = [
                brew.date.formatted(date: .abbreviated, time: .omitted),
                brew.ratioText,
                brew.time.isEmpty ? nil : brew.time,
            ]
            Text(parts.compactMap { $0 }.joined(separator: " · "))
                .font(.subheadline).foregroundStyle(.secondary)
            if let summary = brew.stepsSummary {
                Text(summary).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            if !brew.notes.isEmpty {
                Text(brew.notes).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .foregroundStyle(Color.primary)
    }
}
