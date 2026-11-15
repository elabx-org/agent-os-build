import XCTest

/// Taps the keyboard bar's real Paste control with text copied outside the app
final class PasteTap: XCTestCase {
    func shot(_ name: String) {
        let dir = ProcessInfo.processInfo.environment["PROBE_OUT"] ?? NSTemporaryDirectory()
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let url = URL(fileURLWithPath: dir).appendingPathComponent(name + ".png")
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: url)
        print("PROBE shot \(url.path)")
    }

    func testPasteTap() {
        continueAfterFailure = true
        let app = XCUIApplication()
        app.launchArguments = ["-serverURL", "http://127.0.0.1:8123/"]
        app.launch()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 6) { allow.tap(); print("PROBE allowed notifications") }
        shot("0-launched")
        let box = app.webViews.textViews.firstMatch
        let found = box.waitForExistence(timeout: 25)
        print("PROBE box \(found)")
        shot("1-loaded")
        if !found { print("PROBE tree \(app.debugDescription)"); XCTFail("no text box"); return }
        box.tap()
        sleep(3)
        // The keyboard's first-run tip covers the bar
        for owner in [app, springboard] {
            let go = owner.descendants(matching: .any).matching(NSPredicate(format: "label == 'Continue'")).firstMatch
            if go.exists { go.tap(); print("PROBE continued"); sleep(2); break }
        }
        if app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Speed up'")).firstMatch.exists {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.915)).tap()
            print("PROBE continued by point"); sleep(2)
        }
        shot("2-focused")
        let named = NSPredicate(format: "label CONTAINS[c] 'paste' OR identifier CONTAINS[c] 'paste'")
        let paste = app.descendants(matching: .any).matching(named).firstMatch
        let has = paste.waitForExistence(timeout: 5)
        print("PROBE paste exists \(has)")
        if !has { print("PROBE tree \(app.debugDescription)"); XCTFail("no paste control"); return }
        print("PROBE paste frame \(paste.frame) type \(paste.elementType.rawValue) label \(paste.label) hittable \(paste.isHittable)")
        paste.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        print("PROBE tapped")
        sleep(4)
        if app.state == .runningForeground, (app.webViews.textViews.firstMatch.value as? String ?? "").isEmpty {
            shot("3-first-tap")
            app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: paste.frame.midX, dy: paste.frame.midY)).tap()
            print("PROBE tapped by point")
            sleep(4)
        }
        shot("3-after")
        print("PROBE state \(app.state.rawValue)")
        let prompt = springboard.buttons["Allow Paste"]
        print("PROBE allow-paste prompt \(prompt.exists) app prompt \(app.buttons["Allow Paste"].exists)")
        print("PROBE value \(String(describing: app.webViews.textViews.firstMatch.value))")
        XCTAssertEqual(app.state, .runningForeground)
    }
}
