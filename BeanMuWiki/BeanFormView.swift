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
                    TextField("원두명", text: $bean.name).accessibilityIdentifier("nameField")
                    TextField("로스터리", text: $bean.roaster).accessibilityIdentifier("roasterField")
                    OptionPickerRow(title: "로스팅 포인트", value: $bean.roastLevel, groups: BeanOptions.roastLevels, id: "roast", ownColor: true)
                    TextField("판매 페이지 URL", text: $bean.url)
                        .urlField()
                }
                Section("패키지 사진") {
                    if let image = bean.photo.flatMap(Image.init(data:)) {
                        image.resizable().scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 220)
                    }
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(bean.photo == nil ? "사진 선택" : "사진 변경", systemImage: "photo")
                    }
                    if bean.photo != nil {
                        Button("사진 삭제", role: .destructive) { bean.photo = nil; bean.photoUpdatedAt = .now; photoItem = nil }
                    }
                }
                Section("원산지") {
                    OptionPickerRow(title: "원산지 (국가)", value: $bean.country, groups: BeanOptions.countries, id: "country")
                    TextField("산지 / 재배지", text: $bean.region)
                    TextField("농장", text: $bean.farm)
                    TextField("고도 (예: 1,900~2,100m)", text: $bean.altitude)
                    OptionPickerRow(title: "품종", value: $bean.variety, groups: BeanOptions.varieties, id: "variety")
                    OptionPickerRow(title: "가공 방식", value: $bean.process, groups: BeanOptions.processes, id: "process")
                }
                Section("컵노트") {
                    if bean.cupNotes.isEmpty {
                        Text("아직 없음").foregroundStyle(.secondary)
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
        }
        .onDisappear {
            // 새 원두는 저장(insert)됐을 때, 기존 원두는 필드가 바뀌었을 때만 동기화 대상으로 표시
            if isNew ? bean.modelContext != nil : Snapshot.BeanDTO(bean, includeBrews: false) != before { bean.updatedAt = .now }
        }
        .formSheet()
    }

    private func save() {
        if isNew { context.insert(bean) }
        dismiss()
    }
}
