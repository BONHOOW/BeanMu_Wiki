import XCTest

final class UserJourneyTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-inMemory"]   // 매번 빈 상태
    }

    /// 라벨 또는 값에 text가 포함된 첫 요소 (SwiftUI가 행·버튼·LabeledContent의 텍스트를 하나로 합치므로 CONTAINS로 찾는다)
    private func element(containing text: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text)).firstMatch
    }

    /// 합성 탭으로 클립보드를 읽으면 iOS가 붙여넣기 허용 알림을 띄울 수 있다 → 허용.
    /// 알림이 떠 있는 동안 UIPasteboard.general.string이 앱 메인 스레드를 막으므로 앱보다 SpringBoard를 먼저 조회한다 (앱 스냅샷은 타임아웃).
    private func allowPasteIfAsked() {
        let predicate = NSPredicate(format: "(label CONTAINS '허용' AND NOT label CONTAINS '안 함') OR label CONTAINS[c] 'Allow Paste'")
        for host in [XCUIApplication(bundleIdentifier: "com.apple.springboard"), app!] {
            let allow = host.buttons.matching(predicate).firstMatch
            if allow.waitForExistence(timeout: 2) { allow.tap(); return }
        }
    }

    /// 값이 이미 들어 있는 숫자 필드를 지우고 새로 입력 (typeText는 커서 뒤에 덧붙이므로).
    /// 좁은 우측 정렬 필드는 가운데를 탭하면 커서가 텍스트 앞에 놓여 백스페이스가 먹지 않는다 → 오른쪽 끝을 탭
    private func replaceText(in field: XCUIElement, with text: String) {
        field.tap()   // 화면 밖이면 스크롤해서 포커스 (좌표 탭은 스크롤하지 않아 키보드를 누를 수 있다)
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        let current = (field.value as? String) ?? ""
        // 값이 바뀔 때마다 필드가 다시 포맷·렌더되어 빠른 연속 입력이 씹힐 수 있다 → 한 키씩 (typeText는 호출마다 앱이 idle할 때까지 기다린다)
        for key in Array(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + text.map(String.init) { field.typeText(key) }
    }

    /// List가 아직 만들지 않은 아래쪽 행은 존재하지 않는다 → 보일 때까지 스크롤
    private func scrollTo(_ element: XCUIElement) {
        for _ in 0..<3 where !element.exists { app.swipeUp() }
        XCTAssertTrue(element.waitForExistence(timeout: 3))
    }

    /// 빈 상태 → 원두 추가(플레이버 시트) → 목록 → 상세 → 기록 추가(푸어 단계·물 총량 동기화·비율) → 상세에 기록 표시
    func testUserJourney() {
        app.launch()
        XCTAssertTrue(element(containing: "원두를 추가해보세요").waitForExistence(timeout: 5))

        app.buttons["추가"].tap()
        let name = app.textFields["nameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap(); name.typeText("Kenya AA")
        app.textFields["roasterField"].tap(); app.textFields["roasterField"].typeText("Fritz")

        let pickFlavor = app.buttons["flavorPickerButton"]
        scrollTo(pickFlavor)
        pickFlavor.tap()
        let search = app.textFields["flavorSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.tap(); search.typeText("레몬")
        let lemon = app.buttons["레몬"]
        XCTAssertTrue(lemon.waitForExistence(timeout: 3))
        lemon.tap()
        app.buttons["완료"].tap()
        app.buttons["저장"].tap()

        let row = element(containing: "Kenya AA")
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        XCTAssertTrue(element(containing: "레몬").exists)
        row.tap()

        let addBrew = app.buttons["기록 추가"]
        XCTAssertTrue(addBrew.waitForExistence(timeout: 3))
        addBrew.tap()
        let dose = app.textFields["doseField"]
        XCTAssertTrue(dose.waitForExistence(timeout: 3))
        dose.tap(); dose.typeText("15")
        let addStep = app.buttons["addStepButton"]
        addStep.tap(); addStep.tap()
        let grams1 = app.textFields["stepGrams1"]
        XCTAssertTrue(grams1.waitForExistence(timeout: 3))
        replaceText(in: grams1, with: "240")
        app.textFields["stepNote1"].tap()   // 숫자 필드는 포커스가 떠날 때 값이 반영된다
        let water = app.textFields["waterField"]
        XCTAssertTrue(water.waitForExistence(timeout: 3))
        XCTAssertEqual(water.value as? String, "240")   // 물 총량은 마지막 단계를 따라간다
        XCTAssertTrue(element(containing: "1:16").waitForExistence(timeout: 3))   // 비율 계산 표시
        app.buttons["저장"].tap()

        XCTAssertTrue(element(containing: "V60").waitForExistence(timeout: 3))
        XCTAssertTrue(element(containing: "1:16").exists)
        XCTAssertTrue(element(containing: "2단계").exists)
    }

    /// ChatGPT JSON을 클립보드에 넣고 가져오기 버튼으로 가져오기 → 새 원두 상세로 이동 (steps 포함)
    func testImportFromClipboard() {
        UIPasteboard.general.string = """
        ```json
        {"bean":{"name":"Ethiopia Yirgacheffe","roaster":"Fritz","country":"Ethiopia","cupNotes":["자스민","레몬"]},
         "brews":[{"method":"V60","doseGrams":15,"waterGrams":250,"waterTempC":94,"grind":"E80 32 Step","time":"2:40","notes":"블룸 45g 45초","isFavorite":true,
                   "steps":[{"at":"0:00","grams":45,"note":"블룸"},{"at":"0:45","grams":250}]}]}
        ```
        """
        app.launch()   // 클립보드를 채운 뒤 실행해야 한다
        let paste = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS '가져오기' OR label CONTAINS[c] 'paste' OR label CONTAINS '붙여넣기' OR label CONTAINS '붙이기'")).firstMatch
        XCTAssertTrue(paste.waitForExistence(timeout: 5))
        paste.tap()
        allowPasteIfAsked()

        XCTAssertTrue(element(containing: "Ethiopia Yirgacheffe").waitForExistence(timeout: 5))
        XCTAssertTrue(element(containing: "Ethiopia").exists)
        XCTAssertTrue(element(containing: "V60").exists)
        XCTAssertTrue(element(containing: "1:16.7").exists)
        XCTAssertTrue(element(containing: "2단계").exists)
    }

    /// 시드 데이터의 기준 레시피(4단계)를 템플릿으로 새 기록 → 첫 단계 스와이프 삭제 → 다음 단계가 0번으로 올라온다
    func testDeletePourStep() {
        app.launchArguments.append("-seed")
        app.launch()
        let row = element(containing: "에티오피아 예가체프 G1")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let addBrew = app.buttons["기록 추가"]
        XCTAssertTrue(addBrew.waitForExistence(timeout: 3))
        addBrew.tap()

        let time0 = app.textFields["stepTime0"]
        XCTAssertTrue(time0.waitForExistence(timeout: 3))
        XCTAssertEqual(time0.value as? String, "0:00")
        XCTAssertTrue(app.textFields["stepTime3"].exists)

        app.cells.containing(.textField, identifier: "stepTime0").firstMatch.swipeLeft()
        let delete = app.buttons.matching(NSPredicate(format: "label == '삭제' OR label == 'Delete'")).firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        delete.tap()

        XCTAssertTrue(app.textFields["stepTime3"].waitForNonExistence(timeout: 3))
        XCTAssertEqual(time0.value as? String, "0:45")
    }
}
