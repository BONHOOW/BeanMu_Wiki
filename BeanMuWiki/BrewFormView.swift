import SwiftUI
import SwiftData

/// 추출 기록 생성/편집 겸용. 새 기록은 기준 레시피 값을 미리 채운다.
struct BrewFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var brew: Brew
    @State private var waterTyped = false   // 이번 편집에서 사용자가 물 총량을 단계와 다르게 직접 적었는지
    private let bean: Bean?   // 새 기록일 때만 세팅
    private var isNew: Bool { bean != nil }
    @State private var before: Snapshot.BrewDTO   // 편집 전 지문

    init(bean: Bean) {
        let brew = Brew(template: bean.favoriteBrew)
        brew.isFavorite = bean.brews.isEmpty
        _brew = State(initialValue: brew)
        _before = State(initialValue: Snapshot.BrewDTO(brew))
        self.bean = bean
    }

    init(brew: Brew) {
        _brew = State(initialValue: brew)
        _before = State(initialValue: Snapshot.BrewDTO(brew))
        bean = nil
    }

    /// 추출 카드의 "추출 끝": 이 레시피대로 새 기록을 만들고 실측 시간만 채운다. 평점·기준 레시피는 비워 둔다.
    init(bean: Bean, template: Brew, measuredTime: String) {
        let brew = Brew(template: template)
        brew.time = measuredTime
        brew.rating = 0
        brew.isFavorite = false
        _brew = State(initialValue: brew)
        _before = State(initialValue: Snapshot.BrewDTO(brew))
        self.bean = bean
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // 숫자 헤더: 이 기록만의 숫자(비율·온도·시간)를 크게. 입력하면 바로 갱신
                    HStack(spacing: 0) {
                        stat("비율", brew.ratioText ?? "—")
                        if brew.isIced { stat("최종", brew.finalRatioText ?? "—") }   // "최종 비율" 행은 결과 섹션에
                        stat("온도", brew.waterTempC.map { "\($0)℃" } ?? "—")
                        stat("시간", brew.time.isEmpty ? "—" : brew.time)
                    }
                    .cardStyle()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                Section("추출 조건") {
                    Picker("서빙", selection: $brew.isIced) {
                        Text("HOT").tag(false)
                        Text("ICED").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("servingPicker")
                    DatePicker("날짜", selection: $brew.date)
                    Picker("추출 방식", selection: $brew.method) {
                        ForEach(brewMethods.contains(brew.method) ? brewMethods : brewMethods + [brew.method], id: \.self) { Text($0) }
                    }
                    LabeledContent("원두 (g)") {
                        TextField("15", value: $brew.doseGrams, format: .number.grouping(.never))
                            .accessibilityIdentifier("doseField")
                            .numericKeyboard().trailingNumber()
                    }
                    if brew.isIced {
                        LabeledContent("얼음 (g)") {
                            TextField("120", value: $brew.iceGrams, format: .number.grouping(.never))
                                .accessibilityIdentifier("iceField")
                                .numericKeyboard().trailingNumber()
                        }
                    }
                    LabeledContent("물 온도 (℃)") {
                        TextField("92", value: $brew.waterTempC, format: .number.grouping(.never))
                            .numericKeyboard(.integer).trailingNumber()
                    }
                    LabeledContent("분쇄도") {
                        TextField("코만단테 24클릭", text: $brew.grind).trailingNumber(width: 220)
                    }
                }
                Section {
                    ForEach(brew.steps.indices, id: \.self) { i in
                        let step = step(i)
                        HStack {
                            Text("\(i + 1)차").font(.caption).foregroundStyle(Color.muted).frame(width: 28, alignment: .leading)
                            TextField("0:00", value: step.atSeconds, format: PourTimeFormat())
                                .accessibilityIdentifier("stepTime\(i)")
                                .numericKeyboard(.time).plainField().frame(width: Self.timeWidth)
                            TextField("g", value: step.grams, format: .number.grouping(.never))
                                .accessibilityIdentifier("stepGrams\(i)")
                                .numericKeyboard().plainField().multilineTextAlignment(.trailing).frame(width: Self.gramsWidth)
                            Text("g").foregroundStyle(Color.muted)
                            TextField("블룸 · 나선형 푸어", text: step.note)
                                .accessibilityIdentifier("stepNote\(i)").plainField()
                        }
                        .contextMenu { Button("삭제", role: .destructive) { brew.steps.remove(at: i) } }
                    }
                    .onDelete { brew.steps.remove(atOffsets: $0) }
                    Button("단계 추가", systemImage: "plus") { addStep() }
                        .accessibilityIdentifier("addStepButton")
                } header: {
                    Text("푸어 단계")
                } footer: {
                    Text("시작 시각 m:ss · 저울 누적 g · 메모")
                }
                Section("결과") {
                    LabeledContent("물 총량 (g)") {
                        TextField("240", value: $brew.waterGrams, format: .number.grouping(.never))
                            .accessibilityIdentifier("waterField")
                            .numericKeyboard().trailingNumber()
                    }
                    if brew.isIced {
                        if let ratio = brew.ratioText { LabeledContent("브루 비율", value: ratio) }
                        if let final = brew.finalRatioText { LabeledContent("최종 비율", value: final) }
                        if let water = brew.waterGrams { LabeledContent("최종 음료", value: (water + (brew.iceGrams ?? 0)).gramsText) }
                    } else if let ratio = brew.ratioText {
                        LabeledContent("비율", value: ratio)
                    }
                    LabeledContent("추출 시간") {
                        TextField("2:45", text: $brew.time).trailingNumber()
                    }
                }
                Section("평가") {
                    HStack {
                        Text("평점")
                        Spacer()
                        ForEach(1...5, id: \.self) { i in
                            Button { brew.rating = i } label: {
                                Image(systemName: "star.fill").font(.title3)
                                    .foregroundStyle(i <= brew.rating ? Color.cherry : Color.hairline)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(i)점")
                        }
                    }
                    Toggle("기준 레시피", isOn: $brew.isFavorite).tint(.cta)
                    TextField("테이스팅 노트 / 레시피 메모", text: $brew.notes, axis: .vertical).lineLimit(4...)
                }
            }
            .onChange(of: brew.isIced) { _, iced in
                // 새 기록만: 서빙을 바꾸면 그 서빙의 기준 레시피로 다시 채운다. 그 서빙의 첫 기록이면 ★
                guard let bean else { return }
                let template = bean.favoriteBrew(iced: iced)
                if let template { brew.copyRecipe(from: template) }
                brew.isFavorite = template == nil
            }
            .onChange(of: brew.waterGrams) { waterTyped = brew.waterGrams != brew.steps.last?.grams }
            .onChange(of: brew.steps) { _, new in
                // 물 총량은 마지막 단계를 따라간다. 사용자가 직접 더 큰 값을 적었으면(바이패스 등) 그대로 둔다.
                guard let last = new.last?.grams else { return }
                if !waterTyped || (brew.waterGrams ?? 0) < last { brew.waterGrams = last }
            }
            .navigationTitle(isNew ? "새 기록" : "기록 편집")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                if isNew {
                    ToolbarItem(placement: .cancellationAction) { Button("취소", role: .cancel) { dismiss() } }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "저장" : "완료") { save() }
                }
            }
        }
        .onDisappear {
            if isNew ? brew.modelContext != nil : Snapshot.BrewDTO(brew) != before { brew.updatedAt = .now }
        }
        .formSheet()
    }

    #if os(macOS)
    private static let timeWidth: CGFloat = 64, gramsWidth: CGFloat = 72
    #else
    private static let timeWidth: CGFloat = 48, gramsWidth: CGFloat = 56
    #endif

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title2.weight(.semibold)).fontDesign(.rounded).monospacedDigit().foregroundStyle(Color.ink)
            Text(label).font(.caption).foregroundStyle(Color.muted)
        }
        .frame(maxWidth: .infinity)
    }

    /// 행을 지우면 SwiftUI가 사라지는 행을 옛 인덱스로 한 번 더 그린다 → 범위 밖이면 빈 값으로 받아넘긴다 (직접 $brew.steps[i]를 쓰면 크래시)
    private func step(_ i: Int) -> Binding<PourStep> {
        Binding(get: { brew.steps.indices.contains(i) ? brew.steps[i] : PourStep(atSeconds: 0, grams: 0, note: "") },
                set: { if brew.steps.indices.contains(i) { brew.steps[i] = $0 } })
    }

    /// 첫 단계는 블룸(원두 ×3), 이후는 이전 단계 +30초 / +60g
    private func addStep() {
        if let prev = brew.steps.last {
            brew.steps.append(PourStep(atSeconds: prev.atSeconds + 30, grams: prev.grams + 60, note: ""))
        } else {
            brew.steps.append(PourStep(atSeconds: 0, grams: (brew.doseGrams ?? 15) * 3, note: "블룸"))
        }
    }

    private func save() {
        if !brew.isIced { brew.iceGrams = nil }
        if let bean {
            context.insert(brew)
            brew.bean = bean
        }
        if brew.isFavorite { brew.bean?.setFavorite(brew) }   // 같은 서빙의 다른 ★만 해제
        dismiss()
    }
}

private extension View {
    /// macOS 그룹 폼은 TextField의 title을 라벨로 그린다 → LabeledContent 안의 필드는 title(placeholder)을 숨긴다. iOS no-op
    func plainField() -> some View {
        #if os(macOS)
        labelsHidden()
        #else
        self
        #endif
    }
    /// LabeledContent 오른쪽의 값 필드. macOS는 폭 고정 + 라벨 숨김
    func trailingNumber(width: CGFloat = 96) -> some View {
        #if os(macOS)
        plainField().frame(width: width).multilineTextAlignment(.trailing)
        #else
        multilineTextAlignment(.trailing)
        #endif
    }
}

/// "m:ss" ↔ 초. TextField(value:format:)가 커밋 시점에만 파싱하므로 입력 중 값이 튀지 않는다.
private struct PourTimeFormat: ParseableFormatStyle {
    struct Strategy: ParseStrategy {
        func parse(_ value: String) throws -> Int {
            guard let seconds = PourStep.seconds(from: value) else { throw CocoaError(.formatting) }
            return seconds
        }
    }
    var parseStrategy: Strategy { Strategy() }
    func format(_ value: Int) -> String { PourStep.timeString(value) }
}
