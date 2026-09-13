import SwiftUI

/// 빈카이브식 선택 시트. 검색 · 카테고리 탭 · "직접 추가". selection은 선택 순서를 유지하고 목록에 없는 값도 허용한다.
/// 단일 선택(singleSelection)은 길이 0~1 배열 Binding으로 감싸고, 탭하면 바로 닫힌다.
struct OptionPickerSheet: View {
    let title: String
    let groups: [BeanOptionGroup]
    @Binding var selection: [String]
    var singleSelection = false
    var prompt = "검색 또는 직접 입력"
    var searchIdentifier = "optionSearch"
    /// 직접 입력을 목록 표준 이름으로 (nil = BeanOptions.canonicalName). 플레이버 피커는 FlavorWheel.canonicalName.
    var canonicalize: (@MainActor (String) -> String?)?
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var group: String?   // nil = 전체

    private var query: String { search.trimmingCharacters(in: .whitespaces) }
    private var options: [BeanOption] {
        let base = groups.first { $0.name == group }?.options ?? groups.flatMap(\.options)
        guard !query.isEmpty else { return base }
        return base.filter { $0.name.localizedStandardContains(query) || $0.english.localizedStandardContains(query) }
    }
    private var customs: [String] { selection.filter { BeanOptions.option(named: $0, in: groups) == nil } }
    private var canonical: String { canonicalize.flatMap { $0(query) } ?? BeanOptions.canonicalName(query, in: groups) ?? query }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField(prompt, text: $search)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier(searchIdentifier)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(.fill.tertiary, in: .capsule)
                .padding(.horizontal)

                ScrollView(.horizontal) {
                    HStack(spacing: 20) {
                        tab(nil, title: "전체")
                        ForEach(groups) { tab($0.name, title: $0.name) }
                    }
                    .padding(.horizontal)
                }
                .scrollIndicators(.hidden)

                List {
                    ForEach(options) { row($0) }
                    if !query.isEmpty, !options.contains(where: { $0.name == query }) {
                        Button(canonical == query ? "\"\(query)\" 직접 추가" : "\"\(query)\" → \(canonical) 추가", systemImage: "plus") {
                            if singleSelection || !selection.contains(canonical) { select(canonical) }
                            search = ""
                        }
                    }
                    if group == nil, query.isEmpty, !customs.isEmpty {
                        Section("직접 추가") {
                            ForEach(customs, id: \.self) { row(BeanOption(name: $0, english: "", emoji: "", hex: "")) }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle(title)
            .navigationSubtitle(singleSelection || selection.isEmpty ? "" : "\(selection.count)개 선택")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("완료") { dismiss() } }
            }
        }
    }

    private func tab(_ name: String?, title: String) -> some View {
        Button(title) { group = name }
            .buttonStyle(.plain)
            .fontWeight(group == name ? .bold : .regular)
            .foregroundStyle(group == name ? .primary : .secondary)
            .padding(.vertical, 10)
            .overlay(alignment: .bottom) { if group == name { Rectangle().frame(height: 2) } }
    }

    private func row(_ option: BeanOption) -> some View {
        Button { select(option.name) } label: {
            HStack(spacing: 12) {
                if option.emoji.isEmpty {
                    Circle().fill(option.color).frame(width: 24, height: 24)
                } else {
                    Text(option.emoji).font(.title2).frame(width: 24)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.name)
                    // english에는 검색용 별칭이 " · "로 이어져 있어 첫 표기만 보여 준다
                    if let first = option.english.split(separator: " · ").first, !first.isEmpty {
                        Text(first).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if selection.contains(option.name) {
                    Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(Color.accentColor)
                }
            }
        }
        .tint(.primary)
        .accessibilityLabel(option.name)
    }

    private func select(_ name: String) {
        if singleSelection { selection = [name]; dismiss(); return }
        if let i = selection.firstIndex(of: name) { selection.remove(at: i) } else { selection.append(name) }
    }
}

/// 플레이버 다중 선택 (SCA 플레이버 휠).
struct FlavorPickerSheet: View {
    @Binding var selection: [String]

