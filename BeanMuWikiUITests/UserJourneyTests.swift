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

    /// 값이 이미 들어 있는 숫자 필드를 새 값으로 교체 (typeText는 커서 뒤에 덧붙이므로).
    /// 포맷 필드는 값이 바뀔 때마다 다시 렌더되어 백스페이스가 씹힌다 → 숫자(한 단어)를 더블탭으로 통째로 선택한 뒤 덮어쓴다.
    /// 좁은 우측 정렬 필드는 가운데가 빈 공간이므로 오른쪽 끝의 텍스트 위를 더블탭.
    private func replaceText(in field: XCUIElement, with text: String) {
        field.tap()   // 화면 밖이면 스크롤해서 포커스 (좌표 탭은 스크롤하지 않아 키보드를 누를 수 있다)
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).doubleTap()
        for key in text { field.typeText(String(key)) }   // 한 키씩 (typeText는 호출마다 앱이 idle할 때까지 기다린다)
    }

    /// List가 아직 만들지 않은 화면 밖 행은 존재하지 않는다 → 보일 때까지 아래로, 그래도 없으면 위로 스크롤
    private func scrollTo(_ element: XCUIElement) {
        for _ in 0..<3 where !element.exists { app.swipeUp() }
        for _ in 0..<6 where !element.exists { app.swipeDown() }
        XCTAssertTrue(element.waitForExistence(timeout: 3))
    }

    /// 단일 선택 피커: "\(id)PickerButton" 행을 열고 "\(id)Search"에 검색한 뒤 row를 탭 → 시트가 닫히고 행 값이 바뀐다
    private func pick(_ id: String, search text: String? = nil, row: XCUIElement) {
        let button = app.buttons["\(id)PickerButton"]
        scrollTo(button); button.tap()
        let search = app.textFields["\(id)Search"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        if let text { search.tap(); search.typeText(text) }
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        row.tap()
        XCTAssertTrue(search.waitForNonExistence(timeout: 3))
    }

    private func value(of id: String) -> String { (app.buttons[id].value as? String) ?? "" }

    /// 루트 TabView의 탭 ("원두" / "레시피")
    private func tab(_ name: String) -> XCUIElement {
        app.tabBars.buttons[name].exists ? app.tabBars.buttons[name] : app.buttons[name]
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

        pick("country", search: "케냐", row: app.buttons["케냐"])
        XCTAssertTrue(value(of: "countryPickerButton").contains("케냐"))
        pick("roast", row: app.buttons["라이트"])
        XCTAssertTrue(value(of: "roastPickerButton").contains("라이트"))
        app.buttons["저장"].tap()

        let row = element(containing: "Kenya AA")
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        XCTAssertTrue(element(containing: "레몬").exists)
        XCTAssertTrue(element(containing: "🇰🇪").exists)   // 목록 행에 국기
        row.tap()

        let addBrew = app.buttons["기록 추가"]
        XCTAssertTrue(addBrew.waitForExistence(timeout: 3))
        XCTAssertTrue(element(containing: "케냐").exists)   // 상세 원산지 행
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

    /// 목록에 없는 품종을 검색 → "직접 추가" 행으로 입력값 그대로 선택
    func testCustomVarietyEntry() {
        app.launch()
        app.buttons["추가"].tap()
        XCTAssertTrue(app.textFields["nameField"].waitForExistence(timeout: 3))
        pick("variety", search: "루비", row: app.buttons.matching(NSPredicate(format: "label CONTAINS '직접 추가'")).firstMatch)
        XCTAssertTrue(value(of: "varietyPickerButton").contains("루비"))
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
        // 시뮬레이터에서 허용 알림이 15초쯤 뒤 저절로 닫히며 빈 문자열이 오면 앱이 "가져오기 실패"를 띄운다 → 닫고 한 번 더
        let dismissError = app.alerts.buttons.firstMatch
        if dismissError.waitForExistence(timeout: 2) { dismissError.tap(); paste.tap(); allowPasteIfAsked() }

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
        scrollTo(addBrew)   // 원산지 행이 많은 원두는 "추출 카드 열기" 아래의 이 행이 화면 밖일 수 있다
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

    /// 레시피 탭 → 추출 카드 → 타이머 시작(경과 표시가 움직임)/일시정지(멈춤)/계속 → 추출 끝 → 실측 시간이 채워진 새 기록 저장
    /// → 원두 상세에 평점 없는(☆☆☆☆☆) 기록이 추가된다
    func testRecipeTabAndTimer() {
        app.launchArguments.append("-seed")
        app.launch()
        tab("레시피").tap()
        let card = element(containing: "에티오피아 예가체프 G1")
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()

        let start = app.buttons["startTimer"]
        XCTAssertTrue(start.waitForExistence(timeout: 3))
        start.tap()
        let elapsed = app.staticTexts["elapsedTime"]
        XCTAssertTrue(elapsed.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.matching(identifier: "elapsedTime").matching(NSPredicate(format: "label != '0:00'"))
            .firstMatch.waitForExistence(timeout: 3))   // 경과 시간이 움직인다

        app.buttons["pauseTimer"].tap()
        let paused = elapsed.label
        sleep(2)
        XCTAssertEqual(elapsed.label, paused)   // 일시정지 중엔 멈춰 있다

        app.buttons["resumeTimer"].tap()

        // 초기화: 저장 없이 0:00으로 돌아가 '타이머 시작'이 다시 보인다 (확인 다이얼로그 거침)
        app.buttons["resetTimer"].tap()
        let dialog = app.sheets.firstMatch   // confirmationDialog는 Sheet로 노출된다
        XCTAssertTrue(dialog.waitForExistence(timeout: 3))
        dialog.buttons["초기화"].tap()
        XCTAssertTrue(app.buttons["startTimer"].waitForExistence(timeout: 3))

        app.buttons["startTimer"].tap()
        sleep(1)
        app.buttons["finishBrew"].tap()   // '기록하기' → 새 기록 폼
        XCTAssertTrue(element(containing: "새 기록").waitForExistence(timeout: 3))
        // 추출 시간 필드(식별자 없음): 단계 시각 필드를 뺀 m:ss 값 필드
        let measured = app.textFields.matching(NSPredicate(format: "NOT identifier BEGINSWITH 'stepTime' AND value MATCHES '^[0-9]+:[0-9]{2}$'")).firstMatch
        scrollTo(measured)
        XCTAssertNotEqual(measured.value as? String, "0:00")
        app.buttons["저장"].tap()
        XCTAssertTrue(app.buttons["저장"].waitForNonExistence(timeout: 3))   // 시트 닫힘 → 카드로 복귀

        app.navigationBars.buttons.firstMatch.tap()   // 뒤로 (카드에선 탭 바가 숨겨진다)
        let beans = tab("원두")
        XCTAssertTrue(beans.waitForExistence(timeout: 3))
        beans.tap()
        let row = element(containing: "에티오피아 예가체프 G1")
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        row.tap()
        scrollTo(element(containing: "☆☆☆☆☆"))   // 평점 0으로 저장된 새 기록
    }

    /// 상세 화면 상단 "추출 카드 열기" 행 → 추출 카드
    func testOpenBrewCardFromDetail() {
        app.launchArguments.append("-seed")
        app.launch()
        let row = element(containing: "에티오피아 예가체프 G1")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let open = app.descendants(matching: .any).matching(identifier: "openBrewCard").firstMatch
        scrollTo(open)
        open.tap()
        XCTAssertTrue(app.buttons["startTimer"].waitForExistence(timeout: 3))
    }
}
