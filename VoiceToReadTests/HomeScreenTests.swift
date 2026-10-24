import XCTest
import UIKit

final class HomeScreenTests: XCTestCase {
    @MainActor
    private func trainingEntry(in app: XCUIApplication) -> XCUIElement {
        let module = app.segmentedControls["communicationMode"].buttons["Train"]
        return module.exists ? module : app.buttons["englishTrainingEntry"]
    }

    @MainActor
    private func playConversationTranslation(_ app: XCUIApplication, timeout: TimeInterval) {
        let button = app.buttons["conversationTranslationPlayback"]
        XCTAssertTrue(button.waitForExistence(timeout: timeout))
        XCTAssertEqual(button.label, "Play translation", "Translation must wait for an explicit playback request")
        button.tap()
        XCTAssertEqual(button.label, "Stop translation")
    }


    @MainActor
    func testHomeFullScreenAccessoryAndLeadingLibraryMenu() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-communication", "--ui-test-conversation", "--ui-test-live-translation"]
        app.launch()
        let mode = app.segmentedControls["communicationMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 20))
        let conversation = app.buttons["conversationFullScreenButton"]
        XCTAssertTrue(conversation.isHittable)
        conversation.tap()
        XCTAssertFalse(mode.exists)
        XCTAssertEqual(conversation.label, "Exit full screen")
        XCTAssertTrue(app.buttons["conversationSpanishTurn"].isHittable)
        conversation.tap()
        XCTAssertTrue(mode.waitForExistence(timeout: 5))
        mode.buttons["Listen"].tap()
        let listening = app.buttons["fullScreenButton"]
        XCTAssertTrue(listening.waitForExistence(timeout: 5))
        XCTAssertFalse(conversation.exists)
        listening.tap()
        XCTAssertEqual(listening.label, "Exit full screen")
        XCTAssertTrue(app.buttons["primaryCaptionAction"].isHittable)
        listening.tap()
        XCTAssertTrue(mode.waitForExistence(timeout: 5))
        app.tabBars.buttons["Saved"].tap()
        let library = app.buttons["sessionLibraryOptions"]
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        XCTAssertLessThan(library.frame.midX, app.frame.midX)
        XCTAssertFalse(listening.exists)
        library.tap()
        XCTAssertTrue(app.buttons["recentlyDeletedLink"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testListenHeaderActionsPreservePauseResumeAndSessionDecision() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-reader", "--ui-test-session-flow", "--ui-test-communication", "--ui-test-conversation", "--ui-test-live-translation", "--ui-test-labels"]
        app.launch()
        let mode = app.segmentedControls["communicationMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 20))
        XCTAssertTrue(mode.buttons["Talk"].exists)
        XCTAssertTrue(mode.buttons["Train"].exists)
        mode.buttons["Listen"].tap()
        let primary = app.buttons["primaryCaptionAction"]
        XCTAssertTrue(primary.waitForExistence(timeout: 5))
        XCTAssertLessThan(primary.frame.midY, mode.frame.midY)
        let headerSize = primary.frame.size
        let fullScreen = app.buttons["fullScreenButton"]
        let anchor = fullScreen.frame.midY
        primary.tap()
        let pause = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Pause'"), object: primary)
        XCTAssertEqual(XCTWaiter.wait(for: [pause], timeout: 10), .completed)
        XCTAssertFalse(mode.buttons["Train"].isEnabled)
        let stop = app.buttons["stopCaptionAction"]
        XCTAssertTrue(stop.isHittable)
        XCTAssertEqual(stop.frame.width, headerSize.width, accuracy: 1)
        XCTAssertEqual(stop.frame.height, headerSize.height, accuracy: 1)
        XCTAssertLessThan(stop.frame.midY, mode.frame.midY)
        primary.tap()
        let resume = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Resume'"), object: primary)
        XCTAssertEqual(XCTWaiter.wait(for: [resume], timeout: 10), .completed)
        XCTAssertTrue(stop.isHittable)
        primary.tap()
        let recording = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Pause'"), object: primary)
        XCTAssertEqual(XCTWaiter.wait(for: [recording], timeout: 10), .completed)
        stop.tap()
        XCTAssertTrue(app.buttons["saveSessionButton"].waitForExistence(timeout: 15))
        XCTAssertFalse(stop.exists)
        XCTAssertEqual(primary.label, "New Session")
        XCTAssertEqual(fullScreen.frame.midY, anchor, accuracy: 2)
        primary.tap()
        XCTAssertTrue(app.buttons["Save and new session"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Discard and new session"].exists)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["saveSessionButton"].isHittable)
        XCTAssertTrue(app.buttons["discardSessionButton"].isHittable)
    }

    @MainActor
    func testCommunicationHomeTablet() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("Tablet layout") }
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-communication", "--ui-test-conversation", "--ui-test-live-translation", "--ui-test-labels"]
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launch()
        let mode = app.segmentedControls["communicationMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["conversationSpanishTurn"].isHittable)
        XCTAssertTrue(app.buttons["conversationEnglishTurn"].isHittable)
        XCTAssertTrue(app.buttons["conversationWriteReply"].isHittable)
        let home = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); home.name = "Communication-iPad"; home.lifetime = .keepAlways; add(home)
        mode.buttons["Listen"].tap()
        XCTAssertTrue(app.buttons["primaryCaptionAction"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Saved"].tap()
        XCTAssertTrue(app.staticTexts["Review sample"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCommunicationMeetingCaptureOwnsMicrophone() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-reader", "--ui-test-session-flow", "--ui-test-communication", "--ui-test-conversation", "--ui-test-live-translation", "--ui-test-labels"]
        app.launch()
        let mode = app.segmentedControls["communicationMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 20))
        mode.buttons["Listen"].tap()
        let capture = app.buttons["primaryCaptionAction"]
        XCTAssertTrue(capture.waitForExistence(timeout: 5))
        let ready = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); ready.name = "Aligned-Listen-ready"; ready.lifetime = .keepAlways; add(ready)
        capture.tap()
        let active = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Pause"), object: capture)
        XCTAssertEqual(XCTWaiter.wait(for: [active], timeout: 10), .completed)
        XCTAssertFalse(mode.buttons["Talk"].isEnabled)
        XCTAssertFalse(trainingEntry(in: app).isEnabled, "Changing modules must stay disabled during capture")
        app.tabBars.buttons["Settings"].tap()
        XCTAssertFalse(app.buttons["homeExperiencePicker"].isEnabled)
        app.tabBars.buttons["Home"].tap()
        XCTAssertEqual(capture.label, "Pause")
        capture.tap()
        let idle = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: mode.buttons["Talk"])
        XCTAssertEqual(XCTWaiter.wait(for: [idle], timeout: 10), .completed)
        mode.buttons["Talk"].tap()
        XCTAssertTrue(app.buttons["conversationSpanishTurn"].waitForExistence(timeout: 5))
        mode.buttons["Listen"].tap()
        XCTAssertEqual(capture.label, "Resume")
    }

    @MainActor
    func testCommunicationHomeTwoWayAndWrittenReply() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-communication", "--ui-test-conversation", "--ui-test-live-translation", "--ui-test-labels"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        XCTAssertTrue(app.segmentedControls["communicationMode"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.buttons["speakTranslateEntry"].exists)
        XCTAssertEqual(app.buttons["conversationSpanishTurn"].label, "Hablar en español")
        XCTAssertTrue(app.buttons["conversationEnglishTurn"].isHittable)
        let home = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); home.name = "Communication-home"; home.lifetime = .keepAlways; add(home)
        app.buttons["conversationEnglishTurn"].tap()
        XCTAssertTrue(app.staticTexts["Listening"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.segmentedControls["communicationMode"].buttons["Listen"].isEnabled)
        app.buttons["conversationEnglishTurn"].tap()
        playConversationTranslation(app, timeout: 8)
        app.buttons["conversationTranslationPlayback"].tap()
        let reply = app.buttons["conversationWriteReply"]
        if !reply.isHittable { app.swipeUp() }
        reply.tap()
        let input = app.textViews["conversationSource"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.typeText("Gracias")
        app.buttons["conversationApply"].tap()
        playConversationTranslation(app, timeout: 8)
        app.buttons["conversationTranslationPlayback"].tap()
        XCTAssertTrue((app.buttons["conversationTranslationPlayback"].value as? String ?? "").contains("English"), "My written reply must use my language, not the previous speaker's direction")
        XCTAssertEqual(app.staticTexts["conversationSourceText"].label, "Gracias")
        let written = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); written.name = "Communication-written-reply"; written.lifetime = .keepAlways; add(written)
        app.tabBars.buttons["Saved"].tap()
        XCTAssertTrue(app.staticTexts["Review sample"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["savedLanguagePractice"].exists)
        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(trainingEntry(in: app).exists)
    }

    @MainActor
    func testCommunicationAlignedModesAndAlwaysTranslation() throws {
        let app = XCUIApplication()
        // The review fixture writes the obsolete translation preference as false.
        app.launchArguments = ["--ui-test-review", "--ui-test-communication", "--ui-test-conversation", "--ui-test-live-translation", "--ui-test-labels"]
        app.launch()
        let mode = app.segmentedControls["communicationMode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 20))
        XCTAssertFalse(app.switches["conversationTranslationToggle"].exists)
        XCTAssertTrue(app.buttons["conversationSecondLanguage"].exists)
        let modeFrame = mode.frame
        let sourceFrame = app.buttons["conversationFirstLanguage"].frame
        let targetFrame = app.buttons["conversationSecondLanguage"].frame
        let initial = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); initial.name = "Aligned-Converse"; initial.lifetime = .keepAlways; add(initial)
        mode.buttons["Listen"].tap()
        let source = app.buttons["captureLanguagePicker"]
        XCTAssertTrue(source.waitForExistence(timeout: 5))
        XCTAssertEqual(mode.frame.minY, modeFrame.minY, accuracy: 2)
        XCTAssertEqual(source.frame.minY, sourceFrame.minY, accuracy: 2)
        XCTAssertEqual(source.frame.minX, sourceFrame.minX, accuracy: 2)
        XCTAssertEqual(app.buttons["translationTargetPicker"].frame.minX, targetFrame.minX, accuracy: 2)
        XCTAssertTrue(app.buttons["primaryCaptionAction"].isHittable)
        let listenShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); listenShot.name = "Aligned-Listen"; listenShot.lifetime = .keepAlways; add(listenShot)
        app.buttons["sessionActionsButton"].tap()
        app.buttons["Reading language"].tap()
        XCTAssertTrue(app.buttons["Both"].waitForExistence(timeout: 5))
        app.buttons["Both"].tap()
        mode.buttons["Talk"].tap()
        if UIDevice.current.userInterfaceIdiom == .phone {
            XCUIDevice.shared.orientation = .landscapeLeft
            let rotated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.frame.width > app.frame.height }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [rotated], timeout: 5), .completed)
            let landscapeSource = app.buttons["conversationFirstLanguage"].frame
            let wide = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); wide.name = "Aligned-Converse-landscape"; wide.lifetime = .keepAlways; add(wide)
            mode.buttons["Listen"].tap()
            XCTAssertEqual(app.buttons["captureLanguagePicker"].frame.minY, landscapeSource.minY, accuracy: 2)
            let listeningWide = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); listeningWide.name = "Aligned-Listen-landscape"; listeningWide.lifetime = .keepAlways; add(listeningWide)
            mode.buttons["Talk"].tap()
            XCUIDevice.shared.orientation = .portrait
            let upright = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.frame.height > app.frame.width }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [upright], timeout: 5), .completed)
        }
        app.buttons["conversationSpanishTurn"].tap()
        XCTAssertTrue(app.staticTexts["Listening"].waitForExistence(timeout: 8))
        app.buttons["conversationSpanishTurn"].tap()
        playConversationTranslation(app, timeout: 8)
        XCTAssertTrue(app.staticTexts["conversationTranslation"].exists)
        XCTAssertFalse(app.buttons["conversationCorrect"].exists)
        app.buttons["conversationTranslationPlayback"].tap()
        app.tabBars.buttons["Settings"].tap()
        app.buttons["homeExperiencePicker"].tap()
        app.buttons["Previous home"].tap()
        app.tabBars.buttons["Captions"].tap()
        XCTAssertTrue(app.buttons["speakTranslateEntry"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Sessions"].tap()
        XCTAssertTrue(app.staticTexts["Review sample"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Settings"].tap()
        app.buttons["homeExperiencePicker"].tap()
        app.buttons["Conversation first"].tap()
        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(app.buttons["conversationEnglishTurn"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.switches["conversationTranslationToggle"].exists)
    }

    @MainActor
    func testCommunicationHomeSpanishLargeText() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-communication", "--ui-test-conversation", "--ui-test-live-translation", "--ui-test-labels", "-interfaceLanguage", "es", "-appearance", "dark", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        XCTAssertTrue(app.segmentedControls["communicationMode"].waitForExistence(timeout: 20))
        for id in ["conversationSpanishTurn", "conversationEnglishTurn"] {
            let button = app.buttons[id]
            if !button.isHittable { app.swipeUp() }
            XCTAssertTrue(button.isHittable)
            XCTAssertGreaterThanOrEqual(button.frame.minX, app.frame.minX)
            XCTAssertLessThanOrEqual(button.frame.maxX, app.frame.maxX)
            XCTAssertLessThan(button.frame.height, app.frame.height * 0.5, "A single action must not consume the reading screen")
        }
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = "Communication-Spanish-large"; shot.lifetime = .keepAlways; add(shot)
        XCUIDevice.shared.orientation = .landscapeLeft
        let wide = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); wide.name = "Communication-Spanish-landscape"; wide.lifetime = .keepAlways; add(wide)
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testLibrarySavedFirstDraftsSeparateAndKoreanPlayback() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-library"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Sessions"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Sessions"].tap()
        XCTAssertTrue(app.staticTexts["Review sample"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["French and Korean"].exists)
        XCTAssertFalse(app.staticTexts["Unfinished draft example"].exists)
        XCTAssertFalse(app.staticTexts["Deleted example"].exists)
        let main = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); main.name = "Library-saved-first"; main.lifetime = .keepAlways; add(main)
        if app.buttons["reviewDraftsLink"].exists {
            app.buttons["reviewDraftsLink"].tap()
            XCTAssertTrue(app.staticTexts["Unfinished draft example"].waitForExistence(timeout: 5))
            XCTAssertFalse(app.staticTexts["Review sample"].exists)
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        app.staticTexts["French and Korean"].tap()
        app.buttons["Audio & subtitles"].tap()
        XCTAssertTrue(app.buttons["playbackTextMenu"].waitForExistence(timeout: 5))
        // SwiftUI Menu on iOS 17 exposes an invalid AX activation point inside a sheet.
        // Use its visible center, as in the existing playback tests, then verify the real selection.
        app.buttons["playbackTextMenu"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["Both"].tap()
        XCTAssertTrue(app.staticTexts["Bonjour. Nous apprenons ensemble."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["안녕하세요. 우리는 함께 배웁니다."].exists)
        let bilingual = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); bilingual.name = "French-Korean-playback"; bilingual.lifetime = .keepAlways; add(bilingual)
        app.terminate()
    }

    @MainActor
    func testPlaybackVoiceSettingsOffersSampleWithoutStartingMicrophone() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-communication", "--ui-test-conversation", "--ui-test-live-translation", "--ui-test-labels"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Settings"].tap()
        let link = app.buttons["playbackVoiceSettingsLink"]
        for _ in 0..<3 where !link.isHittable { app.swipeUp() }
        XCTAssertTrue(link.isHittable); link.tap()
        XCTAssertTrue(app.buttons["playbackVoiceLanguage"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["playbackVoicePicker"].exists)
        XCTAssertFalse(app.alerts.firstMatch.exists, "Opening voices must not request microphone permission")
        let sample = app.buttons["playbackVoiceSample"]
        if sample.isEnabled {
            sample.tap()
            XCTAssertFalse(app.alerts.firstMatch.exists)
        }
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(app.staticTexts["conversationStatus"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["conversationStatus"].label, "Ready")
    }

    @MainActor
    func testConversationActionNamesFollowSettingAndKeepAccessibleTitles() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-conversation"]
        app.launch()
        let entry = app.buttons["speakTranslateEntry"]
        XCTAssertTrue(entry.waitForExistence(timeout: 20)); entry.tap()
        let write = app.buttons["conversationWriteReply"]
        XCTAssertTrue(write.waitForExistence(timeout: 5))
        XCTAssertFalse(write.staticTexts["visibleControlName"].exists)
        XCTAssertEqual(write.label, "Write a reply")
        XCTAssertEqual(app.buttons["newConversationButton"].label, "New conversation")
        XCTAssertTrue(app.buttons["conversationSpanishTurn"].exists)
        app.navigationBars["Conversation"].buttons["Done"].tap()
        app.tabBars.buttons["Settings"].tap()
        tapPreferenceSwitch(app.switches["buttonNamesToggle"])
        app.tabBars.buttons["Home"].tap(); entry.tap()
        XCTAssertTrue(write.staticTexts["visibleControlName"].waitForExistence(timeout: 5))
        app.navigationBars["Conversation"].buttons["Done"].tap()
        app.tabBars.buttons["Settings"].tap()
        tapPreferenceSwitch(app.switches["buttonNamesToggle"])
        app.tabBars.buttons["Home"].tap(); entry.tap()
        XCTAssertTrue(write.waitForExistence(timeout: 5))
        XCTAssertFalse(write.staticTexts["visibleControlName"].exists)
        XCTAssertEqual(write.label, "Write a reply")
    }

    @MainActor
    func testConversationFixedBarKeepsActionsVisibleWhileScrollingLongText() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-communication", "--ui-test-conversation", "--ui-test-live-translation", "--ui-test-labels"]
        app.launch()
        let write = app.buttons["conversationWriteReply"]
        let new = app.buttons["newConversationButton"]
        let train = trainingEntry(in: app)
        let status = app.staticTexts["conversationStatus"]
        XCTAssertTrue(write.waitForExistence(timeout: 20))
        XCTAssertEqual(status.label, "Ready")
        XCTAssertGreaterThan(write.frame.midX, app.frame.midX)
        XCTAssertLessThan(status.frame.midX, write.frame.midX)
        XCTAssertTrue(write.isHittable); XCTAssertTrue(new.isHittable); XCTAssertTrue(train.isHittable)
        write.tap()
        let input = app.textViews["conversationSource"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        let longText = (1...16).map { "Paragraph \($0). We keep the conversation actions visible while reading." }.joined(separator: "\n")
        input.tap(); input.typeText(longText)
        app.buttons["conversationApply"].tap()
        playConversationTranslation(app, timeout: 10)
        XCTAssertEqual(status.label, "Playing")
        XCTAssertFalse(write.isEnabled); XCTAssertFalse(new.isEnabled); XCTAssertFalse(train.isEnabled)
        app.buttons["conversationTranslationPlayback"].tap()
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'Ready'"), object: status)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
        let reader = app.scrollViews["conversationReadingArea"]
        XCTAssertTrue(reader.exists)
        let originalY = new.frame.midY
        XCTAssertLessThan(new.frame.maxY, reader.frame.minY + 2)
        XCTAssertFalse(reader.buttons["newConversationButton"].exists)
        for _ in 0..<3 { reader.swipeUp() }
        XCTAssertEqual(new.frame.midY, originalY, accuracy: 2)
        XCTAssertTrue(write.isHittable); XCTAssertTrue(new.isHittable); XCTAssertTrue(train.isHittable)
        new.tap()
        XCTAssertTrue(app.buttons["confirmNewConversation"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertEqual(app.staticTexts["conversationSourceText"].label, longText)
        new.tap(); app.buttons["confirmNewConversation"].tap()
        XCTAssertFalse(app.staticTexts["conversationSourceText"].exists)
        XCTAssertEqual(status.label, "Ready")
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "Conversation-fixed-action-bar"; shot.lifetime = .keepAlways; add(shot)
    }

    @MainActor
    func testConversationFullScreenKeepsControlsAndRestoresHome() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-conversation", "--ui-test-live-translation"]
        app.launch()
        XCTAssertTrue(app.buttons["speakTranslateEntry"].waitForExistence(timeout: 20))
        app.buttons["speakTranslateEntry"].tap()
        let expand = app.buttons["conversationFullScreenButton"]
        XCTAssertTrue(expand.waitForExistence(timeout: 5))
        XCTAssertEqual(expand.label, "Full screen")
        expand.tap()
        let exit = app.buttons["conversationFullScreenButton"]
        XCTAssertTrue(exit.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["conversationWriteReply"].isHittable)
        XCTAssertTrue(app.buttons["newConversationButton"].isHittable)
        XCTAssertTrue(trainingEntry(in: app).isHittable)
        XCTAssertFalse(app.segmentedControls["communicationMode"].exists)
        XCTAssertTrue(app.buttons["conversationSpanishTurn"].exists)
        XCTAssertTrue(app.buttons["conversationEnglishTurn"].exists)
        app.buttons["conversationOptions"].tap()
        XCTAssertTrue(app.sliders.firstMatch.waitForExistence(timeout: 5))
        app.navigationBars["Reading options"].buttons["Done"].tap()
        exit.tap()
        XCTAssertTrue(app.buttons["conversationFirstLanguage"].waitForExistence(timeout: 5))
        XCTAssertEqual(exit.label, "Full screen")
    }

    @MainActor
    func testJapaneseAndChineseConversationSelectors() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-conversation", "--ui-test-live-translation"]
        app.launch()
        XCTAssertTrue(app.buttons["speakTranslateEntry"].waitForExistence(timeout: 20))
        app.buttons["speakTranslateEntry"].tap()
        app.buttons["conversationFirstLanguage"].tap()
        app.buttons["Japanese · 日本語"].tap()
        app.buttons["conversationSecondLanguage"].tap()
        app.buttons["Mandarin · 简体中文"].tap()
        XCTAssertTrue(app.buttons["conversationTurn-ja"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["conversationTurn-zh-Hans"].exists)
        app.terminate()
    }

    @MainActor
    func testConversationFrenchAndKoreanPairAndColors() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-conversation", "--ui-test-live-translation"]
        app.launch()
        XCTAssertTrue(app.buttons["speakTranslateEntry"].waitForExistence(timeout: 20))
        app.buttons["speakTranslateEntry"].tap()
        app.buttons["conversationFirstLanguage"].tap(); app.buttons["French · Français"].tap()
        app.buttons["conversationSecondLanguage"].tap(); app.buttons["Korean · 한국어"].tap()
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: app.buttons["conversationTurn-fr"])
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
        XCTAssertTrue(app.buttons["conversationTurn-ko"].isHittable)
        XCTAssertEqual(app.buttons["conversationTurn-fr"].frame.minY, app.buttons["conversationTurn-ko"].frame.minY, accuracy: 1)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = "Conversation-French-Korean"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["conversationTurn-fr"].tap()
        XCTAssertTrue(app.staticTexts["Listening"].waitForExistence(timeout: 10))
        app.buttons["conversationTurn-fr"].tap()
        playConversationTranslation(app, timeout: 10)
        app.buttons["conversationTranslationPlayback"].tap()
        XCTAssertTrue((app.buttons["conversationTranslationPlayback"].value as? String ?? "").contains("한국어"))
        app.terminate()
    }

    @MainActor
    func testTabletLibrarySidebarCategories() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("Sidebar requires iPad") }
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-library"]
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Sessions"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Sessions"].tap()
        XCTAssertTrue(app.staticTexts["French and Korean"].waitForExistence(timeout: 5))
        app.staticTexts["Recovery drafts (1)"].tap()
        XCTAssertTrue(app.staticTexts["Unfinished draft example"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["French and Korean"].exists)
        app.staticTexts["Saved sessions"].tap()
        XCTAssertTrue(app.staticTexts["French and Korean"].waitForExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = "Library-iPad-sidebar"; shot.lifetime = .keepAlways; add(shot)
        app.terminate()
    }

    /// SwiftUI exposes the whole Form row as a switch. Target the trailing thumb,
    /// inside its inset, rather than the label or the row's outer margin.
    @MainActor
    private func tapPreferenceSwitch(_ control: XCUIElement) {
        control.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: control.frame.width - 40, dy: control.frame.height / 2)).tap()
    }

    @MainActor
    func testHomeButtonNamesToggleAndRotate() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-reader", "--ui-test-live-translation"]
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Settings"].tap()
        XCTAssertFalse(app.buttons["speakTranslateEntry"].exists)
        XCTAssertFalse(app.buttons["Write and speak"].exists)
        tapPreferenceSwitch(app.switches["buttonNamesToggle"])
        XCTAssertEqual(app.switches["buttonNamesToggle"].value as? String, "1")
        app.tabBars.buttons["Captions"].tap()
        for name in ["Live caption display", "Conversation", "Reading options", "Session actions"] {
            XCTAssertTrue(app.staticTexts["controlName-" + name].exists, name)
        }
        for id in ["liveSpanishButton", "speakTranslateEntry", "fullScreenButton", "readingOptionsButton", "sessionActionsButton"] {
            XCTAssertTrue(app.buttons[id].isHittable, id)
        }
        let portrait = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        portrait.name = "Home-names-portrait"; portrait.lifetime = .keepAlways; add(portrait)
        XCUIDevice.shared.orientation = .landscapeLeft
        let rotated = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: app.buttons["readingOptionsButton"])
        XCTAssertEqual(XCTWaiter.wait(for: [rotated], timeout: 5), .completed)
        XCTAssertTrue(app.buttons["primaryCaptionAction"].isHittable)
        let landscape = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        landscape.name = "Home-names-landscape"; landscape.lifetime = .keepAlways; add(landscape)
        app.buttons["fullScreenButton"].tap()
        XCTAssertEqual(app.buttons["fullScreenButton"].label, "Exit full screen")
        XCTAssertTrue(app.buttons["sessionActionsButton"].isHittable)
        XCTAssertTrue(app.buttons["primaryCaptionAction"].isHittable)
        app.buttons["fullScreenButton"].tap()
        XCUIDevice.shared.orientation = .portrait
        app.buttons["sessionActionsButton"].tap()
        app.buttons["Write and speak"].tap()
        XCTAssertTrue(app.textViews["writtenResponseText"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Write what you want to say. The voice reads exactly this text in the language you choose; it does not translate it."].exists)
        app.buttons["Done"].tap()
        app.tabBars.buttons["Settings"].tap()
        tapPreferenceSwitch(app.switches["buttonNamesToggle"])
        app.tabBars.buttons["Captions"].tap()
        XCTAssertFalse(app.staticTexts["controlName-Reading options"].exists)
        XCTAssertEqual(app.buttons["readingOptionsButton"].frame.width, 44, accuracy: 1)
    }

    @MainActor
    func testSimpleHomeUniformActionsWithEitherNamePreference() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-reader"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Settings"].tap()
        tapPreferenceSwitch(app.switches["simpleModeToggle"])
        XCTAssertEqual(app.switches["simpleModeToggle"].value as? String, "1")
        app.tabBars.buttons["Home"].tap()
        let ids = ["speakTranslateEntry", "simpleListenNow", "simpleSessions", "simpleEnglishTraining", "simpleWriteResponse", "simplePreparation"]
        for id in ids {
            let button = app.buttons[id]
            XCTAssertTrue(button.exists, id)
            XCTAssertEqual(button.frame.width, app.buttons["simpleListenNow"].frame.width, accuracy: 1)
            XCTAssertEqual(button.frame.height, app.buttons["simpleListenNow"].frame.height, accuracy: 1)
        }
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "Home-simple-uniform"; shot.lifetime = .keepAlways; add(shot)
        app.tabBars.buttons["Settings"].tap()
        tapPreferenceSwitch(app.switches["buttonNamesToggle"])
        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(app.buttons["simpleWriteResponse"].label.contains("Write and speak"))
        for id in ids { XCTAssertEqual(app.buttons[id].frame.height, app.buttons["simpleListenNow"].frame.height, accuracy: 1) }
        app.buttons["simpleListenNow"].tap()
        XCTAssertTrue(app.buttons["sessionActionsButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["readerHomeButton"].exists)
        let readerShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        readerShot.name = "Simple-reader-navigation"; readerShot.lifetime = .keepAlways; add(readerShot)
        app.buttons["sessionActionsButton"].tap()
        XCTAssertTrue(app.buttons["Reading options"].waitForExistence(timeout: 5))
        app.buttons["Reading options"].tap()
        let close = app.navigationBars["Reading options"].buttons["Done"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(close.frame.midX, app.frame.midX)
        close.tap()
        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(app.buttons["simpleListenNow"].exists)
    }

    @MainActor
    func testSimpleReaderNamesAndHomeTabReturn() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-reader", "--ui-test-live-translation", "--ui-test-session-flow"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Settings"].tap()
        tapPreferenceSwitch(app.switches["simpleModeToggle"])
        app.tabBars.buttons["Home"].tap()
        app.buttons["simpleListenNow"].tap()
        let actions = app.buttons["sessionActionsButton"]
        XCTAssertTrue(actions.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["readerHomeButton"].exists)
        XCTAssertFalse(actions.staticTexts["visibleControlName"].exists)
        XCTAssertEqual(actions.label, "Session actions")
        let hidden = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        hidden.name = "Simple-reader-icons"; hidden.lifetime = .keepAlways; add(hidden)
        // Re-selecting the current tab must return Home, not leave the reader stranded.
        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(app.buttons["simpleListenNow"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Settings"].tap()
        tapPreferenceSwitch(app.switches["buttonNamesToggle"])
        app.tabBars.buttons["Home"].tap()
        app.buttons["simpleListenNow"].tap()
        XCTAssertTrue(actions.staticTexts["visibleControlName"].waitForExistence(timeout: 5))
        let named = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        named.name = "Simple-reader-names"; named.lifetime = .keepAlways; add(named)
        app.buttons["captureLanguagePicker"].tap()
        app.buttons["French · Français"].tap()
        XCTAssertTrue((app.buttons["captureLanguagePicker"].value as? String ?? "").contains("Français"))
        app.buttons["translationTargetPicker"].tap()
        app.buttons["Korean · 한국어"].tap()
        XCTAssertTrue((app.buttons["translationTargetPicker"].value as? String ?? "").contains("한국어"))
        app.tabBars.buttons["Settings"].tap()
        tapPreferenceSwitch(app.switches["buttonNamesToggle"])
        app.tabBars.buttons["Home"].tap()
        app.buttons["simpleListenNow"].tap()
        XCTAssertFalse(actions.staticTexts["visibleControlName"].exists)
        app.buttons["primaryCaptionAction"].tap()
        let listening = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Pause"), object: app.buttons["primaryCaptionAction"])
        XCTAssertEqual(XCTWaiter.wait(for: [listening], timeout: 10), .completed)
        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(app.buttons["simpleListenNow"].waitForExistence(timeout: 5))
        app.buttons["simpleListenNow"].tap()
        XCTAssertEqual(app.buttons["primaryCaptionAction"].label, "Pause")
        let count = Int((app.scrollViews["captionScrollView"].value as? String ?? "0").split(separator: " ").first ?? "0") ?? 0
        XCTAssertGreaterThanOrEqual(count, 8)
    }

    @MainActor
    func testPlaybackNamesIndependentOfSimpleMode() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-media", "--ui-test-translation", "--ui-test-simple"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Sessions"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Sessions"].tap()
        app.staticTexts["Review sample"].tap()
        app.buttons["sessionMediaButton"].tap()
        let play = app.buttons["recordingPlayButton"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        XCTAssertEqual(play.label, "Play")
        XCTAssertFalse(play.staticTexts["visibleControlName"].exists)
        app.buttons["playbackOptionsButton"].tap()
        tapPreferenceSwitch(app.switches["Show button names"])
        app.navigationBars["Playback options"].buttons["Done"].tap()
        XCTAssertTrue(play.staticTexts["visibleControlName"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["playbackOptionsButton"].staticTexts["visibleControlName"].exists)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "Playback-shared-names"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["playbackOptionsButton"].tap()
        tapPreferenceSwitch(app.switches["Show button names"])
        app.navigationBars["Playback options"].buttons["Done"].tap()
        XCTAssertFalse(play.staticTexts["visibleControlName"].exists)
        XCTAssertEqual(app.buttons["playbackOptionsButton"].label, "Playback options")
    }

    @MainActor
    func testSimpleHomeDarkSpanishAndLargeText() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-simple", "--ui-test-labels",
            "-appearance", "dark", "-interfaceLanguage", "es",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        XCTAssertTrue(app.buttons["simpleListenNow"].waitForExistence(timeout: 20))
        let home = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        home.name = "Home-dark-Spanish-large"; home.lifetime = .keepAlways; add(home)
        app.buttons["simpleListenNow"].tap()
        XCTAssertTrue(app.buttons["sessionActionsButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["readerHomeButton"].exists)
        XCTAssertTrue(app.buttons["sessionActionsButton"].isHittable)
        XCTAssertLessThanOrEqual(app.buttons["sessionActionsButton"].frame.maxX, app.frame.maxX)
        let reader = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        reader.name = "Reader-dark-Spanish-large"; reader.lifetime = .keepAlways; add(reader)
        app.tabBars.buttons["Inicio"].tap()
        XCTAssertTrue(app.buttons["simpleListenNow"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLanguageColorSettingsAndConversationLight() throws { try checkLanguageColors(dark: false) }
    @MainActor
    func testLanguageColorSettingsAndConversationDark() throws { try checkLanguageColors(dark: true) }

    @MainActor
    private func checkLanguageColors(dark: Bool) throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-live-translation", "--ui-test-conversation", "-appearance", dark ? "dark" : "light"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Settings"].tap()
        let link = app.buttons["languageColorsLink"]
        for _ in 0..<6 { if link.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(link.isHittable); link.tap()
        app.buttons["spanishColorPicker"].tap(); app.buttons["Purple"].tap()
        app.buttons["englishColorPicker"].tap(); app.buttons["Orange"].tap()
        XCTAssertTrue(app.staticTexts["spanishColorPreview"].exists)
        let preview = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        preview.name = dark ? "Language-colors-dark" : "Language-colors-light"; preview.lifetime = .keepAlways; add(preview)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        if !link.isHittable { app.swipeDown() }
        link.tap()
        XCTAssertEqual(app.buttons["spanishColorPicker"].value as? String, "Purple")
        XCTAssertEqual(app.buttons["englishColorPicker"].value as? String, "Orange")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.tabBars.buttons["Captions"].tap()
        app.buttons["speakTranslateEntry"].tap()
        let spanish = app.buttons["conversationSpanishTurn"]
        spanish.tap()
        expectation(for: NSPredicate(format: "label == %@", "Listening"), evaluatedWith: app.staticTexts["conversationStatus"])
        waitForExpectations(timeout: 8)
        spanish.tap()
        playConversationTranslation(app, timeout: 8)
        app.buttons["conversationTranslationPlayback"].tap()
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = dark ? "Language-conversation-dark" : "Language-conversation-light"; shot.lifetime = .keepAlways; add(shot)
        app.navigationBars["Conversation"].buttons["Done"].tap()
        app.tabBars.buttons["Settings"].tap()
        if !link.isHittable { app.swipeDown() }
        link.tap()
        let restore = app.buttons["restoreLanguageColors"]
        if !restore.isHittable { app.swipeUp() }
        restore.tap()
        XCTAssertEqual(app.buttons["spanishColorPicker"].value as? String, "Green")
        XCTAssertEqual(app.buttons["englishColorPicker"].value as? String, "Blue")
    }

    @MainActor
    func testConversationTwoTapTurnsInBothDirections() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-live-translation", "--ui-test-conversation"]
        app.launch()
        let entry = app.buttons["speakTranslateEntry"]
        XCTAssertTrue(entry.waitForExistence(timeout: 20)); entry.tap()
        let spanish = app.buttons["conversationSpanishTurn"]
        let english = app.buttons["conversationEnglishTurn"]
        XCTAssertTrue(spanish.waitForExistence(timeout: 8))
        XCTAssertTrue(english.isHittable)
        XCTAssertLessThan(spanish.frame.midX, english.frame.midX)
        XCTAssertEqual(spanish.frame.midY, english.frame.midY, accuracy: 2)
        XCTAssertFalse(app.buttons["conversationType"].exists)
        spanish.tap()
        let status = app.staticTexts["conversationStatus"]
        expectation(for: NSPredicate(format: "label == %@", "Listening"), evaluatedWith: status)
        waitForExpectations(timeout: 8)
        XCTAssertFalse(english.isEnabled)
        spanish.tap()
        playConversationTranslation(app, timeout: 8)
        expectation(for: NSPredicate(format: "label == %@", "Playing"), evaluatedWith: status)
        waitForExpectations(timeout: 8)
        XCTAssertTrue(app.staticTexts["conversationTranslation"].label.contains("Test translation"))
        XCTAssertFalse(english.isEnabled)
        app.buttons["conversationTranslationPlayback"].tap()
        XCTAssertTrue(app.staticTexts["conversationTranslation"].exists)
        english.tap()
        expectation(for: NSPredicate(format: "label == %@", "Listening"), evaluatedWith: status)
        waitForExpectations(timeout: 8)
        english.tap()
        playConversationTranslation(app, timeout: 8)
        expectation(for: NSPredicate(format: "label == %@", "Playing"), evaluatedWith: status)
        waitForExpectations(timeout: 8)
        XCTAssertTrue(app.staticTexts["conversationTranslation"].label.contains("Traducción de prueba"))
        XCTAssertTrue(app.buttons["conversationTranslationPlayback"].exists)
        XCTAssertFalse(app.buttons["conversationCorrect"].exists)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "Two-way-conversation"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["conversationTranslationPlayback"].tap()
        app.buttons["newConversationButton"].tap()
        XCTAssertTrue(app.buttons["confirmNewConversation"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["conversationTranslation"].exists)
        app.buttons["newConversationButton"].tap()
        XCTAssertTrue(app.buttons["confirmNewConversation"].waitForExistence(timeout: 5))
        app.buttons["confirmNewConversation"].tap()
        XCTAssertTrue(spanish.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["conversationSourceText"].exists)
        XCTAssertFalse(app.staticTexts["conversationTranslation"].exists)
        XCTAssertTrue(english.isEnabled)
        app.buttons["newConversationButton"].tap()
        XCTAssertTrue(english.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["confirmNewConversation"].exists)
        app.navigationBars["Conversation"].buttons["Done"].tap()
        entry.tap()
        XCTAssertFalse(app.staticTexts["conversationTranslation"].exists)
        XCTAssertTrue(app.buttons["conversationEnglishTurn"].isEnabled)
    }

    @MainActor
    func testConversationCardsPlayAndStopManuallyWithoutAutoplay() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-communication", "--ui-test-conversation", "--ui-test-live-translation", "--ui-test-labels"]
        app.launch()
        let write = app.buttons["conversationWriteReply"]
        XCTAssertTrue(write.waitForExistence(timeout: 20)); write.tap()
        let input = app.textViews["conversationSource"]
        XCTAssertTrue(input.waitForExistence(timeout: 5)); input.typeText("Hola, buenos días.")
        app.buttons["conversationApply"].tap()
        let original = app.buttons["conversationOriginalPlayback"]
        let translated = app.buttons["conversationTranslationPlayback"]
        XCTAssertTrue(translated.waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["conversationStatus"].label, "Ready")
        XCTAssertEqual(original.label, "Play original"); XCTAssertEqual(translated.label, "Play translation")
        XCTAssertEqual(original.value as? String, "Español"); XCTAssertEqual(translated.value as? String, "English")
        XCTAssertFalse(app.buttons["conversationPlay"].exists); XCTAssertFalse(app.buttons["conversationStopAudio"].exists)
        original.tap()
        XCTAssertEqual(original.label, "Stop original"); XCTAssertEqual(translated.label, "Play translation")
        XCTAssertEqual(app.staticTexts["conversationStatus"].label, "Playing")
        XCTAssertFalse(write.isEnabled)
        translated.tap()
        XCTAssertEqual(original.label, "Play original"); XCTAssertEqual(translated.label, "Stop translation")
        XCTAssertFalse(app.staticTexts["Listening now"].exists)
        translated.tap()
        XCTAssertEqual(original.label, "Play original"); XCTAssertEqual(translated.label, "Play translation")
        XCTAssertEqual(app.staticTexts["conversationStatus"].label, "Ready")
        XCTAssertTrue(write.isEnabled)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "Conversation-manual-card-audio"; shot.lifetime = .keepAlways; add(shot)
    }

    @MainActor
    func testConversationWrittenReplyCancelAndAutomaticOptions() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-live-translation", "--ui-test-conversation"]
        app.launch()
        XCTAssertTrue(app.buttons["speakTranslateEntry"].waitForExistence(timeout: 20))
        app.buttons["speakTranslateEntry"].tap()
        let english = app.buttons["conversationEnglishTurn"]
        english.tap()
        expectation(for: NSPredicate(format: "label == %@", "Listening"), evaluatedWith: app.staticTexts["conversationStatus"])
        waitForExpectations(timeout: 8)
        english.tap()
        playConversationTranslation(app, timeout: 8)
        let input = app.textViews["conversationSource"]
        app.buttons["conversationTranslationPlayback"].tap()
        let original = app.staticTexts["conversationSourceText"]
        XCTAssertEqual(original.label, "Would you like cold water?")
        XCTAssertFalse(app.buttons["conversationCorrect"].exists)
        let reply = app.buttons["conversationWriteReply"]
        if !reply.isHittable { app.swipeUp() }
        reply.tap()
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap(); input.typeText(" Discard this.")
        app.navigationBars.buttons["Cancel"].tap()
        XCTAssertEqual(original.label, "Would you like cold water?")
        app.buttons["conversationOptions"].tap()
        let modes = app.segmentedControls["conversationMode"]
        XCTAssertTrue(modes.buttons["By button"].isSelected)
        modes.buttons["Automatic"].tap()
        app.navigationBars["Reading options"].buttons["Done"].tap()
        app.navigationBars["Conversation"].buttons["Done"].tap()
        app.buttons["speakTranslateEntry"].tap()
        app.buttons["conversationOptions"].tap()
        XCTAssertTrue(modes.buttons["Automatic"].isSelected)
        app.navigationBars["Reading options"].buttons["Done"].tap()
        XCTAssertFalse(app.staticTexts["conversationTranslation"].exists)
    }

    @MainActor
    func testStoreScreenshotsAndPrivacyEnglish() throws { try captureStoreScreenshots(spanish: false) }

    @MainActor
    func testStoreScreenshotsAndPrivacySpanish() throws { try captureStoreScreenshots(spanish: true) }

    /// Capture real screens with fictional text; never depends on a microphone or downloaded models.
    @MainActor
    private func captureStoreScreenshots(spanish: Bool) throws {
        let app = XCUIApplication()
        app.launchArguments = ["--store-screenshots"]
        if spanish { app.launchArguments.append("--store-spanish") }
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        let sessions = app.tabBars.buttons[spanish ? "Sesiones" : "Sessions"]
        XCTAssertTrue(sessions.waitForExistence(timeout: 20))
        sessions.tap()
        let sample = app.staticTexts[spanish ? "Aprendemos juntos" : "Learning together"]
        XCTAssertTrue(sample.waitForExistence(timeout: 5))
        func capture(_ name: String) {
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = "Store-" + (spanish ? "es-ES-" : "en-US-") + name
            attachment.lifetime = .keepAlways
            add(attachment)
            // Keep the screen stable for simctl's native-size capture. XCTest on iOS 17.2
            // rounds iPhone 15 attachments down to 1178 px, while Apple requires 1179 px.
            Thread.sleep(forTimeInterval: 5)
        }
        capture("01-library")
        sample.tap()
        let edit = app.buttons["editTranscriptButton"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["favoriteSessionButton"].exists)
        capture("02-reading")
        edit.tap()
        XCTAssertTrue(app.buttons["editParagraph-1"].waitForExistence(timeout: 5))
        capture("03-review")
        // Relaunch removes the editor sheet; the isolated library is recreated, not the user's data.
        app.terminate(); app.launch()
        let settings = app.tabBars.buttons[spanish ? "Ajustes" : "Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 15)); settings.tap()
        let privacy = app.staticTexts[spanish ? "Política de privacidad" : "Privacy Policy"]
        for _ in 0..<8 {
            if privacy.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(privacy.isHittable); privacy.tap()
        XCTAssertTrue(app.descendants(matching: .any)["publicPrivacyLink"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["publicSupportLink"].firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any)["privacyContactLink"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts[spanish ? "Responsable: Dario Fernando Meneses Ceron." : "Responsible person: Dario Fernando Meneses Ceron."].exists)
        capture("04-privacy-qa")
        app.terminate()
    }

    @MainActor
    func testSimpleHomeWrittenResponseAndGuide() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-simple", "--ui-test-labels"]
        app.launch()
        XCTAssertTrue(app.buttons["simpleListenNow"].waitForExistence(timeout: 20))
        app.buttons["Write and speak"].tap()
        let editor = app.textViews["writtenResponseText"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap(); editor.typeText("Please speak slowly. I am reading your words. Thank you for waiting while I write my response.")
        app.buttons["speakWrittenResponse"].tap()
        XCTAssertEqual(app.buttons["speakWrittenResponse"].label, "Pause")
        app.buttons["speakWrittenResponse"].tap()
        XCTAssertEqual(app.buttons["speakWrittenResponse"].label, "Resume")
        app.buttons["Stop"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Write and speak"].tap()
        XCTAssertEqual(app.textViews["writtenResponseText"].value as? String, "")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Prepare VoiceToRead"].tap()
        app.buttons["See a short demonstration"].tap()
        XCTAssertTrue(app.staticTexts["Demonstration · no recording"].waitForExistence(timeout: 5))
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["Step 2 of 4"].exists)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = "Accessible-guide"; shot.lifetime = .keepAlways; add(shot)
        app.terminate()
    }

    func testRecentlyDeletedRestoreAndPermanentRemoval() throws {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test-review"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Sessions"].waitForExistence(timeout: 20)); app.tabBars.buttons["Sessions"].tap()
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'sessionActions-'")).firstMatch.tap()
        app.buttons["deleteSessionAction"].tap(); app.buttons["confirmDeleteSession"].tap()
        XCTAssertTrue(app.buttons["undoSessionDeletion"].waitForExistence(timeout: 5))
        app.buttons["undoSessionDeletion"].tap()
        XCTAssertTrue(app.staticTexts["Review sample"].exists)
        sleep(1) // Wait for the restored row to finish its native List insertion animation.
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'sessionActions-'")).firstMatch.tap()
        app.buttons["deleteSessionAction"].tap(); app.buttons["confirmDeleteSession"].tap()
        app.buttons["sessionLibraryOptions"].tap()
        app.buttons["recentlyDeletedLink"].tap()
        app.buttons["restoreDeletedSession"].tap()
        XCTAssertTrue(app.staticTexts["No deleted sessions"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'sessionActions-'")).firstMatch.tap()
        app.buttons["deleteSessionAction"].tap(); app.buttons["confirmDeleteSession"].tap()
        app.buttons["sessionLibraryOptions"].tap()
        app.buttons["recentlyDeletedLink"].tap()
        app.buttons["Delete permanently"].tap(); app.buttons["permanentlyDeleteSession"].tap()
        XCTAssertTrue(app.staticTexts["No deleted sessions"].waitForExistence(timeout: 5))
        app.terminate()
    }

    func testFocusedReaderWithLargeTextAndButtonNames() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-media", "--ui-test-translation", "--ui-test-focus", "--ui-test-labels", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Sessions"].waitForExistence(timeout: 20)); app.tabBars.buttons["Sessions"].tap()
        app.staticTexts["Review sample"].tap(); app.buttons["sessionMediaButton"].tap()
        XCTAssertTrue(app.buttons["recordingPlayButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.segmentedControls["playbackModePicker"].exists)
        app.buttons["nextParagraphButton"].tap()
        XCTAssertEqual(app.buttons["recordingPlayButton"].label, "Play")
        XCTAssertTrue(app.staticTexts["playbackCaption"].exists)
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        XCTAssertTrue(app.buttons["recordingPlayButton"].exists)
        XCTAssertTrue(app.staticTexts["playbackCaption"].exists)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = "Focused-large-text"; shot.lifetime = .keepAlways; add(shot)
        app.terminate()
    }

    @MainActor
    func testSimpleHomeAccessibilityDescriptionsAndTraits() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-simple", "--ui-test-labels"]
        app.launch()
        XCTAssertTrue(app.buttons["simpleListenNow"].waitForExistence(timeout: 20))
        try app.performAccessibilityAudit(for: [.sufficientElementDescription, .trait, .hitRegion])
        app.terminate()
    }

    @MainActor
    func testLargeTextCapturePauseAndResumeRemainReachable() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-reader", "--ui-test-session-flow", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let primary = app.buttons["primaryCaptionAction"]
        XCTAssertTrue(primary.waitForExistence(timeout: 20)); primary.tap()
        XCTAssertTrue(app.buttons["stopCaptionAction"].waitForExistence(timeout: 10))
        primary.tap()
        XCTAssertTrue(app.buttons["resumeCaptureButton"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["resumeCaptureButton"].isHittable, "Resume should be immediately reachable at the largest text size")
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = "Large-text-pause"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["resumeCaptureButton"].tap()
        XCTAssertEqual(primary.label, "Pause")
        app.buttons["stopCaptionAction"].tap()
        XCTAssertTrue(app.buttons["saveSessionButton"].waitForExistence(timeout: 10))
        app.terminate()
    }

    @MainActor
    func testDefaultPreparationGuideReturnsWithoutStartingCapture() throws {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test-reader", "--ui-test-session-flow"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.buttons["Before a meeting or class"].exists)
        app.tabBars.buttons["Settings"].tap()
        let preparation = app.buttons["Check preparation"]
        if !preparation.isHittable { app.swipeUp() }
        preparation.tap()
        XCTAssertTrue(app.navigationBars["Offline Readiness"].waitForExistence(timeout: 5))
        app.buttons["See a short demonstration"].tap()
        XCTAssertTrue(app.staticTexts["Demonstration · no recording"].waitForExistence(timeout: 5))
        app.navigationBars["Quick guide"].buttons["Done"].tap()
        app.navigationBars["Offline Readiness"].buttons["Done"].tap()
        app.tabBars.buttons["Captions"].tap()
        XCTAssertTrue(app.buttons["primaryCaptionAction"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["primaryCaptionAction"].label, "Start Listening")
        app.terminate()
    }

    @MainActor
    func testPlaybackComfortPreferencesAndSearch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-media", "--ui-test-translation"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Sessions"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Sessions"].tap(); app.staticTexts["Review sample"].tap()
        app.buttons["sessionMediaButton"].tap()
        XCTAssertTrue(app.buttons["recordingPlayButton"].waitForExistence(timeout: 10))
        app.buttons["At my pace"].tap()
        app.buttons["playbackTextMenu"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["Both"].tap()
        app.buttons["recordingPlayButton"].tap()
        XCTAssertTrue(app.staticTexts["Listening now"].exists)
        app.buttons["recordingPlayButton"].tap()
        app.navigationBars["Audio & subtitles"].buttons["Done"].tap()
        app.buttons["sessionMediaButton"].tap()
        XCTAssertTrue(app.buttons["recordingPlayButton"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.buttons["playbackTextMenu"].value as? String, "Both")
        XCTAssertTrue(app.buttons["At my pace"].isSelected)
        app.buttons["openParagraphList"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("zzznomatch")
        XCTAssertFalse(app.buttons["listenPlaybackParagraph-0"].exists)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = "Playback-search"; shot.lifetime = .keepAlways; add(shot)
        app.terminate()
    }

    @MainActor
    func testUnifiedAudioGeometryAndSilentNavigation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-media", "--ui-test-translation"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Sessions"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Sessions"].tap(); app.staticTexts["Review sample"].tap()
        app.buttons["sessionMediaButton"].tap()
        let play = app.buttons["recordingPlayButton"]
        XCTAssertTrue(play.waitForExistence(timeout: 8))
        app.buttons["At my pace"].tap()
        XCTAssertFalse(app.buttons["repeatParagraphButton"].exists)
        let original = play.frame.size
        let reader = app.scrollViews["playbackCaptionScroll"]
        let originalHeight = reader.frame.height
        app.buttons["nextParagraphButton"].tap()
        XCTAssertEqual(play.label, "Play")
        XCTAssertEqual(app.staticTexts["playbackParagraphPosition"].label, "Paragraph 2 of 80")
        app.buttons["playbackTextMenu"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["Translation"].tap()
        XCTAssertEqual(play.frame.size, original)
        XCTAssertEqual(reader.frame.height, originalHeight, accuracy: 2)
        XCTAssertEqual(play.label, "Play")
        app.buttons["playbackTextMenu"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap(); app.buttons["Both"].tap()
        XCTAssertTrue(app.staticTexts["playbackTranslationCaption"].exists)
        XCTAssertTrue(app.staticTexts["playbackCaption"].exists)
        play.tap(); XCTAssertEqual(play.label, "Pause")
        play.tap(); XCTAssertEqual(play.label, "Resume")
        app.buttons["nextParagraphButton"].tap(); XCTAssertEqual(play.label, "Play")
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "Unified-bilingual-reader"; shot.lifetime = .keepAlways; add(shot)
        app.terminate()
    }

    @MainActor
    func testStopAutomaticallyTranslatesWithoutTranslateButton() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-reader", "--ui-test-live-translation", "--ui-test-session-flow"]
        app.launch()
        let start = app.buttons["primaryCaptionAction"]
        XCTAssertTrue(start.waitForExistence(timeout: 15)); start.tap()
        let stop = app.buttons["stopCaptionAction"]
        XCTAssertTrue(stop.waitForExistence(timeout: 10))
        sleep(2); stop.tap()
        XCTAssertTrue(app.staticTexts["Translation saved"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["saveSessionButton"].exists, "Automatic translation leaves the save/discard decision intact")
        app.terminate()
    }

    @MainActor
    func testLongPlaybackParagraphScrollsAndPreviousRestoresIt() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-media", "--ui-test-long-paragraph"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Sessions"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Sessions"].tap()
        app.staticTexts["Review sample"].tap()
        app.buttons["sessionMediaButton"].tap()
        app.buttons["At my pace"].tap()
        let reader = app.scrollViews["playbackCaptionScroll"]
        XCTAssertTrue(reader.waitForExistence(timeout: 8))
        XCTAssertGreaterThan(reader.frame.height, 180)
        let text = app.staticTexts["playbackCaption"]
        XCTAssertTrue(text.label.hasSuffix("End of long paragraph."))
        let originalY = text.frame.minY
        reader.swipeUp()
        XCTAssertLessThan(text.frame.minY, originalY, "A long paragraph must scroll inside the expanded reader")
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "Long-paragraph-expanded-reader"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["nextParagraphButton"].tap()
        XCTAssertTrue(text.label.contains("Paragraph 2"))
        app.buttons["previousParagraphButton"].tap()
        XCTAssertTrue(text.label.hasPrefix("Start of long paragraph."))
        XCTAssertFalse(app.buttons["previousParagraphButton"].isEnabled)
        app.terminate()
    }

    @MainActor
    func testSwipeActionsProtectBeforeDeleting() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Sessions"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Sessions"].tap()
        let row = app.staticTexts["Review sample"]
        let cell = app.cells.containing(.staticText, identifier: "Review sample").firstMatch
        let protect = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "swipeFavoriteSession-")).firstMatch
        let delete = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "swipeDeleteSession-")).firstMatch
        cell.swipeRight()
        XCTAssertFalse(protect.exists); XCTAssertFalse(delete.exists)
        cell.swipeLeft()
        XCTAssertTrue(protect.waitForExistence(timeout: 5))
        XCTAssertTrue(delete.exists)
        XCTAssertEqual(protect.label, "Favorite")
        protect.tap()
        XCTAssertTrue(row.exists)
        cell.swipeLeft()
        XCTAssertFalse(delete.exists, "A protected favorite cannot be deleted")
        XCTAssertTrue(protect.exists); XCTAssertEqual(protect.label, "Unprotect")
        protect.tap()
        XCTAssertTrue(app.buttons["confirmRemoveSessionProtection"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Protected favorite"].exists, "Cancelling must retain protection")
        cell.swipeLeft(); protect.tap()
        app.buttons["confirmRemoveSessionProtection"].tap()
        XCTAssertTrue(row.exists, "Removing protection must preserve the session")
        cell.swipeLeft()
        XCTAssertTrue(delete.waitForExistence(timeout: 5)); delete.tap()
        XCTAssertTrue(app.buttons["confirmDeleteSession"].waitForExistence(timeout: 5))
        XCTAssertTrue(row.exists, "Deletion waits for confirmation")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(row.exists, "Cancelling deletion must preserve the session")
        cell.swipeLeft(); delete.tap(); app.buttons["confirmDeleteSession"].tap()
        XCTAssertFalse(row.waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["undoSessionDeletion"].exists)
    }

    @MainActor
    func testSessionSwipeClosesAndMenuDoesNotExpandOrDuplicateRowActions() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-labels"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Sessions"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Sessions"].tap()
        let cell = app.cells.containing(.staticText, identifier: "Review sample").firstMatch
        let height = cell.frame.height
        let favorites = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "swipeFavoriteSession-"))
        let deletes = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "swipeDeleteSession-"))
        cell.swipeLeft()
        XCTAssertTrue(deletes.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(favorites.count, 1); XCTAssertEqual(deletes.count, 1)
        XCTAssertFalse(app.buttons["protectSessionAction"].exists)
        XCTAssertFalse(app.buttons["deleteSessionAction"].exists)
        cell.swipeRight()
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: deletes.firstMatch)
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 5), .completed)
        XCTAssertEqual(cell.frame.height, height, accuracy: 2)
        let menu = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "sessionActions-")).firstMatch
        XCTAssertEqual(menu.label, "Session actions")
        menu.tap()
        XCTAssertTrue(app.buttons["protectSessionAction"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "protectSessionAction").count, 1)
        XCTAssertEqual(app.buttons.matching(identifier: "deleteSessionAction").count, 1)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        XCTAssertTrue(menu.isHittable)
        XCTAssertEqual(cell.frame.height, height, accuracy: 2, "The menu must not leave expanded controls in the row")
        menu.tap()
        app.buttons["protectSessionAction"].tap()
        menu.tap()
        XCTAssertFalse(app.buttons["deleteSessionAction"].isEnabled)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        XCTAssertTrue(menu.isHittable, "The native menu must dismiss when tapping outside")
    }

    @MainActor
    func testReadersRetireBookmarksAndKeepSessionFavorites() throws {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test-review", "--ui-test-translation"]
        app.launch(); XCTAssertTrue(app.tabBars.buttons["Sessions"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.buttons["Before a meeting or class"].exists)
        XCTAssertTrue(app.buttons["speakTranslateEntry"].isHittable)
        app.buttons["sessionActionsButton"].tap()
        XCTAssertFalse(app.buttons["Bookmarks"].exists)
        // iPad presents a popover without a Cancel row; dismiss by tapping outside it.
        if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
        else { app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.12)).tap() }
        app.tabBars.buttons["Sessions"].tap(); app.staticTexts["Review sample"].tap()
        XCTAssertTrue(app.buttons["favoriteSessionButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["savedBookmark-0"].exists)
        XCTAssertFalse(app.buttons["Bookmarks"].exists)
        XCTAssertEqual(app.buttons["sessionTranslationButton"].label, "Text & translation")
        app.buttons["sessionTranslationButton"].tap()
        XCTAssertTrue(app.staticTexts["translatedParagraph-0"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["playTranslationParagraph-0"].exists)
        XCTAssertFalse(app.buttons["translationBookmark-0"].exists)
        XCTAssertTrue(app.buttons["editSpanishButton"].exists)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "Text-and-translation-clean"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["translatedMediaButton"].tap()
        XCTAssertTrue(app.buttons["recordingPlayButton"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["playbackBookmarkButton"].exists)
        app.navigationBars["Audio & subtitles"].buttons["Done"].tap()
        app.navigationBars["Text & translation"].buttons["Done"].tap()
        app.buttons["reviewShareButton"].tap()
        XCTAssertTrue(app.staticTexts["exportPreviewText"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.segmentedControls["exportContentPicker"].exists)
        XCTAssertFalse(app.buttons["Bookmarks"].exists)
        app.terminate()
    }

    @MainActor
    func testTranslationSpeechWithoutRecordingEnglishToSpanish() throws { try checkTranslationSpeech(reverse: false) }
    @MainActor
    func testTranslationSpeechWithoutRecordingSpanishToEnglish() throws { try checkTranslationSpeech(reverse: true) }
    @MainActor
    private func checkTranslationSpeech(reverse: Bool) throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-translation"]
        if reverse { app.launchArguments.append("--ui-test-spanish") }
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Sessions"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Sessions"].tap()
        app.staticTexts["Review sample"].tap()
        app.buttons["sessionTranslationButton"].tap()
        XCTAssertTrue(app.staticTexts["translatedParagraph-0"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["playTranslationParagraph-0"].exists)
        app.segmentedControls["translationLanguagePicker"].buttons["Both"].tap()
        app.buttons["translatedMediaButton"].tap()
        let play = app.buttons["recordingPlayButton"]
        XCTAssertTrue(play.waitForExistence(timeout: 8))
        XCTAssertEqual(app.buttons["playbackTextMenu"].value as? String, "Both")
        play.tap(); XCTAssertEqual(play.label, "Pause")
        play.tap(); XCTAssertEqual(play.label, "Resume")
        XCTAssertTrue(app.staticTexts["playbackTranslationCaption"].exists)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "Unified-bilingual-playback"; shot.lifetime = .keepAlways; add(shot)
        app.terminate()
    }

    @MainActor
    func testLiveBilingualEnglishCapture() throws { try checkLiveBilingual(spanish: false) }

    @MainActor
    func testLiveBilingualSpanishCapture() throws { try checkLiveBilingual(spanish: true) }

    @MainActor
    private func checkLiveBilingual(spanish: Bool) throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-reader", "--ui-test-session-flow", "--ui-test-live-translation"]
        if spanish { app.launchArguments.append("--ui-test-spanish") }
        app.launch()
        let action = app.buttons["primaryCaptionAction"]
        XCTAssertTrue(action.waitForExistence(timeout: 20))
        action.tap()
        expectation(for: NSPredicate(format: "label == 'Pause'"), evaluatedWith: action)
        waitForExpectations(timeout: 10)
        let selector = app.buttons["liveSpanishButton"]
        selector.tap(); app.buttons["Both"].tap()
        XCTAssertEqual(action.label, "Pause", "Changing presentation must not stop capture")
        action.tap()
        XCTAssertTrue(app.buttons["resumeCaptureButton"].waitForExistence(timeout: 5))
        let originals = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'liveOriginal-'"))
        let translations = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH 'liveTranslated-'"))
        XCTAssertTrue(translations.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(originals.firstMatch.exists)
        let translated = translations.firstMatch
        let sourceID = translated.identifier.replacingOccurrences(of: "liveTranslated-", with: "liveOriginal-")
        XCTAssertTrue(app.staticTexts[sourceID].exists, "Original and translation must remain paired by paragraph")
        XCTAssertTrue(translated.label.contains(spanish ? "Test translation" : "Traducción de prueba"))
        XCTAssertTrue(app.staticTexts[sourceID].label.contains(spanish ? "Párrafo" : "Paragraph"))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "liveBookmark-")).firstMatch.exists)
        let follow = app.buttons["liveTranslationFollowButton"]
        XCTAssertFalse(follow.exists)
        app.scrollViews["liveTranslationReader"].swipeDown()
        XCTAssertTrue(follow.waitForExistence(timeout: 5))
        XCTAssertEqual(follow.label, "Back to live text")
        follow.tap()
        XCTAssertFalse(follow.exists)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = spanish ? "Live-both-Spanish" : "Live-both-English"; shot.lifetime = .keepAlways; add(shot)
        selector.tap(); app.buttons[spanish ? "Translation English" : "Translation Español"].tap()
        expectation(for: NSPredicate { _, _ in originals.count == 0 }, evaluatedWith: app)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(translations.firstMatch.exists)
        selector.tap(); app.buttons[spanish ? "Original Español" : "Original English"].tap()
        XCTAssertTrue(app.scrollViews["captionScrollView"].exists)
        XCTAssertFalse(app.scrollViews["liveTranslationReader"].exists)
        selector.tap(); app.buttons["Both"].tap()
        XCTAssertTrue(translations.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["resumeCaptureButton"].exists)
        app.buttons["resumeCaptureButton"].tap()
        expectation(for: NSPredicate(format: "label == 'Pause'"), evaluatedWith: action)
        waitForExpectations(timeout: 5)
        app.buttons["fullScreenButton"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        expectation(for: NSPredicate { _, _ in app.frame.width > app.frame.height && selector.isHittable }, evaluatedWith: app)
        waitForExpectations(timeout: 12)
        XCTAssertTrue(translations.firstMatch.exists)
        let landscape = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        landscape.name = "Live-both-landscape"; landscape.lifetime = .keepAlways; add(landscape)
    }

    @MainActor
    func testAtMyPaceEditingAndProtectedFavorites() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-media"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Sessions"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Sessions"].tap()
        app.staticTexts["Review sample"].tap()
        app.buttons["favoriteSessionButton"].tap()
        XCTAssertEqual(app.buttons["favoriteSessionButton"].label, "Protected favorite")
        app.buttons["sessionMediaButton"].tap()
        XCTAssertTrue(app.buttons["At my pace"].waitForExistence(timeout: 5))
        app.buttons["At my pace"].tap()
        XCTAssertFalse(app.buttons["previousParagraphButton"].isEnabled)
        XCTAssertGreaterThan(app.scrollViews["playbackCaptionScroll"].frame.height, 180)
        app.buttons["recordingPlayButton"].tap()
        expectation(for: NSPredicate(format: "label == 'Listen again'"), evaluatedWith: app.buttons["recordingPlayButton"])
        waitForExpectations(timeout: 8)
        let caption = app.staticTexts["playbackCaption"]
        XCTAssertTrue(caption.label.contains("Acmee"), "Finished paragraphs must stay visible")
        app.buttons["editPlaybackOriginalButton"].tap()
        let editor = app.textViews["paragraphEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap(); editor.typeText(" Reviewed at my pace.")
        app.buttons["saveParagraphCorrection"].tap()
        XCTAssertTrue(caption.waitForExistence(timeout: 5))
        XCTAssertTrue(caption.label.contains("Reviewed at my pace."))
        XCTAssertEqual(app.buttons["recordingPlayButton"].label, "Listen again")
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "Pace-corrected-paragraph"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["nextParagraphButton"].tap()
        expectation(for: NSPredicate(format: "label CONTAINS 'Paragraph 2'"), evaluatedWith: caption)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.buttons["previousParagraphButton"].isEnabled)
        app.buttons["previousParagraphButton"].tap()
        XCTAssertTrue(caption.label.contains("Acmee"))
        XCTAssertFalse(app.buttons["previousParagraphButton"].isEnabled)
        app.buttons["Full screen"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        expectation(for: NSPredicate { _, _ in
            app.frame.width > app.frame.height && app.buttons["editPlaybackOriginalButton"].isHittable
        }, evaluatedWith: app)
        waitForExpectations(timeout: 12)
        let landscape = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        landscape.name = "Pace-fullscreen-landscape"; landscape.lifetime = .keepAlways; add(landscape)
        app.buttons["Exit full screen"].tap()
        XCUIDevice.shared.orientation = .portrait
        expectation(for: NSPredicate { _, _ in
            app.frame.height > app.frame.width && app.buttons["playbackOptionsButton"].isHittable
        }, evaluatedWith: app)
        waitForExpectations(timeout: 8)
        // iPad resizes the sheet after the device orientation event; wait for that animation.
        Thread.sleep(forTimeInterval: 1)
        app.buttons["playbackOptionsButton"].tap()
        XCTAssertTrue(app.buttons["phraseListButton"].waitForExistence(timeout: 5))
        // Protected audio cannot be deleted, even from the media screen.
        let delete = app.buttons["Delete audio, keep text"]
        for _ in 0..<18 { if delete.exists { break }; app.collectionViews["mediaActionsList"].swipeUp() }
        XCTAssertTrue(delete.exists)
        XCTAssertFalse(delete.isEnabled)
        app.navigationBars["Playback options"].buttons["Done"].tap()
        app.navigationBars["Audio & subtitles"].buttons["Done"].tap()
        app.buttons["favoriteSessionButton"].tap()
        if app.frame.width > 600 {
            // iPad confirmation popovers cancel by tapping outside, without a Cancel row.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.8)).tap()
        } else { app.buttons["Cancel"].tap() }
        XCTAssertEqual(app.buttons["favoriteSessionButton"].label, "Protected favorite")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Favorites"].tap()
        XCTAssertTrue(app.staticTexts["Review sample"].exists)
        let favorite = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        favorite.name = "Pace-favorites"; favorite.lifetime = .keepAlways; add(favorite)
    }

    @MainActor
    func testProminentPreparationDoesNotStartCapture() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-reader", "--ui-test-preparation"]
        app.launch()
        let microphone = app.buttons["Allow Microphone"]
        XCTAssertTrue(microphone.waitForExistence(timeout: 20))
        XCTAssertTrue(microphone.isHittable)
        if app.frame.width < 450 {
            XCTAssertGreaterThan(app.staticTexts["Microphone access is needed to hear the conversation."].frame.height, 24, "The notice must wrap instead of truncating")
        }
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "First-preparation"; shot.lifetime = .keepAlways; add(shot)
        microphone.tap()
        let model = app.buttons["Download speech model"]
        XCTAssertTrue(model.waitForExistence(timeout: 5))
        XCTAssertTrue(model.isHittable)
        model.tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: model)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(app.buttons["primaryCaptionAction"].label, "Start Listening")
        XCTAssertFalse(app.buttons["resumeCaptureButton"].exists)
    }

    @MainActor
    func testInterfaceLanguageDoesNotChangeCaptureLanguage() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-reader", "--ui-test-session-flow"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Settings"].tap()
        app.buttons["interfaceLanguagePicker"].tap()
        app.buttons["Spanish · Español"].tap()
        XCTAssertTrue(app.tabBars.buttons["Ajustes"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Ajustes"].exists)
        XCTAssertTrue(app.buttons["captureLanguagePicker"].label.contains("English"))
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "Separate-interface-and-capture-languages"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["captureLanguagePicker"].tap()
        app.buttons["Spanish · Español"].tap()
        app.buttons["interfaceLanguagePicker"].tap()
        app.buttons["English"].tap()
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)
        XCTAssertTrue(app.navigationBars["Settings"].exists)
        XCTAssertTrue(app.buttons["captureLanguagePicker"].label.contains("Español"))
        app.tabBars.buttons["Captions"].tap()
        XCTAssertTrue(app.staticTexts["captionPlaceholder"].label.contains("Español"))
        app.buttons["primaryCaptionAction"].tap()
        expectation(for: NSPredicate(format: "label == 'Pause'"), evaluatedWith: app.buttons["primaryCaptionAction"])
        waitForExpectations(timeout: 10)
        app.buttons["primaryCaptionAction"].tap()
        XCTAssertTrue(app.buttons["resumeCaptureButton"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Settings"].tap()
        app.buttons["interfaceLanguagePicker"].tap()
        app.buttons["Spanish · Español"].tap()
        app.tabBars.buttons["Subtítulos"].tap()
        XCTAssertTrue(app.buttons["resumeCaptureButton"].exists)
        XCTAssertEqual(app.buttons["resumeCaptureButton"].label, "Reanudar")
    }

    @MainActor
    func testBilingualSettingsPaperAndInterruptedResume() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-reader", "--ui-test-session-flow", "--ui-test-interruption"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Settings"].tap()
        let language = app.descendants(matching: .any).matching(identifier: "captureLanguagePicker").firstMatch
        for _ in 0..<8 {
            if language.isHittable { break }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7)).press(forDuration: 0.05,
                thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
        }
        XCTAssertTrue(language.isHittable)
        language.tap()
        app.buttons["Spanish · Español"].tap()
        app.tabBars.buttons["Captions"].tap()
        XCTAssertTrue(app.staticTexts["captionPlaceholder"].label.contains("Español"))
        app.buttons["readingOptionsButton"].tap()
        let paper = app.buttons["readerPaperPicker"]
        for _ in 0..<8 {
            if paper.isHittable { break }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7)).press(forDuration: 0.05,
                thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
        }
        paper.tap()
        app.buttons["Light yellow"].tap()
        let lines = app.switches["ruledPaperToggle"]
        for _ in 0..<8 {
            if lines.isHittable { break }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7)).press(forDuration: 0.05,
                thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
        }
        XCTAssertTrue(lines.isHittable)
        lines.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        expectation(for: NSPredicate(format: "value == '1'"), evaluatedWith: lines)
        waitForExpectations(timeout: 5)
        app.buttons["Done"].tap()
        app.buttons["primaryCaptionAction"].tap()
        let banner = app.descendants(matching: .any).matching(identifier: "pausedCaptureBanner").firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["resumeCaptureButton"].isHittable)
        let paused = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        paused.name = "Paper-interrupted-portrait"; paused.lifetime = .keepAlways; add(paused)
        app.buttons["fullScreenButton"].tap()
        XCTAssertTrue(banner.exists)
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let rotated = NSPredicate { _, _ in
            app.frame.width > app.frame.height && app.buttons["resumeCaptureButton"].isHittable
        }
        expectation(for: rotated, evaluatedWith: app)
        waitForExpectations(timeout: 10)
        app.scrollViews["captionScrollView"].swipeDown()
        let landscape = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        landscape.name = "Paper-interrupted-fullscreen-landscape"; landscape.lifetime = .keepAlways; add(landscape)
        app.buttons["resumeCaptureButton"].tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: banner)
        waitForExpectations(timeout: 10)
        XCTAssertEqual(app.buttons["primaryCaptionAction"].label, "Pause")
        app.buttons["stopCaptionAction"].tap()
    }

    @MainActor
    func testSpanishSessionTranslationKeepsExistingFlowWithoutPracticeAccess() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-spanish", "--ui-test-translation"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Sessions"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Sessions"].tap()
        app.staticTexts["Review sample"].tap()
        app.buttons["sessionTranslationButton"].tap()
        let paragraph = app.staticTexts["translatedParagraph-0"]
        XCTAssertTrue(paragraph.waitForExistence(timeout: 10))
        XCTAssertEqual(paragraph.label, "Hello world. We learn together.")
        app.segmentedControls["translationLanguagePicker"].buttons["Spanish · Español"].tap()
        XCTAssertEqual(paragraph.label, "Hola mundo. Aprendemos juntos.")
        app.buttons["Done"].tap()
        XCTAssertFalse(app.buttons["learnEnglishButton"].exists)
    }

    @MainActor
    func testIndependentEnglishTrainingSeedReviewAndTemporaryRound() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-communication", "--ui-test-conversation", "--ui-test-live-translation", "--ui-test-training", "--ui-test-labels"]
        app.launchEnvironment["TRAINING_TEST_ID"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(trainingEntry(in: app).waitForExistence(timeout: 20))
        trainingEntry(in: app).tap()
        app.staticTexts["Una mañana en el colegio"].tap()
        let start = app.buttons["startEnglishTraining"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertFalse(start.isEnabled)
        app.buttons["prepareTrainingEnglish"].tap()
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: start)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
        app.buttons["reviewTrainingEnglish"].tap()
        let english = app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH %@", "trainingEnglish-")).firstMatch
        XCTAssertTrue(english.waitForExistence(timeout: 5))
        XCTAssertEqual(english.value as? String, "Test translation. We read both languages together.")
        app.buttons["saveTrainingEnglish"].tap()
        start.tap()
        XCTAssertTrue(app.staticTexts["trainingPrompt"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["trainingPrompt"].label, "Yo había ido al colegio ayer por la mañana.")
        XCTAssertFalse(app.staticTexts["trainingExpected"].exists)
        XCTAssertFalse(app.alerts.firstMatch.exists, "Opening training must not request microphone access")
        app.buttons["revealTrainingResponse"].tap()
        XCTAssertTrue(app.staticTexts["trainingExpected"].exists)
        XCTAssertFalse(app.staticTexts["How did this phrase feel?"].exists)
        XCTAssertFalse(app.buttons["Needs practice"].exists)
        XCTAssertFalse(app.buttons["I feel comfortable"].exists)
        for _ in 0..<20 {
            let next = app.buttons["trainingNext"]
            if !next.isHittable { app.swipeUp() }
            next.tap()
        }
        XCTAssertTrue(app.staticTexts["trainingRoundSummary"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["trainingUnattemptedCount"].firstMatch.label.contains("20"))
        XCTAssertTrue(app.descendants(matching: .any)["trainingMatchedCount"].firstMatch.label.contains("0"))
        XCTAssertTrue(app.descendants(matching: .any)["trainingDifferentCount"].firstMatch.label.contains("0"))
        XCTAssertFalse(app.buttons["trainingReviewDifferences"].exists)
        app.terminate(); app.launch()
        XCTAssertTrue(trainingEntry(in: app).waitForExistence(timeout: 20))
        trainingEntry(in: app).tap()
        app.staticTexts["Una mañana en el colegio"].tap()
        XCTAssertFalse(app.buttons["Review phrases to practise"].exists)
        app.buttons["startEnglishTraining"].tap()
        XCTAssertEqual(app.staticTexts["trainingPrompt"].label, "Yo había ido al colegio ayer por la mañana.")
    }

    @MainActor
    func testMultilingualTrainingLanguagesConfirmationAndRetranslation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-communication", "--ui-test-conversation", "--ui-test-live-translation", "--ui-test-training", "--ui-test-labels"]
        app.launchEnvironment["TRAINING_TEST_ID"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(trainingEntry(in: app).waitForExistence(timeout: 20))
        trainingEntry(in: app).tap()
        app.buttons["newEnglishTraining"].tap()
        app.textFields["trainingTitle"].tap(); app.textFields["trainingTitle"].typeText("My languages")
        app.buttons["trainingSourceLanguage"].tap(); app.buttons["English"].tap()
        XCTAssertFalse(app.buttons["saveEnglishTraining"].isEnabled, "Identical languages cannot be saved")
        app.buttons["trainingTargetLanguage"].tap(); app.buttons["French · Français"].tap()
        app.textViews["trainingSpanishInput"].tap(); app.textViews["trainingSpanishInput"].typeText("Hello\nThanks")
        app.buttons["saveEnglishTraining"].tap()
        app.staticTexts["My languages"].tap()
        app.buttons["prepareTrainingEnglish"].tap()
        let start = app.buttons["startEnglishTraining"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: start)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
        app.buttons["reviewTrainingEnglish"].tap()
        let translated = app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH %@", "trainingEnglish-")).firstMatch
        XCTAssertTrue(translated.waitForExistence(timeout: 5))
        XCTAssertEqual(translated.value as? String, "Bonjour")
        translated.tap(); translated.typeText(" corrected")
        let correction = translated.value as? String
        app.buttons["saveTrainingEnglish"].tap()
        app.buttons["retranslateTraining"].tap()
        XCTAssertTrue(app.buttons["confirmTrainingRetranslation"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].lastMatch.tap()
        app.buttons["reviewTrainingEnglish"].tap()
        XCTAssertEqual(translated.value as? String, correction, "Cancelling retranslation must retain manual corrections")
        app.navigationBars["Review translations"].buttons["Cancel"].tap()
        app.buttons["editTrainingSource"].tap()
        app.buttons["trainingTargetLanguage"].tap(); app.buttons["Japanese · 日本語"].tap()
        app.buttons["saveEnglishTraining"].tap()
        XCTAssertTrue(app.buttons["confirmTrainingLanguages"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].lastMatch.tap()
        app.navigationBars["Edit training"].buttons["Cancel"].tap()
        app.buttons["reviewTrainingEnglish"].tap()
        XCTAssertEqual(translated.value as? String, correction)
        app.navigationBars["Review translations"].buttons["Cancel"].tap()
        app.buttons["editTrainingSource"].tap()
        app.buttons["trainingTargetLanguage"].tap(); app.buttons["Japanese · 日本語"].tap()
        app.buttons["saveEnglishTraining"].tap(); app.buttons["confirmTrainingLanguages"].tap()
        let translatedAgain = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: start)
        XCTAssertEqual(XCTWaiter.wait(for: [translatedAgain], timeout: 10), .completed)
        app.buttons["reviewTrainingEnglish"].tap()
        XCTAssertEqual(translated.value as? String, "こんにちは")
        app.buttons["saveTrainingEnglish"].tap()
        start.tap()
        XCTAssertEqual(app.staticTexts["trainingPrompt"].label, "Hello")
        XCTAssertTrue(app.staticTexts["Try saying this in 日本語 before revealing the response."].exists)
        app.buttons["revealTrainingResponse"].tap()
        XCTAssertEqual(app.staticTexts["trainingExpected"].label, "こんにちは")
    }

    @MainActor
    func testCreateSeparateEnglishTrainingAndRetireSessionPractice() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-communication", "--ui-test-conversation", "--ui-test-live-translation", "--ui-test-training", "--ui-test-labels"]
        app.launchEnvironment["TRAINING_TEST_ID"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(trainingEntry(in: app).waitForExistence(timeout: 20))
        let train = trainingEntry(in: app)
        let write = app.buttons["conversationWriteReply"]
        let new = app.buttons["newConversationButton"]
        XCTAssertEqual(train.label, "Train")
        XCTAssertEqual(write.label, "Write a reply")
        XCTAssertEqual(new.label, "New conversation")
        XCTAssertLessThan(new.frame.midY, train.frame.midY)
        XCTAssertLessThan(train.frame.midY, write.frame.midY)
        let newConversationSize = new.frame.size
        trainingEntry(in: app).tap()
        let newTraining = app.buttons["newEnglishTraining"]
        XCTAssertTrue(newTraining.waitForExistence(timeout: 5))
        XCTAssertEqual(newTraining.frame.width, newConversationSize.width, accuracy: 1)
        XCTAssertEqual(newTraining.frame.height, newConversationSize.height, accuracy: 1)
        newTraining.tap()
        app.textFields["trainingTitle"].tap(); app.textFields["trainingTitle"].typeText("Travel")
        app.textViews["trainingSpanishInput"].tap(); app.textViews["trainingSpanishInput"].typeText("Buenos días.\nNecesito un taxi.")
        app.buttons["saveEnglishTraining"].tap()
        XCTAssertTrue(app.staticTexts["Travel"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Una mañana en el colegio"].exists)
        app.tabBars.buttons["Saved"].tap()
        XCTAssertFalse(app.buttons["savedLanguagePractice"].exists)
        app.staticTexts["Review sample"].tap()
        XCTAssertFalse(app.buttons["learnEnglishButton"].exists)
        XCTAssertTrue(app.buttons["sessionTranslationButton"].exists)
        XCTAssertTrue(app.buttons["sessionMediaButton"].exists)
    }

    @MainActor
    func testSavedTranslationLanguagesEditingPlaybackAndShare() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-media", "--ui-test-translation"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Sessions"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Sessions"].tap()
        app.staticTexts["Review sample"].tap()
        app.buttons["sessionTranslationButton"].tap()
        let paragraph = app.staticTexts["translatedParagraph-0"]
        XCTAssertTrue(paragraph.waitForExistence(timeout: 10))
        XCTAssertEqual(paragraph.label, "Hola mundo. Aprendemos juntos.")
        app.segmentedControls["translationLanguagePicker"].buttons["Both"].tap()
        XCTAssertTrue(app.staticTexts["translatedOriginal-0"].label.contains("Acmee"))
        XCTAssertTrue(paragraph.label.contains("Hola mundo"))
        app.segmentedControls["translationLanguagePicker"].buttons["English"].tap()
        XCTAssertFalse(paragraph.label.contains("Hola mundo"))
        app.segmentedControls["translationLanguagePicker"].buttons["Spanish · Español"].tap()
        app.buttons["editSpanishButton"].tap()
        app.buttons["editParagraph-0"].tap()
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText(" Traducción revisada.")
        app.buttons["Apply"].tap()
        app.buttons["saveTranscriptEdits"].tap()
        XCTAssertTrue(paragraph.waitForExistence(timeout: 5))
        XCTAssertTrue(paragraph.label.contains("Traducción revisada."))
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "Spanish-translation-reader"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["translatedMediaButton"].tap()
        let play = app.buttons["recordingPlayButton"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        app.buttons["playbackTextMenu"].tap()
        app.buttons["Both"].tap()
        for mode in ["Continuous", "At my pace"] {
            app.buttons[mode].tap()
            XCTAssertTrue(app.buttons["editPlaybackOriginalButton"].isHittable)
            XCTAssertTrue(app.buttons["editPlaybackTranslationButton"].isHittable)
            app.buttons["editPlaybackOriginalButton"].tap()
            let originalEditor = app.textViews["paragraphEditor"]
            XCTAssertTrue(originalEditor.waitForExistence(timeout: 5))
            XCTAssertTrue((originalEditor.value as? String ?? "").contains("Acmee"))
            XCTAssertFalse((originalEditor.value as? String ?? "").contains("Hola mundo"))
            app.buttons["Cancel"].tap()
            expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: originalEditor)
            waitForExpectations(timeout: 8)
        }
        app.buttons["Continuous"].tap()
        app.buttons["playbackTextMenu"].tap()
        app.buttons["Translation"].tap()
        play.tap()
        expectation(for: NSPredicate(format: "label == 'Pause'"), evaluatedWith: play)
        waitForExpectations(timeout: 8)
        play.tap()
        XCTAssertEqual(play.label, "Resume")
        XCTAssertTrue(app.staticTexts["playbackCaption"].exists)
        app.buttons["At my pace"].tap()
        app.buttons["playbackOptionsButton"].tap()
        app.buttons["phraseListButton"].tap()
        // Choose the first paragraph; opening its editor stops playback.
        let firstPlaybackParagraph = app.buttons["listenPlaybackParagraph-0"]
        XCTAssertTrue(firstPlaybackParagraph.waitForExistence(timeout: 8))
        firstPlaybackParagraph.tap()
        app.buttons["editPlaybackTranslationButton"].tap()
        let playbackEditor = app.textViews["paragraphEditor"]
        XCTAssertTrue(playbackEditor.waitForExistence(timeout: 5))
        playbackEditor.tap(); playbackEditor.typeText(" Corrección durante audio.")
        app.buttons["saveParagraphCorrection"].tap()
        // The updated text is visible behind the sheet before dismissal completes.
        // Wait for the editor to leave before trying to reopen it.
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: playbackEditor)
        waitForExpectations(timeout: 8)
        let reopen = app.buttons["editPlaybackTranslationButton"]
        expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: reopen)
        waitForExpectations(timeout: 8)
        XCTAssertTrue(app.staticTexts["playbackCaption"].label.contains("Corrección durante audio."))
        let beforeReopen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        beforeReopen.name = "Player-after-saving-correction"; beforeReopen.lifetime = .keepAlways; add(beforeReopen)
        reopen.tap()
        XCTAssertTrue(playbackEditor.waitForExistence(timeout: 10))
        playbackEditor.tap(); playbackEditor.typeText(" DESCARTAR")
        app.navigationBars["Edit translation"].buttons["Cancel"].tap()
        app.buttons["Discard changes"].tap()
        XCTAssertFalse(app.staticTexts["playbackCaption"].label.contains("DESCARTAR"))
        app.navigationBars["Audio & subtitles"].buttons["Done"].tap()
        XCTAssertTrue(paragraph.label.contains("Corrección durante audio."))
        let afterPlayer = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        afterPlayer.name = "Translation-after-player"; afterPlayer.lifetime = .keepAlways; add(afterPlayer)
        let sharing = app.buttons["shareTranslationButton"]
        expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: sharing)
        waitForExpectations(timeout: 8)
        sharing.tap()
        XCTAssertTrue(app.navigationBars["Review & share"].waitForExistence(timeout: 5))
        app.segmentedControls["translationExportFormat"].buttons["SRT"].tap()
        let confirmShare = app.buttons["confirmTranslationShare"]
        for _ in 0..<5 { if confirmShare.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(confirmShare.isHittable)
        confirmShare.tap()
        let saveFile = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Save to Files")).firstMatch
        XCTAssertTrue(saveFile.waitForExistence(timeout: 8))
        let shared = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shared.name = "Spanish-subtitle-share"; shared.lifetime = .keepAlways; add(shared)
    }

    @MainActor
    func testSpanishSearchFindsSavedSession() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-translation"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Sessions"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Sessions"].tap()
        let search = app.searchFields.firstMatch
        if !search.isHittable { app.swipeDown() }
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText("Aprendemos")
        app.staticTexts["Review sample"].tap()
        XCTAssertTrue(app.staticTexts["translatedParagraph-0"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["translatedParagraph-0"].label.contains("Aprendemos"))
    }

    @MainActor
    func testStaleSpanishIsHiddenUntilRetranslation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-translation", "--ui-test-translation-stale"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Sessions"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Sessions"].tap()
        app.staticTexts["Review sample"].tap()
        app.buttons["sessionTranslationButton"].tap()
        XCTAssertTrue(app.staticTexts["translationOutdated"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["translatedParagraph-0"].exists)
        XCTAssertFalse(app.buttons["shareTranslationButton"].isEnabled)
        app.segmentedControls["translationLanguagePicker"].buttons["English"].tap()
        XCTAssertEqual(app.staticTexts["translatedParagraph-0"].label, "The English transcript changed.")
    }

    @MainActor
    func testNoisePreferenceIsAccessibleAndFixedWhilePaused() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-reader", "--ui-test-session-flow"]
        app.launch()
        let quick = app.buttons["quickNoisePreference"]
        XCTAssertTrue(quick.waitForExistence(timeout: 20))
        XCTAssertTrue(quick.isHittable)
        XCTAssertTrue(quick.staticTexts["Reduce noise"].exists)
        XCTAssertTrue(app.buttons["quickAudioPreference"].staticTexts["Save audio"].exists)
        XCTAssertFalse(app.buttons["capturePreferencesButton"].exists)
        XCTAssertEqual(quick.value as? String, "Off")
        quick.tap()
        XCTAssertEqual(quick.value as? String, "On")
        XCTAssertEqual(app.buttons["primaryCaptionAction"].label, "Start Listening")
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "Noise-quick-preference"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["primaryCaptionAction"].tap()
        expectation(for: NSPredicate(format: "label == 'Pause'"), evaluatedWith: app.buttons["primaryCaptionAction"])
        waitForExpectations(timeout: 10)
        app.buttons["primaryCaptionAction"].tap()
        XCTAssertTrue(app.buttons["resumeCaptureButton"].waitForExistence(timeout: 5))
        app.buttons["fullScreenButton"].tap()
        app.buttons["capturePreferencesButton"].tap()
        let toggle = app.switches["noiseReductionToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "1")
        toggle.switches.firstMatch.exists ? toggle.switches.firstMatch.tap() : toggle.tap()
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertTrue(app.staticTexts["Audio saving and noise reduction changes apply to your next session. Background listening can change during this session."].exists)
        let settingsShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        settingsShot.name = "Noise-session-preferences"; settingsShot.lifetime = .keepAlways; add(settingsShot)
        app.buttons["Done"].tap()
        app.buttons["fullScreenButton"].tap()
        app.buttons["resumeCaptureButton"].tap()
        expectation(for: NSPredicate(format: "label == 'Pause'"), evaluatedWith: app.buttons["primaryCaptionAction"])
        waitForExpectations(timeout: 10)
        app.buttons["primaryCaptionAction"].tap()
        XCTAssertTrue(app.buttons["resumeCaptureButton"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Settings"].tap()
        app.buttons["interfaceLanguagePicker"].tap()
        app.buttons["Spanish · Español"].tap()
        app.tabBars.buttons["Subtítulos"].tap()
        app.buttons["fullScreenButton"].tap()
        app.buttons["capturePreferencesButton"].tap()
        XCTAssertTrue(app.switches["noiseReductionToggle"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["noiseReductionToggle"].label.contains("Reducir ruido de fondo"))
        let spanish = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        spanish.name = "Noise-preferences-Spanish"; spanish.lifetime = .keepAlways; add(spanish)
    }

    @MainActor
    func testGlobalCapturePreferencesPersistWithoutStartingMicrophone() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["quickAudioPreference"].waitForExistence(timeout: 20))
        let audio = app.buttons["quickAudioPreference"]
        let background = app.buttons["quickBackgroundPreference"]
        if audio.value as? String == "Off" { audio.tap() }
        if background.value as? String == "Off" { background.tap() }
        XCTAssertEqual(app.buttons["primaryCaptionAction"].label, "Start Recording")
        app.tabBars.buttons["Settings"].tap()
        XCTAssertEqual(app.switches["saveAudioToggle"].value as? String, "1")
        XCTAssertEqual(app.switches["backgroundAudioToggle"].value as? String, "1")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["quickAudioPreference"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.buttons["quickAudioPreference"].value as? String, "On")
        XCTAssertEqual(app.buttons["quickBackgroundPreference"].value as? String, "On")
        XCTAssertEqual(app.buttons["primaryCaptionAction"].label, "Start Recording")
        app.buttons["quickAudioPreference"].tap()
        app.buttons["quickBackgroundPreference"].tap()
    }

    @MainActor
    func testCompactControlsSaveNewSessionAndDiscardDraft() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-reader", "--ui-test-session-flow"]
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launch()
        let primary = app.buttons["primaryCaptionAction"]
        XCTAssertTrue(primary.waitForExistence(timeout: 20))
        XCTAssertEqual(primary.frame.width, 44, accuracy: 1)
        XCTAssertEqual(app.buttons["stopCaptionAction"].frame.width, 44, accuracy: 1)
        app.buttons["quickBackgroundPreference"].tap()
        let startCapture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        startCapture.name = "Compact-capture-controls-portrait"; startCapture.lifetime = .keepAlways; add(startCapture)
        primary.tap()
        expectation(for: NSPredicate(format: "label == 'Pause'"), evaluatedWith: primary)
        waitForExpectations(timeout: 10)
        app.buttons["stopCaptionAction"].tap()
        XCTAssertTrue(app.buttons["saveSessionButton"].waitForExistence(timeout: 10))
        primary.tap()
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["saveSessionButton"].exists)
        app.buttons["saveSessionButton"].tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.buttons["saveSessionButton"])
        waitForExpectations(timeout: 5)
        primary.tap() // saved session: no second confirmation
        XCTAssertTrue(app.buttons["quickAudioPreference"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["quickBackgroundPreference"].value as? String, "On")
        primary.tap()
        expectation(for: NSPredicate(format: "label == 'Pause'"), evaluatedWith: primary)
        waitForExpectations(timeout: 10)
        app.buttons["fullScreenButton"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: app.buttons["stopCaptionAction"])
        waitForExpectations(timeout: 8)
        app.buttons["stopCaptionAction"].tap()
        XCTAssertTrue(app.buttons["discardSessionButton"].waitForExistence(timeout: 10))
        let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        capture.name = "Compact-session-decision-landscape"; capture.lifetime = .keepAlways; add(capture)
        app.buttons["discardSessionButton"].tap()
        app.buttons["Discard Session"].tap()
        XCTAssertTrue(app.buttons["quickAudioPreference"].waitForExistence(timeout: 10))
        app.buttons["fullScreenButton"].tap()
        XCUIDevice.shared.orientation = .portrait
        app.tabBars.buttons["Sessions"].tap()
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Session · ")).count, 1)
        XCTAssertFalse(app.staticTexts["Recovery drafts"].exists)
    }

    @MainActor
    func testPausePinchAndNamedSave() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-reader", "--ui-test-session-flow"]
        app.launch()
        let primary = app.buttons["primaryCaptionAction"]
        XCTAssertTrue(primary.waitForExistence(timeout: 20))
        let reader = app.scrollViews["captionScrollView"]
        reader.pinch(withScale: 1.3, velocity: 1)
        app.buttons["readingOptionsButton"].tap()
        let value = app.sliders["Caption size"].value as? String ?? ""
        XCTAssertNotEqual(value, "28 points")
        app.buttons["Done"].tap()
        primary.tap()
        expectation(for: NSPredicate(format: "label == 'Pause'"), evaluatedWith: primary)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(app.progressIndicators["captureLevelMeter"].exists)
        primary.tap()
        expectation(for: NSPredicate(format: "label == 'Resume'"), evaluatedWith: primary)
        waitForExpectations(timeout: 10)
        XCTAssertFalse(app.progressIndicators["captureLevelMeter"].exists)
        app.buttons["resumeCaptureButton"].tap()
        expectation(for: NSPredicate(format: "label == 'Pause'"), evaluatedWith: primary)
        waitForExpectations(timeout: 10)
        app.buttons["stopCaptionAction"].tap()
        let name = app.textFields["sessionTitleField"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        name.tap()
        app.buttons["clearSessionName"].tap()
        name.typeText("Planning review\n")
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.keyboards.firstMatch)
        waitForExpectations(timeout: 5)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "Save-session-name"; shot.lifetime = .keepAlways; add(shot)
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: app.buttons["saveSessionButton"])
        waitForExpectations(timeout: 8)
        let landscape = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        landscape.name = "Named-session-landscape"; landscape.lifetime = .keepAlways; add(landscape)
        app.buttons["saveSessionButton"].tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.buttons["saveSessionButton"])
        waitForExpectations(timeout: 5)
        XCUIDevice.shared.orientation = .portrait
        expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: app.tabBars.buttons["Sessions"])
        waitForExpectations(timeout: 8)
        app.tabBars.buttons["Sessions"].tap()
        XCTAssertTrue(app.staticTexts["Planning review"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testTapParagraphStartsAudioAndPauseKeepsPosition() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-media"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Sessions"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Sessions"].tap()
        app.staticTexts["Review sample"].tap()
        let paragraph = app.buttons["listenParagraph-0"]
        XCTAssertTrue(paragraph.waitForExistence(timeout: 10))
        paragraph.tap()
        let play = app.buttons["recordingPlayButton"]
        XCTAssertTrue(play.waitForExistence(timeout: 10))
        play.tap()
        expectation(for: NSPredicate(format: "label == 'Pause'"), evaluatedWith: play)
        waitForExpectations(timeout: 10)
        play.tap()
        XCTAssertEqual(play.label, "Resume")
        app.buttons["openParagraphList"].tap()
        let cue = app.buttons["listenPlaybackParagraph-0"]
        for _ in 0..<5 { if cue.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(cue.isHittable)
        cue.tap()
        XCTAssertEqual(play.label, "Play")
        play.tap()
        XCTAssertEqual(play.label, "Pause")
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "Phrase-playback"; shot.lifetime = .keepAlways; add(shot)
        play.tap()
    }

    @MainActor
    func testSavedAudioPlaybackSubtitleExportAndIndependentDeletion() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-media"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Sessions"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Sessions"].tap()
        app.staticTexts["Review sample"].tap()
        app.buttons["sessionMediaButton"].tap()
        XCTAssertTrue(app.navigationBars["Audio & subtitles"].waitForExistence(timeout: 5))
        let play = app.buttons["recordingPlayButton"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        play.tap()
        let caption = app.staticTexts["playbackCaption"]
        XCTAssertTrue(caption.waitForExistence(timeout: 5))
        expectation(for: NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@", "Acmee", "Paragraph"), evaluatedWith: caption)
        waitForExpectations(timeout: 8)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Media-Playback-Portrait"; attachment.lifetime = .keepAlways; add(attachment)
        app.buttons["Full screen"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        XCTAssertTrue(app.buttons["Exit full screen"].waitForExistence(timeout: 5))
        let landscape = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        landscape.name = "Media-Playback-Landscape"; landscape.lifetime = .keepAlways; add(landscape)
        app.buttons["Exit full screen"].tap()
        XCUIDevice.shared.orientation = .portrait
        app.buttons["playbackOptionsButton"].tap()
        app.buttons["editMediaTranscriptButton"].tap()
        XCTAssertTrue(app.buttons["editParagraph-1"].waitForExistence(timeout: 5))
        app.buttons["editParagraph-1"].tap()
        let editor = app.textViews["paragraphEditor"]
        editor.tap()
        editor.typeText(" Audio review correction.")
        app.buttons["Apply"].tap()
        app.buttons["saveTranscriptEdits"].tap()
        XCTAssertTrue(app.navigationBars["Audio & subtitles"].waitForExistence(timeout: 5))
        app.buttons["playbackOptionsButton"].tap()
        let subtitles = app.buttons["Subtitles (SRT)"]
        let actions = app.collectionViews["mediaActionsList"]
        for _ in 0..<24 {
            if subtitles.exists && subtitles.isHittable { break }
            actions.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)).press(forDuration: 0.1,
                thenDragTo: actions.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)),
                withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        XCTAssertTrue(subtitles.exists && subtitles.isHittable)
        subtitles.tap()
        let save = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Save to Files")).firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        // Dismiss the native activity controller explicitly, without sending files.
        let close = app.buttons["Close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        let delete = app.buttons["Delete audio, keep text"]
        for _ in 0..<5 { if delete.isHittable { break }; app.collectionViews["mediaActionsList"].swipeUp() }
        XCTAssertTrue(delete.isHittable)
        delete.tap()
        app.buttons["Delete audio"].tap()
        XCTAssertFalse(play.exists)
        XCTAssertTrue(app.buttons["Subtitles (SRT)"].isEnabled)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["reviewParagraph-0"].exists)
    }

    @MainActor
    func testLaunchShowsCaptionsWithoutRequestingMicrophone() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.scrollViews["captionScrollView"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["captionPlaceholder"].exists)
        XCTAssertTrue(app.buttons["Start Listening"].exists)
        XCTAssertFalse(app.buttons["Stop"].isEnabled)
        XCTAssertFalse(app.alerts.firstMatch.exists)
        XCTAssertFalse(XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch.exists)
        if app.buttons["captionStatusDetails"].exists {
            app.buttons["captionStatusDetails"].tap()
            XCTAssertTrue(app.navigationBars["Session information"].waitForExistence(timeout: 5))
            app.buttons["Done"].tap()
            XCTAssertTrue(app.buttons["primaryCaptionAction"].isHittable)
        }
    }

    @MainActor
    func testReadinessAndPrivacyAreAccessibleFromSettings() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Settings"].tap()
        app.staticTexts["Check preparation"].tap()
        XCTAssertTrue(app.navigationBars["Offline Readiness"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Test Offline Mode"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let privacy = app.staticTexts["Privacy Policy"]
        for _ in 0..<4 {
            if privacy.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(privacy.isHittable)
        privacy.tap()
        XCTAssertTrue(app.navigationBars["Privacy"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testMicrophoneDiagnosticRemainsAvailable() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Settings"].tap()
        app.staticTexts["Microphone Check"].tap()
        XCTAssertTrue(app.staticTexts["Microphone capture"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Start Listening"].exists)
        XCTAssertFalse(app.buttons["Stop"].isEnabled)
    }

    @MainActor
    func testReadingOptionsDoNotOccupyTheReader() throws {
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        let reader = app.scrollViews["captionScrollView"]
        XCTAssertTrue(reader.waitForExistence(timeout: 15))
        XCTAssertFalse(app.sliders["Caption size"].exists)
        let originalFrame = reader.frame
        app.buttons["readingOptionsButton"].tap()
        XCTAssertTrue(app.navigationBars["Reading options"].waitForExistence(timeout: 5))
        let slider = app.sliders["Caption size"]
        XCTAssertTrue(slider.exists)
        slider.adjust(toNormalizedSliderPosition: 0)
        XCTAssertEqual(slider.value as? String, "14 points")
        let selectedSize = slider.value as? String
        app.buttons["Done"].tap()
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        XCTAssertEqual(reader.frame.height, originalFrame.height, accuracy: 2)
        XCTAssertTrue(app.buttons["primaryCaptionAction"].isHittable)
        app.buttons["readingOptionsButton"].tap()
        XCTAssertEqual(app.sliders["Caption size"].value as? String, selectedSize)
        slider.adjust(toNormalizedSliderPosition: 1)
        XCTAssertEqual(slider.value as? String, "60 points")
        slider.adjust(toNormalizedSliderPosition: 14.0 / 46.0)
        app.buttons["Done"].tap()
        app.buttons["sessionActionsButton"].tap()
        XCTAssertTrue(app.buttons["Reading options"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["New Session"].exists)
        XCTAssertFalse(app.buttons["Session information"].exists)
        XCTAssertFalse(app.buttons["Full screen"].exists)
        // iOS may omit disabled actions from a confirmation dialog.
        let save = app.buttons["Save Session"]
        if save.exists { XCTAssertFalse(save.isEnabled) }
        app.buttons["Cancel"].tap()
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
    }

    @MainActor
    func testReaderUsesMostOfScreenInBothOrientations() throws {
        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launch()
        let reader = app.scrollViews["captionScrollView"]
        XCTAssertTrue(reader.waitForExistence(timeout: 15))
        for orientation: UIDeviceOrientation in [.portrait, .landscapeLeft, .landscapeRight, .portrait] {
            XCUIDevice.shared.orientation = orientation
            let landscape = orientation == .landscapeLeft || orientation == .landscapeRight
            let expectedShape = NSPredicate { _, _ in
                let frame = app.windows.firstMatch.frame
                return landscape ? frame.width > frame.height : frame.height > frame.width
            }
            expectation(for: expectedShape, evaluatedWith: app)
            waitForExpectations(timeout: 10)
            XCTAssertTrue(app.buttons["primaryCaptionAction"].isHittable)
            XCTAssertTrue(app.buttons["readingOptionsButton"].isHittable)
            XCTAssertTrue(app.buttons["sessionActionsButton"].isHittable)
            XCTAssertTrue(app.staticTexts["captionPlaceholder"].exists)
            XCTAssertGreaterThan(reader.frame.height / app.windows.firstMatch.frame.height, landscape ? 0.45 : 0.55)
            let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screenshot.name = "Reader-\(orientation.rawValue)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
        app.tabBars.buttons["Sessions"].tap()
        app.tabBars.buttons["Captions"].tap()
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
    }

    @MainActor
    func testFullScreenKeepsListeningAndRestoresTabsAfterRotation() throws {
        let app = XCUIApplication()
        // Use a scrollable short history, then live arrivals every two seconds.
        // The 320-paragraph stress fixture races snapshot queries while it loads.
        app.launchArguments = ["--ui-test-reader", "--ui-test-session-flow"]
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launch()
        let reader = app.scrollViews["captionScrollView"]
        XCTAssertTrue(reader.waitForExistence(timeout: 15))
        app.buttons["primaryCaptionAction"].tap()
        XCTAssertTrue(app.buttons["primaryCaptionAction"].waitForExistence(timeout: 5))
        XCTAssertTrue(reader.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Paragraph 8.")).firstMatch.waitForExistence(timeout: 15))
        let originalHeight = reader.frame.height
        app.buttons["fullScreenButton"].tap()
        XCTAssertEqual(app.buttons["primaryCaptionAction"].label, "Pause")
        XCTAssertFalse(app.tabBars.buttons["Settings"].isHittable)
        XCTAssertGreaterThan(reader.frame.height, originalHeight + 40)
        for orientation: UIDeviceOrientation in [.portrait, .landscapeLeft, .landscapeRight] {
            XCUIDevice.shared.orientation = orientation
            let landscape = orientation != .portrait
            expectation(for: NSPredicate { _, _ in
                let frame = app.windows.firstMatch.frame
                let rotated = landscape ? frame.width > frame.height : frame.height > frame.width
                return rotated && app.buttons["fullScreenButton"].isHittable
            }, evaluatedWith: app)
            waitForExpectations(timeout: 8)
            XCTAssertTrue(app.buttons["fullScreenButton"].isHittable)
            XCTAssertTrue(app.buttons["primaryCaptionAction"].isHittable)
            expectation(for: NSPredicate { _, _ in
                let count = (reader.value as? String ?? "").components(separatedBy: " ").first ?? ""
                let latest = reader.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Paragraph \(count).")).firstMatch
                // This is noninteractive text moving as new captions arrive. XCTest can
                // reject its activation point during scrolling; visibility is the contract.
                guard latest.exists else { return false }
                let visible = reader.frame.intersection(latest.frame)
                return !visible.isNull && visible.height > 0 && visible.width > 0
            }, evaluatedWith: reader)
            waitForExpectations(timeout: 8)
            let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            capture.name = "Reader-Fullscreen-\(orientation.rawValue)"
            capture.lifetime = .keepAlways
            add(capture)
        }
        app.buttons["primaryCaptionAction"].tap()
        expectation(for: NSPredicate(format: "label == 'Resume'"), evaluatedWith: app.buttons["primaryCaptionAction"])
        waitForExpectations(timeout: 5)
        app.buttons["fullScreenButton"].tap()
        XCTAssertTrue(app.tabBars.buttons["Sessions"].isHittable)
        app.tabBars.buttons["Sessions"].tap()
        app.tabBars.buttons["Captions"].tap()
        XCTAssertEqual(app.buttons["primaryCaptionAction"].label, "Resume")
    }

    @MainActor
    func testRereadingStaysInPlaceAsNewCaptionsArriveAndReturnsToLive() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-reader"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        let reader = app.scrollViews["captionScrollView"]
        XCTAssertTrue(reader.waitForExistence(timeout: 15))
        app.buttons["primaryCaptionAction"].tap()
        // Wait for rendered live text, rather than a transient accessibility
        // scroll value while SwiftUI is laying out the initial 320 paragraphs.
        let incoming = reader.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@", "New captions keep arriving while you read.")).firstMatch
        // The fixture inserts and persists 320 paragraphs before emitting this text.
        // Wait for the actual result; this is not a production speech-latency assertion.
        XCTAssertTrue(incoming.waitForExistence(timeout: 120))
        reader.swipeDown()
        XCTAssertTrue(app.buttons["backToLiveButton"].waitForExistence(timeout: 5))
        let visible = reader.staticTexts.allElementsBoundByIndex.first {
            $0.label.hasPrefix("Paragraph ") && reader.frame.contains($0.frame)
        }
        let paragraph = try XCTUnwrap(visible)
        let oldY = paragraph.frame.minY
        let oldValue = reader.value as? String
        expectation(for: NSPredicate { _, _ in (reader.value as? String) != oldValue }, evaluatedWith: reader)
        waitForExpectations(timeout: 8)
        XCTAssertTrue(paragraph.isHittable)
        XCTAssertEqual(paragraph.frame.minY, oldY, accuracy: 3)
        XCTAssertEqual(app.buttons["primaryCaptionAction"].label, "Pause")
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "liveBookmark-")).firstMatch.exists)
        app.buttons["backToLiveButton"].tap()
        XCTAssertFalse(app.buttons["backToLiveButton"].exists)
        XCTAssertTrue((reader.value as? String)?.contains("Following live captions") == true)
        app.buttons["primaryCaptionAction"].tap()
        expectation(for: NSPredicate(format: "label == 'Resume'"), evaluatedWith: app.buttons["primaryCaptionAction"])
        waitForExpectations(timeout: 5)
        let count = (reader.value as? String ?? "").components(separatedBy: " ").first ?? ""
        let latest = reader.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Paragraph \(count).")).firstMatch
        XCTAssertTrue(latest.isHittable)
        XCTAssertLessThanOrEqual(latest.frame.maxY, reader.frame.maxY + 2)
    }

    @MainActor
    private func openReviewSample(_ app: XCUIApplication) {
        XCTAssertTrue(app.tabBars.buttons["Sessions"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Sessions"].tap()
        app.staticTexts["Review sample"].tap()
        XCTAssertTrue(app.buttons["editTranscriptButton"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testEditingReplacementAndPreviewShareTheCorrectedText() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        openReviewSample(app)
        app.buttons["editTranscriptButton"].tap()
        app.buttons["editParagraph-1"].tap()
        let editor = app.textViews["paragraphEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText(" Reviewed note.")
        app.buttons["Apply"].tap()
        XCTAssertTrue(app.buttons["editParagraph-1"].label.contains("Reviewed note."))
        app.buttons["undoTranscriptEdit"].tap()
        XCTAssertFalse(app.buttons["editParagraph-1"].label.contains("Reviewed note."))
        app.buttons["Redo"].tap()
        XCTAssertTrue(app.buttons["editParagraph-1"].label.contains("Reviewed note."))
        let editCapture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        editCapture.name = "Review-Editor"
        editCapture.lifetime = .keepAlways
        add(editCapture)
        app.buttons["findReplaceButton"].tap()
        app.textFields["findText"].tap()
        app.textFields["findText"].typeText("Acmee")
        app.textFields["replacementText"].tap()
        app.textFields["replacementText"].typeText("Acme")
        app.buttons["Preview matches"].tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.keyboards.firstMatch)
        waitForExpectations(timeout: 5)
        let findCapture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        findCapture.name = "Review-Find-replace"
        findCapture.lifetime = .keepAlways
        add(findCapture)
        app.buttons["Replace all"].tap()
        app.buttons["Replace 2 matches"].tap()
        app.buttons["Done"].tap()
        app.buttons["saveTranscriptEdits"].tap()
        XCTAssertTrue(app.staticTexts["reviewParagraph-0"].label.contains("Acme makes"))
        XCTAssertTrue(app.staticTexts["reviewParagraph-0"].label.contains("Acmees stays unchanged"))
        app.buttons["reviewShareButton"].tap()
        let preview = app.staticTexts["exportPreviewText"]
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
        XCTAssertTrue(preview.label.contains("Reviewed note."))
        XCTAssertFalse(app.segmentedControls["exportContentPicker"].exists)
        XCTAssertTrue(preview.label.contains("Acme makes"))
        XCTAssertTrue(preview.label.contains("Paragraph 2."))
        let details = app.switches["Session details"]
        details.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        expectation(for: NSPredicate(format: "value == '0'"), evaluatedWith: details)
        waitForExpectations(timeout: 5)
        expectation(for: NSPredicate(format: "NOT label CONTAINS %@", "Language:"), evaluatedWith: preview)
        waitForExpectations(timeout: 5)
        app.buttons["Copy"].tap()
        XCTAssertTrue(app.buttons["Copied"].exists)
        app.segmentedControls.buttons["PDF"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["pdfPreview"].waitForExistence(timeout: 15))
        let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        capture.name = "Review-PDF-preview"
        capture.lifetime = .keepAlways
        add(capture)
        app.buttons["Share"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Save to Files")).firstMatch.waitForExistence(timeout: 8))
        let shareCapture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shareCapture.name = "Review-Native-share"
        shareCapture.lifetime = .keepAlways
        add(shareCapture)
    }

    @MainActor
    func testDiscardAndRestoreOriginalWithoutBookmarkNavigation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-reviewed"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        openReviewSample(app)
        app.buttons["editTranscriptButton"].tap()
        app.buttons["restoreOriginalDraft"].tap()
        app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "Restore original", "restoreOriginalDraft")).firstMatch.tap()
        app.buttons["Cancel"].tap()
        app.buttons["Discard changes"].tap()
        XCTAssertEqual(app.staticTexts["reviewParagraph-0"].label, "Acme corrected draft.")
        app.buttons["editTranscriptButton"].tap()
        app.buttons["restoreOriginalDraft"].tap()
        app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "Restore original", "restoreOriginalDraft")).firstMatch.tap()
        app.buttons["saveTranscriptEdits"].tap()
        XCTAssertTrue(app.staticTexts["reviewParagraph-0"].label.contains("Acmee makes"))
        XCTAssertFalse(app.buttons["Bookmarks"].exists)
        app.navigationBars.buttons["Sessions"].tap()
        app.staticTexts["Review sample"].tap()
        XCTAssertTrue(app.staticTexts["reviewParagraph-0"].label.contains("Acmee makes"))

    }

    @MainActor
    func testNewSessionIsACircleAndReclaimsReaderSpace() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-reader"]
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launch()
        let reader = app.scrollViews["captionScrollView"]
        XCTAssertTrue(reader.waitForExistence(timeout: 15))
        app.buttons["primaryCaptionAction"].tap()
        expectation(for: NSPredicate(format: "label == 'Pause'"), evaluatedWith: app.buttons["primaryCaptionAction"])
        waitForExpectations(timeout: 10)
        let incoming = reader.staticTexts.matching(NSPredicate(
            format: "label CONTAINS %@", "New captions keep arriving while you read.")).firstMatch
        XCTAssertTrue(incoming.waitForExistence(timeout: 20))
        let listeningHeight = reader.frame.height
        app.buttons["Stop"].tap()
        XCTAssertTrue(app.buttons["saveSessionButton"].waitForExistence(timeout: 10))
        app.buttons["saveSessionButton"].tap()
        let action = app.buttons["primaryCaptionAction"]
        expectation(for: NSPredicate(format: "label == 'New Session'"), evaluatedWith: action)
        waitForExpectations(timeout: 10)
        XCTAssertEqual(action.frame.width, 44, accuracy: 1)
        XCTAssertEqual(action.frame.height, 44, accuracy: 1)
        XCTAssertGreaterThan(reader.frame.height, listeningHeight + 40)
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.buttons["Stop"])
        waitForExpectations(timeout: 5)
        let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        capture.name = "Review-New-session-circle"
        capture.lifetime = .keepAlways
        add(capture)
        app.buttons["fullScreenButton"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: action)
        waitForExpectations(timeout: 8)
        action.tap() // Already saved: one tap prepares the next session.
        XCTAssertTrue(app.staticTexts["captionPlaceholder"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testOngoingSessionRequiresStoppingBeforeEditing() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-reader"]
        app.launch()
        XCTAssertTrue(app.buttons["primaryCaptionAction"].waitForExistence(timeout: 15))
        app.buttons["primaryCaptionAction"].tap()
        expectation(for: NSPredicate(format: "label == 'Pause'"), evaluatedWith: app.buttons["primaryCaptionAction"])
        waitForExpectations(timeout: 10)
        app.tabBars.buttons["Sessions"].tap()
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Session · ")).firstMatch.tap()
        XCTAssertFalse(app.buttons["editTranscriptButton"].isEnabled)
        app.buttons["reviewShareButton"].tap()
        XCTAssertFalse(app.buttons["editFromPreview"].isEnabled)
        app.buttons["Done"].tap()
        app.tabBars.buttons["Captions"].tap()
        app.buttons["Stop"].tap()
    }

}
