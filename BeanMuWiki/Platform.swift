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
    /// macOS 시트는 내용의 ideal size로 뜨므로 Form이 너무 작아진다 → 최소 크기. iOS no-op
    func formSheet() -> some View {
        #if os(macOS)
        frame(minWidth: 480, minHeight: 560)
        #else
        self
        #endif
    }
}

extension View {
    /// 앱 루트 TabView 스타일. iOS/iPad는 sidebarAdaptable, macOS는 기본 탭 + 최소 창 크기.
    /// (App 본문에서 postfix #if 체인 뒤에 수정자를 더 붙이면 macOS 26에서 창이 생성되지 않는 문제가 있어 헬퍼로 분리)
    func rootTabStyle() -> some View {
        #if os(iOS)
        tabViewStyle(.sidebarAdaptable)
        #else
        frame(minWidth: 900, minHeight: 600)
        #endif
    }
}
