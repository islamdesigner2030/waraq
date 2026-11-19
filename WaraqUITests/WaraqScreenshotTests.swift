import XCTest

/// Walks through the app like a new user and saves a screenshot at every step.
/// The GitHub workflow exports them as the `screenshots` artifact.
///
/// Debug-only launch switches used here (see AppModel / ReaderViewController):
///   WARAQ_RESET=1        start from a clean install
///   WARAQ_FREEZE_CURL=1  hold a page mid-curl where the finger lets go
final class WaraqScreenshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    // MARK: Flows

    /// English: every screen, every toolbar tool, saving, and reopening after a relaunch.
    func test1_EnglishJourney() {
        let app = launch()
        startAndCreate(app, language: "en", prefix: "en-")

        let text = app.textViews["page.text"]
        if text.waitForExistence(timeout: 6) {
            shot("en-06-first-page")
            text.tap()
            text.typeText("Every page, a new beginning.\nA calm first line on real paper.")
            pause(0.6)
            shot("en-07-writing")
        }

        tapTool(app, "daily")
        let mit = app.textFields.matching(NSPredicate(format: "placeholderValue == %@", "The most important task")).firstMatch
        if mit.waitForExistence(timeout: 3) {
            mit.tap()
            mit.typeText("Finish the first chapter\n")
        }
        shot("en-08-daily")

        tapTool(app, "monthly")
        shot("en-09-month-calendar")

        tapTool(app, "habits")
        let habit = app.textFields.matching(NSPredicate(format: "placeholderValue == %@", "e.g. read 10 minutes")).firstMatch
        if habit.waitForExistence(timeout: 3) {
            habit.tap()
            habit.typeText("Read 10 minutes\n")
        }
        shot("en-10-habits")

        tapTool(app, "thoughts")
        let field = app.textFields["thought.field"]
        if field.waitForExistence(timeout: 3) {
            field.tap()
            field.typeText("Quiet morning, good coffee")
            app.buttons["thought.add"].tap()
            pause(0.5)
        }
        shot("en-11-thoughts")

        tapTool(app, "index")
        shot("en-12-index")

        tapTool(app, "draw", wait: 1.2)
        drawStroke(app)
        shot("en-13-drawing")
        tapTool(app, "draw", wait: 0.8)

        let save = app.buttons["editor.save"]
        if save.waitForExistence(timeout: 3) {
            save.tap()
            pause(0.7)
            shot("en-14-saved")
        }
        let home = app.buttons["toast.home"]
        if home.waitForExistence(timeout: 3) {
            home.tap()
            pause(1.2)
            shot("en-15-shelf")
        }

        // Relaunch: content and the last page must come back.
        app.terminate()
        let again = launch(reset: false)
        pause(1.0)
        again.tap()   // skip the welcome
        let cell = again.descendants(matching: .any)["notebook.cell"].firstMatch
        if cell.waitForExistence(timeout: 6) {
            cell.tap()
            pause(2.6)
            shot("en-16-reopened-last-page")
        }
    }

    /// Arabic: right-to-left interface and writing.
    func test2_ArabicJourney() {
        let app = launch()
        startAndCreate(app, language: "ar", prefix: "ar-")

        let text = app.textViews["page.text"]
        if text.waitForExistence(timeout: 6) {
            text.tap()
            text.typeText("كل صفحة بداية جديدة.\nسطر هادئ على ورق حقيقي.")
            pause(0.6)
            shot("ar-07-writing")
        }
        tapTool(app, "daily")
        shot("ar-08-daily")
        tapTool(app, "monthly")
        shot("ar-09-month-calendar")
        tapTool(app, "habits")
        shot("ar-10-habits")
        tapTool(app, "thoughts")
        shot("ar-11-thoughts")
        tapTool(app, "index")
        shot("ar-12-index")
    }

    /// The page curl, frozen mid-turn, English direction (grab the right edge).
    func test3_CurlEnglish() {
        curlShot(language: "en")
    }

    /// The page curl, frozen mid-turn, Arabic direction (grab the left edge).
    func test4_CurlArabic() {
        curlShot(language: "ar")
    }

    // MARK: Steps

    private func curlShot(language: String) {
        let app = launch(freezeCurl: true)
        startAndCreate(app, language: language, prefix: "\(language)-curl-", shots: false)
        let text = app.textViews["page.text"]
        if text.waitForExistence(timeout: 6) {
            text.tap()
            text.typeText(language == "ar" ? "اسحب طرف الصفحة لتقلبها." : "Drag the edge of the page to turn it.")
            pause(0.4)
        }
        let size = app.frame.size
        let y = size.height * 0.40   // above the keyboard
        let edgeX = language == "ar" ? 26 : size.width - 26
        let endX = language == "ar" ? size.width * 0.58 : size.width * 0.42
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: edgeX, dy: y))
        let end = origin.withOffset(CGVector(dx: endX, dy: y - 40))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: XCUIGestureVelocity(rawValue: 500), thenHoldForDuration: 0.2)
        pause(0.5)
        shot("\(language)-curl-mid-turn")
    }

    private func startAndCreate(_ app: XCUIApplication, language: String, prefix: String, shots: Bool = true) {
        let choice = app.buttons["lang.\(language)"]
        XCTAssertTrue(choice.waitForExistence(timeout: 12), "language screen")
        if shots { shot("\(prefix)01-language") }
        choice.tap()
        pause(1.8)
        if shots { shot("\(prefix)02-welcome") }
        app.tap()

        let create = app.buttons["home.create"]
        XCTAssertTrue(create.waitForExistence(timeout: 8), "empty shelf")
        pause(0.6)
        if shots { shot("\(prefix)03-shelf-empty") }
        create.tap()

        let confirm = app.buttons["create.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 6), "create screen")
        pause(0.8)
        if shots {
            shot("\(prefix)04-create")
            let colorTab = app.buttons["create.tab.color"]
            if colorTab.exists {
                colorTab.tap()
                pause(0.5)
                shot("\(prefix)04b-create-color")
                app.buttons["create.tab.shape"].tap()
            }
        }
        confirm.tap()
        pause(0.55)
        if shots { shot("\(prefix)05-cover-opening") }
        pause(2.2)
    }

    private func tapTool(_ app: XCUIApplication, _ id: String, wait: Double = 1.8) {
        let tool = app.buttons["tool.\(id)"]
        guard tool.waitForExistence(timeout: 4) else {
            XCTFail("tool \(id) not found")
            return
        }
        tool.tap()
        pause(wait)
    }

    private func drawStroke(_ app: XCUIApplication) {
        let size = app.frame.size
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let a = origin.withOffset(CGVector(dx: size.width * 0.30, dy: size.height * 0.45))
        let b = origin.withOffset(CGVector(dx: size.width * 0.62, dy: size.height * 0.52))
        a.press(forDuration: 0.05, thenDragTo: b)
        pause(0.4)
    }

    // MARK: Helpers

    private func launch(reset: Bool = true, freezeCurl: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        var env: [String: String] = [:]
        if reset { env["WARAQ_RESET"] = "1" }
        if freezeCurl { env["WARAQ_FREEZE_CURL"] = "1" }
        app.launchEnvironment = env
        app.launch()
        return app
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func pause(_ seconds: Double) {
        Thread.sleep(forTimeInterval: seconds)
    }
}
