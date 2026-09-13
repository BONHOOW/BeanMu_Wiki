import Testing
import SwiftUI
import UIKit
@testable import BeanMuWiki

@MainActor
struct FlavorWheelTests {
    @Test func nineCategoriesInSCAOrder() {
        #expect(FlavorWheel.categories.map(\.name) == ["과일", "신맛/발효", "녹색/채소", "기타", "구운", "향신료", "견과/코코아", "단맛", "꽃"])
    }

    @Test func namesUniqueAndHexWellFormed() {
        let names = FlavorWheel.all.map(\.name)
        #expect(Set(names).count == names.count)
        for hex in FlavorWheel.all.map(\.hex) + FlavorWheel.categories.map(\.hex) {
            #expect(hex.range(of: "^#[0-9A-Fa-f]{6}$", options: .regularExpression) != nil, "\(hex)")
        }
    }

    @Test func lookupAndFallbackColor() throws {
        let lemon = try #require(FlavorWheel.flavor(named: "레몬"))
        #expect(FlavorWheel.categories.first { $0.flavors.contains(lemon) }?.name == "과일")
        #expect(FlavorWheel.flavor(named: "없는향미") == nil)
        #expect(FlavorWheel.color(for: "없는향미") == .gray)
    }

    @Test func everyCategoryHasAtLeastFiveAndAllIsFlattened() {
        for category in FlavorWheel.categories { #expect(category.flavors.count >= 5, "\(category.name)") }
        #expect(FlavorWheel.all.count == FlavorWheel.categories.flatMap(\.flavors).count)
    }

    @Test func colorFromHexIsRed() {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #expect(UIColor(Color(hex: "#FF0000")).getRed(&r, green: &g, blue: &b, alpha: &a))
        #expect(abs(r - 1) < 0.001 && g < 0.001 && b < 0.001 && abs(a - 1) < 0.001)
    }
}
