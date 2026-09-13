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

    init(bean: Bean? = nil) {
        _bean = State(initialValue: bean ?? Bean())
        isNew = bean == nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("원두") {
                    TextField("원두명", text: $bean.name).accessibilityIdentifier("nameField")
                    TextField("로스터리", text: $bean.roaster).accessibilityIdentifier("roasterField")
                    TextField("로스팅 포인트 (예: 약배전)", text: $bean.roastLevel)
                    TextField("판매 페이지 URL", text: $bean.url)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section("패키지 사진") {
                    if let image = bean.photo.flatMap(UIImage.init(data:)) {
                        Image(uiImage: image).resizable().scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 220)
                    }
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(bean.photo == nil ? "사진 선택" : "사진 변경", systemImage: "photo")
                    }
                    if bean.photo != nil {
                        Button("사진 삭제", role: .destructive) { bean.photo = nil; photoItem = nil }
                    }
                }
                Section("원산지") {
                    TextField("원산지 (국가)", text: $bean.country)
                    TextField("산지 / 재배지", text: $bean.region)
                    TextField("농장", text: $bean.farm)
                    TextField("고도 (예: 1,900~2,100m)", text: $bean.altitude)
                    TextField("품종", text: $bean.variety)
                    TextField("가공 방식", text: $bean.process)
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
    }

    private func save() {
        if isNew { context.insert(bean) }
        dismiss()
    }
}
