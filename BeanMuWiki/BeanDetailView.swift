import SwiftUI
import SwiftData

/// 원두 문서: 헤더(사진·이름·메타·로스팅·컵노트) → 원산지 인포박스 → 메모 → 추출 기록. iPhone·Mac 같은 레이아웃.
struct BeanDetailView: View {
    let bean: Bean
    @Environment(\.modelContext) private var context
    @State private var editing = false
    @State private var addingBrew = false
    @State private var editingBrew: Brew?
    #if os(macOS)
    @State private var tableSelection: Set<Brew.ID> = []
    #endif

    private var brews: [Brew] { bean.brews.sorted { $0.date > $1.date } }
    private func deleteBrew(_ brew: Brew) {
        context.insert(Tombstone(uuid: brew.uuid, kind: "brew"))
        context.delete(brew)
    }

    /// 인포박스 행. groups가 있으면 국기/색 점 배지, rounded는 숫자 데이터(고도)
    private struct InfoRow: Identifiable {
        let label: String, value: String
        var groups: [BeanOptionGroup] = [], ownColor = false, rounded = false
        var id: String { label }
    }
    private var infoRows: [InfoRow] {
        [InfoRow(label: "로스터리", value: bean.roaster),
         InfoRow(label: "원산지", value: bean.country, groups: BeanOptions.countries),
         InfoRow(label: "산지 / 재배지", value: bean.region),
         InfoRow(label: "농장", value: bean.farm),
         InfoRow(label: "고도", value: bean.altitude, rounded: true),
         InfoRow(label: "품종", value: bean.variety, groups: BeanOptions.varieties),
         InfoRow(label: "가공", value: bean.process, groups: BeanOptions.processes),
         InfoRow(label: "로스팅", value: bean.roastLevel, groups: BeanOptions.roastLevels, ownColor: true)]
            .filter { !$0.value.isEmpty }
    }