    var body: some View {
        OptionPickerSheet(title: "플레이버", groups: BeanOptions.flavors, selection: $selection,
                          prompt: "향과 맛을 검색해보세요", searchIdentifier: "flavorSearch", canonicalize: { FlavorWheel.canonicalName($0) })
    }
}

extension BeanOptions {
    /// FlavorWheel → 피커 그룹 (색 점 배지, 국기 없음)
    static let flavors: [BeanOptionGroup] = FlavorWheel.categories.map { c in
        BeanOptionGroup(name: c.name, hex: c.hex, options: c.flavors.map {
            BeanOption(name: $0.name, english: $0.english, emoji: "", hex: $0.hex)
        })
    }
}

/// 폼 행: 현재 값(배지 + 이름) 또는 "선택" → 탭하면 단일 선택 시트. 빈 문자열 = 미선택.
/// 접근성 식별자: "\(id)PickerButton", 시트 검색창 "\(id)Search".
struct OptionPickerRow: View {
    let title: String
    @Binding var value: String
    let groups: [BeanOptionGroup]
    let id: String
    var ownColor = false
    @State private var picking = false

    var body: some View {
        Button { picking = true } label: {
            LabeledContent(title) {
                if value.isEmpty {
                    Text("선택")
                } else {
                    HStack(spacing: 6) {
                        OptionBadge(value: value, groups: groups, ownColor: ownColor)
                        Text(value).foregroundStyle(.primary)
                    }
                }
            }
        }
        .tint(.primary)
        .accessibilityIdentifier("\(id)PickerButton")
        .accessibilityLabel(title)
        .accessibilityValue(value.isEmpty ? "선택" : value)
        .sheet(isPresented: $picking) {
            OptionPickerSheet(title: title, groups: groups,
                              selection: Binding(get: { value.isEmpty ? [] : [value] }, set: { value = $0.last ?? "" }),
                              singleSelection: true, searchIdentifier: "\(id)Search")
        }
    }
}

/// 표시용 배지: 국기 이모지가 있으면 이모지, 없으면 색 점. ownColor = 옵션 고유색(로스팅 원두색), 아니면 그룹색.
/// 목록에 없는 값(직접 입력)은 아무것도 그리지 않는다.
struct OptionBadge: View {
    let value: String
    let groups: [BeanOptionGroup]
    var ownColor = false

    var body: some View {
        if let group = groups.first(where: { $0.options.contains { $0.name == value } }),
           let option = group.options.first(where: { $0.name == value }) {
            if option.emoji.isEmpty {
                Circle().fill(ownColor ? option.color : group.color).frame(width: 10, height: 10)
            } else {
                Text(option.emoji)
            }
        }
    }
}

/// 상세 화면용 읽기 전용 칩. 색 점 + 이름, 여러 줄로 줄바꿈.
struct FlavorChips: View {
    let tags: [String]

    var body: some View {
        FlowLayout {
            ForEach(tags, id: \.self) { tag in
                HStack(spacing: 6) {
                    Circle().fill(FlavorWheel.color(for: tag)).frame(width: 10, height: 10)
                    Text(tag)
                }
                .font(.subheadline)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(.fill.tertiary, in: .capsule)
            }
        }
    }
}

/// 목록 행용 색 점 묶음 (최대 8개).
struct FlavorDots: View {
    let tags: [String]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tags.prefix(8), id: \.self) { Circle().fill(FlavorWheel.color(for: $0)).frame(width: 10, height: 10) }
        }
    }
}

/// 가로로 채우다 넘치면 다음 줄로 넘기는 최소 레이아웃.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (view, point) in zip(subviews, arrange(width: bounds.width, subviews).points) {
            view.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func arrange(width: CGFloat, _ subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        var points: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return (CGSize(width: maxX, height: y + rowHeight), points)
    }
}

#Preview("Picker") {
    @Previewable @State var selection = ["레몬", "자스민", "패션후르츠"]
    FlavorPickerSheet(selection: $selection)
}

#Preview("Country") {
    @Previewable @State var country = ["에티오피아"]
    OptionPickerSheet(title: "원산지", groups: BeanOptions.countries, selection: $country, singleSelection: true)
}
