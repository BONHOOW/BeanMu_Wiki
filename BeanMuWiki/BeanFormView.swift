import SwiftUI
import SwiftData
import PhotosUI

/// 원두 생성/편집 겸용. 새 원두는 저장 시에만 insert, 기존 원두는 제자리 편집(자동 저장).
struct BeanFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var bean: Bean
    @State private var pickingFlavor = false
    @State private var photoItem: PhotosPickerItem?
    private let isNew: Bool
    @State private var before: Snapshot.BeanDTO   // 편집 전 지문. 실제로 바뀐 경우에만 updatedAt 갱신

    init(bean: Bean? = nil) {
        let target = bean ?? Bean()
        _bean = State(initialValue: target)
        _before = State(initialValue: Snapshot.BeanDTO(target, includeBrews: false))
        isNew = bean == nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("원두") {
                    field("원두명", $bean.name, prompt: "예: 에티오피아 예가체프 G1").accessibilityIdentifier("nameField")
                    field("로스터리", $bean.roaster, prompt: "예: 프릳츠").accessibilityIdentifier("roasterField")
                    OptionPickerRow(title: "로스팅 포인트", value: $bean.roastLevel, groups: BeanOptions.roastLevels, id: "roast", ownColor: true)
                    field("판매 페이지 URL", $bean.url, prompt: "https://").urlField()
                }
                Section("원산지") {
                    OptionPickerRow(title: "원산지 (국가)", value: $bean.country, groups: BeanOptions.countries, id: "country")
                    field("산지 / 재배지", $bean.region, prompt: "예: 예가체프 코체레")
                    field("농장", $bean.farm, prompt: "예: 바나코 워시드 스테이션")
                    #if os(macOS)
                    field("고도", $bean.altitude, prompt: "예: 1,900~2,100m")
                    #else
                    field("고도 (예: 1,900~2,100m)", $bean.altitude)
                    #endif
                    OptionPickerRow(title: "품종", value: $bean.variety, groups: BeanOptions.varieties, id: "variety")
                    OptionPickerRow(title: "가공 방식", value: $bean.process, groups: BeanOptions.processes, id: "process")
                }
                // 사진은 원산지 뒤: 첫 화면에 이름·로스터리·원산지가 다 보이도록 (UI 테스트도 이 순서를 가정)
                Section("패키지 사진") { photoSection }
                Section("컵노트") {
                    if bean.cupNotes.isEmpty {
                        Text("아직 없음").foregroundStyle(Color.muted)
                    } else {
                        FlavorChips(tags: bean.cupNotes)
                    }
                    Button("플레이버 선택", systemImage: "circle.grid.2x2") { pickingFlavor = true }
                        .accessibilityIdentifier("flavorPickerButton")
                }
                Section("메모") {
                    TextField("메모", text: $bean.memo, axis: .vertical).lineLimit(3...)
                }
            }
            .task(id: photoItem) {
                guard let photoItem, let data = try? await photoItem.loadTransferable(type: Data.self) else { return }
                bean.photo = Bean.compressedPhoto(data) ?? data
                bean.photoUpdatedAt = .now
            }
            .sheet(isPresented: $pickingFlavor) { FlavorPickerSheet(selection: $bean.cupNotes) }
            .navigationTitle(isNew ? "새 원두" : "원두 편집")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                if isNew {
                    ToolbarItem(placement: .cancellationAction) { Button("취소", role: .cancel) { dismiss() } }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "저장" : "완료") { save() }
                        .disabled(bean.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            #if DEBUG
            .task { try? await Task.sleep(for: .seconds(1)); if debugSheet == "flavor" { pickingFlavor = true } }
            #endif
        }
        .onDisappear {
            // 새 원두는 저장(insert)됐을 때, 기존 원두는 필드가 바뀌었을 때만 동기화 대상으로 표시
            if isNew ? bean.modelContext != nil : Snapshot.BeanDTO(bean, includeBrews: false) != before { bean.updatedAt = .now }
        }
        .formSheet()
    }

    /// 사진 없음 → 점선 타일(탭하면 선택), 있음 → 160pt 미리보기 + 변경/삭제
    @ViewBuilder private var photoSection: some View {
        if let image = bean.photo.flatMap(Image.init(data:)) {
            HStack(alignment: .top, spacing: Theme.s16) {
                image.resizable().scaledToFill()
                    .frame(width: 160, height: 160).clipShape(.rect(cornerRadius: Theme.card))
                VStack(alignment: .leading, spacing: Theme.s8) {
                    PhotosPicker(selection: $photoItem, matching: .images) { Label("사진 변경", systemImage: "photo") }
                    Button("사진 삭제", systemImage: "trash", role: .destructive) { bean.photo = nil; bean.photoUpdatedAt = .now; photoItem = nil }
                }
                .controlSize(.small)
            }
        } else {
            PhotosPicker(selection: $photoItem, matching: .images) {
                VStack(spacing: Theme.s8) {
                    Image(systemName: "photo.badge.plus").font(.title2)
                    Text("패키지 사진 추가").font(.subheadline)
                }
                .foregroundStyle(Color.muted)
                .frame(maxWidth: .infinity).frame(height: 120)
                .background(RoundedRectangle(cornerRadius: Theme.card).strokeBorder(Color.hairline, style: StrokeStyle(lineWidth: 1, dash: [6])))
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }

    /// macOS 그룹 폼은 title을 왼쪽 라벨로 쓰므로 prompt를 따로 준다. iOS는 title이 placeholder 겸 라벨.
    private func field(_ title: String, _ text: Binding<String>, prompt: String? = nil) -> some View {
        #if os(macOS)
        TextField(title, text: text, prompt: prompt.map { Text($0) })
        #else
        TextField(title, text: text)
        #endif
    }

    private func save() {
        if isNew { context.insert(bean) }
        dismiss()
    }
}
