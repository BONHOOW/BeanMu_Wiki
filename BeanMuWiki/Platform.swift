import SwiftUI
import ImageIO
#if os(iOS)
import UIKit
#else
import AppKit
#endif

extension Image {
    /// JPEG/PNG Data → Image. 디코딩 실패 시 nil.
    nonisolated init?(data: Data) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        self.init(decorative: cg, scale: 1)
    }
}

/// 클립보드 문자열
var pasteboardString: String? {
    #if os(iOS)
    UIPasteboard.general.string
    #else
    NSPasteboard.general.string(forType: .string)
    #endif
}

#if os(macOS)
private var awakeActivity: NSObjectProtocol?
#endif
/// 추출 타이머 중 화면 꺼짐 방지. iOS = idle timer, macOS = ProcessInfo activity
func keepScreenAwake(_ on: Bool) {
    #if os(iOS)
    UIApplication.shared.isIdleTimerDisabled = on
    #else
    if on, awakeActivity == nil {
        awakeActivity = ProcessInfo.processInfo.beginActivity(options: .idleDisplaySleepDisabled, reason: "추출 타이머")
    } else if !on, let a = awakeActivity {
        ProcessInfo.processInfo.endActivity(a); awakeActivity = nil
    }
    #endif
}

enum NumericKeys { case decimal, integer, time }

extension View {
    /// iOS 숫자 키패드. macOS는 no-op
    func numericKeyboard(_ keys: NumericKeys = .decimal) -> some View {
        #if os(iOS)
        keyboardType(keys == .decimal ? .decimalPad : keys == .integer ? .numberPad : .numbersAndPunctuation)
        #else
        self
        #endif
    }
    /// URL 입력 필드
    func urlField() -> some View {
        #if os(iOS)
        keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
        #else
        autocorrectionDisabled()
        #endif
    }
    /// 폼 시트. macOS: 그룹 폼 스타일(라벨 왼쪽·입력 오른쪽 정렬, 섹션 박스) + 창 크기 고정. iOS no-op
    func formSheet() -> some View {
        #if os(macOS)
        formStyle(.grouped).frame(minWidth: 560, idealWidth: 600, minHeight: 640, idealHeight: 720)
        #else
        self
        #endif
    }
}

extension View {
    /// 앱 루트 스타일. iOS/iPad는 사이드바 적응형 탭, macOS는 3열 창 최소 크기. 브랜드 틴트는 양쪽 공통.
    func rootStyle() -> some View {
        #if os(iOS)
        tabViewStyle(.sidebarAdaptable).tint(.brand)
        #else
        frame(minWidth: 1000, minHeight: 640).tint(.brand)
        #endif
    }
    /// macOS ⌫(삭제 명령). iOS no-op
    func deleteCommand(_ action: @escaping () -> Void) -> some View {
        #if os(macOS)
        onDeleteCommand(perform: action)
        #else
        self
        #endif
    }
}
