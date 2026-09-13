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

    init(bean: Bean) {
        let brew = Brew(template: bean.favoriteBrew)
        brew.isFavorite = bean.brews.isEmpty
        _brew = State(initialValue: brew)
        self.bean = bean
    }

    init(brew: Brew) {
        _brew = State(initialValue: brew)
        bean = nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("추출 조건") {
                    DatePicker("날짜", selection: $brew.date)
                    Picker("추출 방식", selection: $brew.method) {
                        ForEach(brewMethods.contains(brew.method) ? brewMethods : brewMethods + [brew.method], id: \.self) { Text($0) }
                    }
                    LabeledContent("원두 (g)") {
                        TextField("15", value: $brew.doseGrams, format: .number.grouping(.never))
                            .accessibilityIdentifier("doseField")
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    LabeledContent("물 온도 (℃)") {
                        TextField("92", value: $brew.waterTempC, format: .number.grouping(.never))
                            .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                    }
                    LabeledContent("분쇄도") {
                        TextField("코만단테 24클릭", text: $brew.grind).multilineTextAlignment(.trailing)
                    }
                }
                Section {
                    ForEach(brew.steps.indices, id: \.self) { i in
                        let step = step(i)
                        HStack {
                            TextField("0:00", value: step.atSeconds, format: PourTimeFormat())
                                .accessibilityIdentifier("stepTime\(i)")
                                .keyboardType(.numbersAndPunctuation).frame(width: 48)
                            TextField("g", value: step.grams, format: .number.grouping(.never))
                                .accessibilityIdentifier("stepGrams\(i)")
                                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 56)
                            Text("g").foregroundStyle(.secondary)
                            TextField("블룸 · 나선형 푸어", text: step.note)
                                .accessibilityIdentifier("stepNote\(i)")
                        }
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
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    if let ratio = brew.ratioText {
                        LabeledContent("비율", value: ratio)
                    }
                    LabeledContent("추출 시간") {
                        TextField("2:45", text: $brew.time).multilineTextAlignment(.trailing)
                    }
                }
                Section("평가") {
                    HStack {
                        Text("평점")
                        Spacer()
                        ForEach(1...5, id: \.self) { i in
                            Button { brew.rating = i } label: {
                                Image(systemName: i <= brew.rating ? "star.fill" : "star")
                                    .foregroundStyle(.orange)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Toggle("기준 레시피", isOn: $brew.isFavorite)
                    TextField("테이스팅 노트 / 레시피 메모", text: $brew.notes, axis: .vertical).lineLimit(4...)
                }
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
        if let bean {
            context.insert(brew)
            brew.bean = bean
        }
        dismiss()
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
