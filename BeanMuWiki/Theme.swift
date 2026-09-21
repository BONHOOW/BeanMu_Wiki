import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// 디자인 토큰 (docs/DESIGN_DIRECTION.md §3 + Claude DESIGN.md 스케일).
/// 색은 라이트/다크 한 쌍으로만 정의하고, 큰 면에는 canvas/card, 강조는 brand/cta, 의식(★·평점)은 cherry.
enum Theme {
    // 반지름: 8 칩·입력 / 12 카드 / 16 히어로·시트 / capsule 배지
    static let chip: CGFloat = 8
    static let card: CGFloat = 12
    static let hero: CGFloat = 16
    // 간격: 4 · 8 · 12 · 16 · 24 · 32
    static let s4: CGFloat = 4, s8: CGFloat = 8, s12: CGFloat = 12, s16: CGFloat = 16, s24: CGFloat = 24, s32: CGFloat = 32
}

extension Color {
    static let canvas    = Color(light: 0xFAF9F5, dark: 0x181715)   // 화면 바닥. 순백·쿨그레이 금지
    static let card      = Color(light: 0xFFFFFF, dark: 0x252320)   // 카드·인포박스 본문
    static let cardTint  = Color(light: 0xEFE9DE, dark: 0x33302B)   // 인포박스 헤더, 비선택 칩, 카테고리 탭 활성 배경
    static let hairline  = Color(light: 0xE6DFD8, dark: 0x3A3631)   // 1px 테두리·구분선
    static let ink       = Color(light: 0x141413, dark: 0xFAF9F5)   // 본문. 순흑 금지
    static let muted     = Color(light: 0x6C6A64, dark: 0xA09D96)   // 메타·캡션
    static let brand     = Color(light: 0x2F6B45, dark: 0x6DBB84)   // 제목 강조·선택·링크 (아이콘 숲색)
    static let cta       = Color(light: 0x3E8A5A, dark: 0x7FCB96)   // 주요 버튼 채움(흰 글자). 작은 글자 금지. (`accent`는 Asset Catalog 심볼과 충돌)
    static let cherry    = Color(light: 0xD84343, dark: 0xE25A5A)   // ★ 기준 레시피, 평점. 텍스트 금지
    static let bean      = Color(light: 0x6B4423, dark: 0xA9754A)   // 로스팅 바 진한 끝, 사진 없는 원두 타일
    static let hot       = Color(light: 0xE8A55A, dark: 0xE8A55A)   // HOT 배지 (Claude accent-amber)
    static let iced      = Color(light: 0x5DB8A6, dark: 0x5DB8A6)   // ICED 배지 (Claude accent-teal)

    /// 라이트/다크 한 쌍의 동적 색
    init(light: UInt32, dark: UInt32) {
        #if os(iOS)
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light) })
        #else
        self.init(nsColor: NSColor(name: nil) { $0.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? NSColor(rgb: dark) : NSColor(rgb: light) })
        #endif
    }
}

#if os(iOS)
private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255, green: CGFloat((rgb >> 8) & 0xFF) / 255, blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
    }
}
#else
private extension NSColor {
    convenience init(rgb: UInt32) {
        self.init(srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255, green: CGFloat((rgb >> 8) & 0xFF) / 255, blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
    }
}
#endif

extension View {
    /// 카드: card 배경 + 12pt 반지름 + 헤어라인. 그림자 없음(띄우는 건 FAB만).
    func cardStyle(padding: CGFloat = Theme.s16) -> some View {
        self.padding(padding)
            .background(Color.card, in: .rect(cornerRadius: Theme.card))
            .overlay(RoundedRectangle(cornerRadius: Theme.card).strokeBorder(Color.hairline))
    }
    /// 스크롤 컨테이너(List/Form/ScrollView)의 바닥을 크림 캔버스로
    func canvasBackground() -> some View {
        scrollContentBackground(.hidden).background(Color.canvas)
    }
}

/// 라벨용 캡슐 배지 (Claude badge-pill). fill 기본은 cardTint, 강조는 hot/iced/cherry 등 20% 워시.
struct Pill: View {
    let text: String
    var fill: Color = .cardTint
    var foreground: Color = .ink

    var body: some View {
        Text(text).font(.caption.weight(.semibold))
            .padding(.horizontal, Theme.s8).padding(.vertical, 3)
            .background(fill, in: .capsule)
            .foregroundStyle(foreground)
    }
}
