import XCTest

/// 레이아웃·비율 검사 (iPhone·iPad 공용). 요소가 화면 밖으로 나가지 않고, 입력 필드 폭이 합리적이며,
/// 큰 글자 설정에서도 핵심 버튼이 살아 있는지 본다. 시드 데이터(-seed)로 시작한다.
final class LayoutTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true   // 한 화면의 위반을 모아서 본다
        app = XCUIApplication()
        app.launchArguments = ["-inMemory", "-seed"]
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    private var screen: CGRect { app.windows.firstMatch.frame }
    private let seedName = "에티오피아 예가체프 G1"

    private func element(containing text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text)).firstMatch
    }

    /// 보이는 버튼·입력 필드·텍스트가 화면 가로 밖으로 나가지 않는다 (세로는 스크롤 가능)
    private func assertOnScreen(_ context: String, file: StaticString = #filePath, line: UInt = #line) {
        for type in [XCUIElement.ElementType.button, .textField, .staticText] {
            for el in app.descendants(matching: type).allElementsBoundByIndex.prefix(60) where el.exists {
                let f = el.frame
                guard f.width > 0, f.height > 0, f.maxY > 0, f.minY < screen.maxY else { continue }
                XCTAssertGreaterThanOrEqual(f.minX, -1, "\(context): '\(el.label)' 왼쪽 밖 \(f)", file: file, line: line)
                XCTAssertLessThanOrEqual(f.maxX, screen.maxX + 1, "\(context): '\(el.label)' 오른쪽 밖 \(f)", file: file, line: line)
            }
        }
    }

    /// List가 아직 만들지 않은 화면 밖 행은 존재하지 않는다 → 보일 때까지 아래로, 그래도 없으면 위로 스크롤
    private func scrollTo(_ element: XCUIElement) {
        for _ in 0..<4 where !element.exists { app.swipeUp() }
        for _ in 0..<6 where !element.exists { app.swipeDown() }
        XCTAssertTrue(element.waitForExistence(timeout: 3), "\(element) 를 스크롤로 찾지 못함")
    }

    private func openSeedDetail() {
        let row = element(containing: seedName)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.buttons["기록 추가"].waitForExistence(timeout: 5))
    }

    /// 목록 → 상세: 잘림 없음, 히어로 사진/제목 비율
    func testListAndDetailFitScreen() {
        app.launch()
        XCTAssertTrue(element(containing: seedName).waitForExistence(timeout: 5))
        assertOnScreen("목록")
        openSeedDetail()
        assertOnScreen("상세")
        let title = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", seedName)).firstMatch
        XCTAssertTrue(title.exists, "상세 제목이 보여야 한다")
        for image in app.images.allElementsBoundByIndex.prefix(5) where image.frame.height > 0 {
            XCTAssertLessThanOrEqual(image.frame.height, screen.height * 0.45, "히어로 이미지가 화면의 45%를 넘는다 \(image.frame)")
        }
    }

    /// 폼 필드 폭: 원두명은 넉넉하고, 숫자 필드는 너무 좁지도 넓지도 않다
    func testFormFieldWidths() {
        app.launch()
        app.buttons["추가"].firstMatch.tap()
        let name = app.textFields["nameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(name.frame.width, screen.width * 0.45, "원두명 필드가 너무 좁다 \(name.frame)")
        assertOnScreen("원두 폼")
        app.buttons["취소"].tap()

        openSeedDetail()
        app.buttons["기록 추가"].tap()
        let dose = app.textFields["doseField"]
        XCTAssertTrue(dose.waitForExistence(timeout: 3))
        XCTAssertTrue((40...screen.width).contains(dose.frame.width), "원두 g 필드 폭 \(dose.frame.width)")   // iOS는 행 나머지를 채운다
        XCTAssertLessThanOrEqual(dose.frame.maxX, screen.maxX, "원두 g 필드가 오른쪽 밖 \(dose.frame)")
        let time0 = app.textFields["stepTime0"]
        if !time0.exists { app.buttons["addStepButton"].tap() }
        XCTAssertTrue(time0.waitForExistence(timeout: 3))
        XCTAssertTrue((36...110).contains(time0.frame.width), "단계 시각 필드 폭 \(time0.frame.width)")
        let grams0 = app.textFields["stepGrams0"]
        XCTAssertTrue((40...120).contains(grams0.frame.width), "단계 g 필드 폭 \(grams0.frame.width)")
        let note0 = app.textFields["stepNote0"]
        XCTAssertGreaterThanOrEqual(note0.frame.width, 80, "단계 메모 필드가 너무 좁다 \(note0.frame)")
        assertOnScreen("기록 폼")
        XCTAssertTrue(element(containing: "1:").exists || element(containing: "—").exists, "비율 헤더가 있어야 한다")
    }

    /// 설정 시트: 버튼이 화면 안, 완료는 상단
    func testSettingsSheetLayout() {
        app.launch()
        app.buttons["settingsButton"].tap()
        let export = app.buttons["exportBackup"]
        XCTAssertTrue(export.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["importBackup"].exists)
        assertOnScreen("설정")
        let done = app.buttons["완료"]
        XCTAssertTrue(done.exists)
        XCTAssertLessThan(done.frame.midY, screen.height * 0.25, "완료 버튼은 시트 상단에 있어야 한다 \(done.frame)")
        done.tap()
    }

    /// 플레이버 피커: 검색창 폭, 카테고리 탭 노출
    func testFlavorPickerLayout() {
        app.launch()
        app.buttons["추가"].firstMatch.tap()
        let pick = app.buttons["flavorPickerButton"]
        scrollTo(pick)
        pick.tap()
        let search = app.textFields["flavorSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(search.frame.width, screen.width * 0.5, "검색창이 좁다 \(search.frame)")
        XCTAssertTrue(app.buttons["전체"].exists && app.buttons["과일"].exists, "카테고리 탭이 보여야 한다")
        assertOnScreen("플레이버 피커")
        app.buttons["완료"].tap()
    }

    /// 접근성 큰 글자(AX M)에서도 핵심 버튼이 존재하고 화면 안에 있다
    func testAccessibilityLargeText() {
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityM"]
        app.launch()
        XCTAssertTrue(element(containing: seedName).waitForExistence(timeout: 5))
        assertOnScreen("목록 · 큰 글자")
        openSeedDetail()
        assertOnScreen("상세 · 큰 글자")
        app.buttons["기록 추가"].tap()
        XCTAssertTrue(app.buttons["저장"].waitForExistence(timeout: 3))
        assertOnScreen("기록 폼 · 큰 글자")
    }

    /// 가로 모드: 목록·상세가 깨지지 않는다
    func testLandscape() {
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launch()
        XCTAssertTrue(element(containing: seedName).waitForExistence(timeout: 5))
        assertOnScreen("목록 · 가로")
        openSeedDetail()
        assertOnScreen("상세 · 가로")
    }
}
