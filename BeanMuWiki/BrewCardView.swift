import SwiftUI
import SwiftData

/// 추출하면서 보는 한 화면: 레시피 조건 · 지금/다음 단계 · 타이머. 읽기 전용.
/// 마지막 단계보다 늦은 총 추출 시간(brew.time)이 있으면 "드리퍼 제거" 행이 붙는다.
struct BrewCardView: View {
    let brew: Brew
    @State private var timer = BrewTimer()
    @State private var notesExpanded = false
    @State private var finishing = false
    @State private var confirmingReset = false

    private var steps: [PourStep] { brew.steps }
    private var endSeconds: Int? {
        guard let end = PourStep.seconds(from: brew.time), end > (steps.last?.atSeconds ?? -1) else { return nil }
        return end
    }
    /// 단계 시작 시각 + 종료 시각. 인덱스 steps.count = 종료 행
    private var times: [Int] { steps.map(\.atSeconds) + (endSeconds.map { [$0] } ?? []) }

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.2, paused: !timer.isRunning)) { context in
            let elapsed = timer.elapsed(at: context.date)
            let phase = timer.started ? times.lastIndex { Double($0) <= elapsed } : nil
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    nowPanel(elapsed: elapsed, phase: phase)
                    stepList(phase: phase)
                    notes
                }
                .padding()
            }
            .sensoryFeedback(trigger: phase) { _, new in
                new == steps.count && endSeconds != nil ? .success : .impact
            }
        }
        .navigationTitle("추출 카드")
        .toolbarTitleDisplayMode(.inline)
        #if os(iOS)
        .toolbar(.hidden, for: .tabBar)
        #endif
        .safeAreaBar(edge: .bottom) {
            HStack {
                if !timer.started {
                    wide("타이머 시작", id: "startTimer") { start() }.buttonStyle(.glassProminent)
                } else {
                    if timer.isRunning {
                        wide("일시정지", id: "pauseTimer") { timer.pause() }.buttonStyle(.glassProminent)
                    } else {
                        wide("계속", id: "resumeTimer") { start() }.buttonStyle(.glassProminent)
                    }
                    wide("초기화", id: "resetTimer") { confirmingReset = true }.buttonStyle(.glass)
                        .confirmationDialog("타이머를 0:00으로 되돌릴까요?", isPresented: $confirmingReset, titleVisibility: .visible) {
                            Button("초기화", role: .destructive) { reset() }
                        } message: {
                            Text("지금까지 측정한 시간은 저장되지 않습니다. 기록을 남기려면 '기록하기'를 누르세요.")
                        }
                    wide("기록하기", id: "finishBrew") { finish() }.buttonStyle(.glass)
                }
            }
            .controlSize(.large)
            .padding()
        }
        .sheet(isPresented: $finishing) {
            if let bean = brew.bean {
                BrewFormView(bean: bean, template: brew, measuredTime: PourStep.timeString(Int(timer.elapsed(at: .now))))
            }
        }
        .onDisappear { keepScreenAwake(false) }
    }

    // MARK: 섹션

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(brew.bean?.name ?? "").font(.title2.bold())
                if brew.isFavorite {
                    Text("★ 기준 레시피").font(.caption.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(.yellow.opacity(0.25), in: .capsule)
                }
                ServingChip(brew: brew)
            }
            let origin = [brew.method, brew.bean?.countryText ?? "", brew.bean?.roastLevel ?? ""].filter { !$0.isEmpty }
            Text(origin.joined(separator: " · ")).font(.subheadline).foregroundStyle(.secondary)
            Text(brew.conditionLine).font(.system(.body, design: .rounded)).monospacedDigit()
        }
    }

    @ViewBuilder
    private func nowPanel(elapsed: TimeInterval, phase: Int?) -> some View {
        if !timer.started {
            Text("타이머를 시작하면 단계가 순서대로 안내됩니다").foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(PourStep.timeString(Int(elapsed)))
                    .font(.system(size: 56, weight: .semibold, design: .rounded))
                    .accessibilityIdentifier("elapsedTime")
                if let phase {
                    Text(phase < steps.count ? "지금 · \(phase + 1)차 푸어 → \(target(phase))" : "지금 · 드리퍼 제거 · 추출 종료")
                        .font(.title3.weight(.semibold))
                    if phase < steps.count, !steps[phase].note.isEmpty {
                        Text(steps[phase].note).foregroundStyle(.secondary)
                    }
                } else {
                    Text("지금 · 대기").font(.title3.weight(.semibold))
                }
                let next = (phase ?? -1) + 1
                if next < times.count {
                    let wait = Int((Double(times[next]) - elapsed).rounded(.up))
                    Text("다음 · \(PourStep.timeString(times[next])) → \(target(next)) (\(max(0, wait))초 후)")
                        .font(.subheadline)
                    if next < steps.count, !steps[next].note.isEmpty {
                        Text(steps[next].note).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            .font(.system(.body, design: .rounded)).monospacedDigit()
        }
    }

    /// 단계 i의 목표: "120g", 종료 행이면 "추출 종료"
    private func target(_ i: Int) -> String { i < steps.count ? steps[i].grams.gramsText : "추출 종료" }

    private func stepList(phase: Int?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(steps.indices, id: \.self) { i in
                row(time: steps[i].timeText, grams: steps[i].grams.gramsText, note: steps[i].note, state: state(i, phase))
            }
            if let endSeconds {
                row(time: PourStep.timeString(endSeconds), grams: "", note: "드리퍼 제거 / 추출 종료", state: state(steps.count, phase))
            }
        }
    }

    private enum RowState { case done, current, upcoming }

    private func state(_ i: Int, _ phase: Int?) -> RowState {
        guard let phase else { return .upcoming }
        return i < phase ? .done : i == phase ? .current : .upcoming
    }

    private func row(time: String, grams: String, note: String, state: RowState) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(time).frame(width: 44, alignment: .leading)
            Text(grams).font(.system(.title3, design: .rounded, weight: .bold)).frame(width: 64, alignment: .trailing)
            Text(note)
            Spacer(minLength: 0)
            if state == .done { Image(systemName: "checkmark") }
        }
        .font(.system(.body, design: .rounded)).monospacedDigit()
        .foregroundStyle(state == .done ? Color.secondary : state == .current ? Color.accentColor : Color.primary)
        .padding(.vertical, 10).padding(.leading, 12)
        .overlay(alignment: .leading) {
            if state == .current { RoundedRectangle(cornerRadius: 1.5).fill(.tint).frame(width: 3) }
        }
    }

    @ViewBuilder
    private var notes: some View {
        if !brew.notes.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(brew.notes).lineLimit(notesExpanded ? nil : 2).foregroundStyle(.secondary)
                Button(notesExpanded ? "접기" : "더 보기") { notesExpanded.toggle() }.font(.subheadline)
            }
        }
    }

    // MARK: 동작

    private func wide(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).frame(maxWidth: .infinity) }.accessibilityIdentifier(id)
    }

    private func start() {
        timer.start()
        keepScreenAwake(true)
    }

    /// 저장 없이 멈추고 0:00으로. 다시 '타이머 시작' 상태가 된다.
    private func reset() {
        timer.reset()
        keepScreenAwake(false)
    }

    /// 타이머를 멈추고 이 레시피로 새 기록(실측 시간 채움)을 연다. 원두가 없으면 멈추기만.
    private func finish() {
        timer.pause()
        keepScreenAwake(false)
        finishing = brew.bean != nil
    }
}