    #if os(macOS)
    private let pad = Theme.s24
    #else
    private let pad = Theme.s16
    #endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.s24) {
                header
                if !infoRows.isEmpty || bean.pageURL != nil { infobox }
                if !bean.memo.isEmpty {
                    card("메모") {
                        Text(bean.memo).lineSpacing(4).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(Theme.s16)
                    }
                }
                brewsCard
            }
            .padding(pad)
            #if os(macOS)
            .frame(maxWidth: 760)
            #endif
            .frame(maxWidth: .infinity)
        }
        .background(Color.canvas)
        .foregroundStyle(Color.ink)
        .navigationTitle(bean.name)
        .toolbarTitleDisplayMode(.inline)   // 본문에 큰 제목이 있으므로 바에는 작게
        .toolbar {
            Button("편집") { editing = true }
        }
        .sheet(isPresented: $editing) { BeanFormView(bean: bean) }
        .sheet(isPresented: $addingBrew) { BrewFormView(bean: bean) }
        .sheet(item: $editingBrew) { BrewFormView(brew: $0) }
        #if DEBUG
        .task {
            try? await Task.sleep(for: .seconds(1))   // 창이 key가 되기 전에는 시트가 뜨지 않는다
            switch debugSheet {
            case "bean", "flavor": editing = true
            case "brew": addingBrew = true
            default: break
            }
        }
        #endif
    }

    // MARK: 헤더

    private var header: some View {
        let image = bean.photo.flatMap(Image.init(data:))
        let text = VStack(alignment: .leading, spacing: Theme.s8) {
            Text(bean.name).font(.title.bold())
            let meta = [bean.roaster, bean.countryText, bean.region].filter { !$0.isEmpty }
            if !meta.isEmpty { Text(meta.joined(separator: " · ")).font(.subheadline).foregroundStyle(Color.muted) }
            if !bean.roastLevel.isEmpty {
                HStack(spacing: 6) {
                    OptionBadge(value: bean.roastLevel, groups: BeanOptions.roastLevels, ownColor: true)
                    Text(bean.roastLevel).font(.caption.weight(.semibold))
                }
                .padding(.horizontal, Theme.s8).padding(.vertical, 3)
                .background(Color.cardTint, in: .capsule)
            }
            if !bean.cupNotes.isEmpty { FlavorChips(tags: bean.cupNotes) }
        }
        #if os(macOS)
        return HStack(alignment: .top, spacing: Theme.s16) {
            if let image {
                image.resizable().scaledToFill()
                    .frame(width: 160, height: 160).clipShape(.rect(cornerRadius: Theme.hero))
            }
            text
        }
        #else
        return VStack(alignment: .leading, spacing: Theme.s16) {
            if let image {
                Color.clear.aspectRatio(4 / 3, contentMode: .fit).frame(maxHeight: 240)
                    .overlay { image.resizable().scaledToFill() }
                    .clipShape(.rect(cornerRadius: Theme.hero))
            }
            text
        }
        #endif
    }

    // MARK: 카드

    /// cardTint 헤더 바 + 본문
    private func card<Content: View>(_ title: String, @ViewBuilder trailing: () -> some View = { EmptyView() },
                                     @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(Color.muted)
                Spacer()
                trailing()
            }
            .padding(.horizontal, Theme.s12).padding(.vertical, Theme.s8)
            .frame(minHeight: 36)
            .background(Color.cardTint)
            content()
        }
        .clipShape(.rect(cornerRadius: Theme.card))
        .cardStyle(padding: 0)
    }

    private var infobox: some View {
        card("원산지") {
            Grid(alignment: .leading, horizontalSpacing: Theme.s16, verticalSpacing: 0) {
                ForEach(Array(infoRows.enumerated()), id: \.element.id) { i, row in
                    if i > 0 { Divider().overlay(Color.hairline).gridCellColumns(2) }
                    GridRow {
                        Text(row.label).font(.subheadline).foregroundStyle(Color.muted)
                            .frame(minWidth: 88, alignment: .trailing).gridColumnAlignment(.trailing)
                        HStack(spacing: 6) {
                            OptionBadge(value: row.value, groups: row.groups, ownColor: row.ownColor)
                            Text(row.value).fontDesign(row.rounded ? .rounded : .default).monospacedDigit()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 10)
                }
                if let url = bean.pageURL {
                    if !infoRows.isEmpty { Divider().overlay(Color.hairline).gridCellColumns(2) }
                    GridRow {
                        Text("판매 페이지").font(.subheadline).foregroundStyle(Color.muted)
                            .frame(minWidth: 88, alignment: .trailing).gridColumnAlignment(.trailing)
                        Link(destination: url) { Label(url.host() ?? "열기", systemImage: "safari") }
                            .foregroundStyle(Color.brand).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 10)
                }
            }
            .padding(.horizontal, Theme.s12)
        }
    }

    private var brewsCard: some View {
        card("추출 기록 \(brews.count)") {
            Button("기록 추가", systemImage: "plus") { addingBrew = true }
                .controlSize(.small)
                #if os(macOS)
                .buttonStyle(.bordered)
                #else
                .buttonStyle(.borderedProminent).tint(.cta)
                #endif
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                // 서빙(HOT/ICED)별 추출 카드 열기
                ForEach([false, true], id: \.self) { iced in
                    if let fav = bean.favoriteBrew(iced: iced) {
                        NavigationLink { BrewCardView(brew: fav) } label: {
                            HStack(spacing: Theme.s12) {
                                Image(systemName: "timer").foregroundStyle(Color.brand)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        if fav.isFavorite { Image(systemName: "star.fill").font(.caption).foregroundStyle(Color.cherry) }
                                        Text(fav.isFavorite ? "\(fav.servingLabel) 기준 레시피" : "\(fav.servingLabel) 최근 기록").font(.headline)
                                        ServingChip(brew: fav)
                                    }
                                    Text(fav.conditionLine).font(.caption).foregroundStyle(Color.muted)
                                        .fontDesign(.rounded).monospacedDigit().lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.muted)
                            }
                            .padding(.horizontal, Theme.s12).padding(.vertical, 10)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(iced ? "openBrewCardIced" : "openBrewCard")
                        Divider().overlay(Color.hairline)
                    }
                }
                if brews.isEmpty {
                    Text("아직 기록이 없습니다").font(.subheadline).foregroundStyle(Color.muted).padding(Theme.s12)
                } else {
                    history
                }
            }
        }
    }

    #if os(macOS)
    private var history: some View {
        Table(brews, selection: $tableSelection) {
            TableColumn("날짜") { Text($0.date.formatted(date: .abbreviated, time: .omitted)) }.width(min: 90)
            TableColumn("방식") { Text($0.method) }
            TableColumn("서빙") { ServingChip(brew: $0) }.width(52)
            TableColumn("원두 / 물") { brew in
                Text([brew.doseGrams?.gramsText, brew.waterGrams?.gramsText].compactMap { $0 }.joined(separator: " / "))
                    .fontDesign(.rounded).monospacedDigit()
            }
            TableColumn("비율") { Text($0.ratioText ?? "—").fontDesign(.rounded).monospacedDigit() }.width(48)
            TableColumn("시간") { Text($0.time.isEmpty ? "—" : $0.time).fontDesign(.rounded).monospacedDigit() }.width(48)
            TableColumn("평점") { Stars(rating: $0.rating) }.width(88)
            TableColumn("★") { brew in
                if brew.isFavorite { Image(systemName: "star.fill").foregroundStyle(Color.cherry) }
            }.width(24)
        }
        .tableStyle(.inset)
        .contextMenu(forSelectionType: Brew.ID.self) { ids in
            Button("편집") { editingBrew = brews.first { ids.contains($0.id) } }
            Button("삭제", role: .destructive) { for brew in brews where ids.contains(brew.id) { deleteBrew(brew) } }
        } primaryAction: { ids in
            editingBrew = brews.first { ids.contains($0.id) }   // 더블클릭
        }
        .frame(height: max(160, CGFloat(brews.count) * 30 + 44))
    }
    #else
    private var history: some View {
        ForEach(brews) { brew in
            Button { editingBrew = brew } label: { BrewRow(brew: brew) }
                .buttonStyle(.plain)
                .contextMenu { Button("삭제", role: .destructive) { deleteBrew(brew) } }
            if brew != brews.last { Divider().overlay(Color.hairline) }
        }
    }
    #endif
}

