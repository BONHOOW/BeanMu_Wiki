import Testing
import Foundation
@testable import BeanMuWiki

@MainActor
struct BeanOptionsTests {
    private let lists: [(String, [BeanOptionGroup])] = [
        ("countries", BeanOptions.countries), ("varieties", BeanOptions.varieties),
        ("processes", BeanOptions.processes), ("roastLevels", BeanOptions.roastLevels),
    ]

    @Test func countriesGroupedByRegionWithFlags() {
        #expect(BeanOptions.countries.map(\.name) == ["아프리카", "중앙아메리카·카리브", "남아메리카", "아시아·태평양"])
        let all = BeanOptions.countries.flatMap(\.options)
        #expect(all.count >= 40)
        for option in all {
            let scalars = Array(option.emoji.unicodeScalars)
            #expect(scalars.count == 2 && scalars.allSatisfy { (0x1F1E6...0x1F1FF).contains($0.value) }, "\(option.name) \(option.emoji)")
        }
    }

    @Test func groupCounts() {
        #expect(BeanOptions.varieties.count == 5)
        #expect(BeanOptions.processes.count == 5)
        #expect(BeanOptions.roastLevels.count == 1)
        #expect(BeanOptions.roastLevels[0].options.count == 7)
    }

    @Test func roastLevelsGetDarkerLightToDark() {
        let luminances = BeanOptions.roastLevels[0].options.map { luminance($0.hex) }
        for (light, dark) in zip(luminances, luminances.dropFirst()) { #expect(light > dark, "\(luminances)") }
    }

    @Test func namesUniqueHexWellFormedEmojiOnlyOnCountries() {
        for (label, groups) in lists {
            let options = groups.flatMap(\.options)
            #expect(Set(options.map(\.name)).count == options.count, "\(label)")
            for hex in options.map(\.hex) + groups.map(\.hex) {
                #expect(hex.range(of: "^#[0-9A-Fa-f]{6}$", options: .regularExpression) != nil, "\(label) \(hex)")
            }
            if label != "countries" { for o in options { #expect(o.emoji == "", "\(label) \(o.name)") } }
        }
    }

    @Test func lookupByName() {
        #expect(BeanOptions.option(named: "케냐", in: BeanOptions.countries)?.emoji == "🇰🇪")
        #expect(BeanOptions.option(named: "없음", in: BeanOptions.countries) == nil)
        #expect(BeanOptions.option(named: "없음", in: BeanOptions.varieties) == nil)
    }

    @Test func flavorsMirrorFlavorWheel() {
        #expect(BeanOptions.flavors.flatMap(\.options).count == FlavorWheel.all.count)
        #expect(BeanOptions.flavors.map(\.name) == FlavorWheel.categories.map(\.name))
    }

    /// "#RRGGBB" → 상대 휘도 (sRGB 선형화 생략 — 단조 비교에는 충분)
    private func luminance(_ hex: String) -> Double {
        let v = UInt32(hex.dropFirst(), radix: 16) ?? 0
        let r = Double((v >> 16) & 0xFF), g = Double((v >> 8) & 0xFF), b = Double(v & 0xFF)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
}