/// 스톱워치. 경과 시간을 시각으로 계산하므로 탭 전환·백그라운드에도 어긋나지 않는다.
@Observable final class BrewTimer {
    private(set) var startDate: Date?
    private(set) var accumulated: TimeInterval = 0
    private(set) var started = false
    var isRunning: Bool { startDate != nil }

    func elapsed(at now: Date) -> TimeInterval {
        accumulated + (startDate.map { max(0, now.timeIntervalSince($0)) } ?? 0)
    }
    func start() { started = true; startDate = .now }
    func pause() { accumulated = elapsed(at: .now); startDate = nil }
    func reset() { startDate = nil; accumulated = 0; started = false }
}

/// HOT(주황) / ICED(시안) 캡슐 태그
struct ServingChip: View {
    let brew: Brew

    var body: some View {
        Text(brew.servingLabel).font(.caption.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background((brew.isIced ? Color.cyan : .orange).opacity(0.25), in: .capsule)
    }
}

extension Brew {
    /// "15g · 240g · 92℃ · 코만단테 24클릭 · 1:16" (없는 항목은 생략). ICED는 " · 얼음 120g · 최종 1:15"가 붙는다
    var conditionLine: String {
        var parts: [String?] = [doseGrams?.gramsText, waterGrams?.gramsText, waterTempC.map { "\($0)℃" },
                                grind.isEmpty ? nil : grind, ratioText]
        if isIced { parts += [iceGrams.map { "얼음 " + $0.gramsText }, finalRatioText.map { "최종 " + $0 }] }
        return parts.compactMap { $0 }.joined(separator: " · ")
    }
}

extension Bean {
    /// "🇪🇹 에티오피아" (국기가 없으면 이름만)
    var countryText: String {
        let flag = BeanOptions.option(named: country, in: BeanOptions.countries)?.emoji ?? ""
        return flag.isEmpty ? country : "\(flag) \(country)"
    }
}

extension Double {
    /// 240 → "240g", 12.5 → "12.5g"
    var gramsText: String { formatted(.number.precision(.fractionLength(0...1))) + "g" }
}
