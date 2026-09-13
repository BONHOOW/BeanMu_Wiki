import SwiftUI

/// 빈카이브식 플레이버 선택 시트. selection은 선택한 순서를 유지하고, 휠에 없는 직접 입력 노트도 허용한다.
struct FlavorPickerSheet: View {
    @Binding var selection: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var category: String?   // nil = 전체

    private var query: String { search.trimmingCharacters(in: .whitespaces) }
    private var flavors: [Flavor] {
        let base = FlavorWheel.categories.first { $0.name == category }?.flavors ?? FlavorWheel.all
        guard !query.isEmpty else { return base }
        return base.filter { $0.name.localizedStandardContains(query) || $0.english.localizedStandardContains(query) }
    }
    private var customs: [String] { selection.filter { FlavorWheel.flavor(named: $0) == nil } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("향과 맛을 검색해보세요", text: $search)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("flavorSearch")
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(.fill.tertiary, in: .capsule)
                .padding(.horizontal)

                ScrollView(.horizontal) {
                    HStack(spacing: 20) {
                        tab(nil, title: "전체")
                        ForEach(FlavorWheel.categories) { tab($0.name, title: $0.name) }
                    }
                    .padding(.horizontal)
                }
                .scrollIndicators(.hidden)

                List {
                    ForEach(flavors) { row($0.name) }
                    if !query.isEmpty, !flavors.contains(where: { $0.name == query }) {
                        Button("\"\(query)\" 직접 추가", systemImage: "plus") {
                            if !selection.contains(query) { selection.append(query) }
                            search = ""
                        }
                    }
                    if category == nil, query.isEmpty, !customs.isEmpty {
                        Section("직접 추가") { ForEach(customs, id: \.self) { row($0) } }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("플레이버")
            .navigationSubtitle(selection.isEmpty ? "" : "\(selection.count)개 선택")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("완료") { dismiss() } }
            }
        }
    }

    private func tab(_ name: String?, title: String) -> some View {
        Button(title) { category = name }
            .buttonStyle(.plain)
            .fontWeight(category == name ? .bold : .regular)
            .foregroundStyle(category == name ? .primary : .secondary)
            .padding(.vertical, 10)
            .overlay(alignment: .bottom) { if category == name { Rectangle().frame(height: 2) } }
    }

    private func row(_ name: String) -> some View {
        Button { toggle(name) } label: {
            HStack(spacing: 12) {
                Circle().fill(FlavorWheel.color(for: name)).frame(width: 24, height: 24)
                Text(name)
                Spacer()
                if selection.contains(name) {
                    Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(Color.accentColor)
                }
            }
        }
        .tint(.primary)
        .accessibilityLabel(name)
    }

    private func toggle(_ name: String) {
        if let i = selection.firstIndex(of: name) { selection.remove(at: i) } else { selection.append(name) }
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