/// 평점 ★ 5개 (채움 cherry, 빈 별 hairline)
struct Stars: View {
    let rating: Int
    var font: Font = .caption

    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: "star.fill").font(font).foregroundStyle(i <= rating ? Color.cherry : Color.hairline)
            }
        }
        .accessibilityLabel(String(repeating: "★", count: max(0, min(5, rating))) + String(repeating: "☆", count: 5 - max(0, min(5, rating))))   // Brew.stars와 같은 문자열 (UI 테스트가 찾는다)
    }
}

#if os(iOS)
private struct BrewRow: View {
    let brew: Brew

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(brew.method).font(.headline)
                ServingChip(brew: brew)
                if brew.isFavorite { Image(systemName: "star.fill").font(.caption).foregroundStyle(Color.cherry) }
                Spacer()
                Stars(rating: brew.rating)
            }
            let parts: [String?] = [brew.date.formatted(date: .abbreviated, time: .omitted), brew.ratioText, brew.time.isEmpty ? nil : brew.time]
            Text(parts.compactMap { $0 }.joined(separator: " · "))
                .font(.subheadline).foregroundStyle(Color.muted).fontDesign(.rounded).monospacedDigit()
            if let summary = brew.stepsSummary {
                Text(summary).font(.caption).foregroundStyle(Color.muted).lineLimit(1)
            }
            if !brew.notes.isEmpty {
                Text(brew.notes).font(.caption).foregroundStyle(Color.muted).lineLimit(2)
            }
        }
        .padding(.horizontal, Theme.s12).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }
}
#endif

#if DEBUG
/// `-debugSheet bean|brew|flavor` 런치 인자: 클릭 없이 시트를 열어 레이아웃을 검증한다
var debugSheet: String? {
    let args = CommandLine.arguments
    guard let i = args.firstIndex(of: "-debugSheet"), i + 1 < args.count else { return nil }
    return args[i + 1]
}
#endif
