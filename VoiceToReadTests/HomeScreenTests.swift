import XCTest

final class HomeScreenTests: XCTestCase {
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
        app.buttons["Write a response"].tap()
        let editor = app.textViews["writtenResponseText"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap(); editor.typeText("Please speak slowly. I am reading your words. Thank you for waiting while I write my response.")
        app.buttons["speakWrittenResponse"].tap()
        XCTAssertEqual(app.buttons["speakWrittenResponse"].label, "Pause")
        app.buttons["speakWrittenResponse"].tap()
        XCTAssertEqual(app.buttons["speakWrittenResponse"].label, "Resume")
        app.buttons["Stop"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Write a response"].tap()
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
        app.buttons["recentlyDeletedLink"].tap()
        app.buttons["restoreDeletedSession"].tap()
        XCTAssertTrue(app.staticTexts["No deleted sessions"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'sessionActions-'")).firstMatch.tap()
        app.buttons["deleteSessionAction"].tap(); app.buttons["confirmDeleteSession"].tap()
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
        XCTAssertTrue(app.buttons["Before a meeting or class"].waitForExistence(timeout: 20))
        app.buttons["Before a meeting or class"].tap()
        XCTAssertTrue(app.navigationBars["Offline Readiness"].waitForExistence(timeout: 5))
        app.buttons["See a short demonstration"].tap()
        XCTAssertTrue(app.staticTexts["Demonstration · no recording"].waitForExistence(timeout: 5))
        app.navigationBars["Quick guide"].buttons["Done"].tap()
        app.navigationBars["Offline Readiness"].buttons["Done"].tap()
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
        app.buttons["Español"].tap()
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
        row.swipeLeft()
        let protect = app.buttons["protectSessionAction"]
        XCTAssertTrue(protect.waitForExistence(timeout: 5))
        let delete = app.buttons["deleteSessionAction"]
        XCTAssertTrue(delete.isEnabled)
        protect.tap()
        XCTAssertFalse(delete.isEnabled)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "Protected-circular-actions"; shot.lifetime = .keepAlways; add(shot)
        protect.tap()
        app.buttons["confirmRemoveSessionProtection"].tap()
        XCTAssertTrue(delete.isEnabled)
        XCTAssertTrue(row.exists, "Removing protection must preserve the session")
        delete.tap()
        app.buttons["confirmDeleteSession"].tap()
        XCTAssertFalse(row.waitForExistence(timeout: 2))
    }


    @MainActor
    func testVisibleBookmarksSaveRemoveAndReopen() throws {
        let app = XCUIApplication(); app.launchArguments = ["--ui-test-review", "--ui-test-translation"]
        app.launch(); XCTAssertTrue(app.tabBars.buttons["Sessions"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Sessions"].tap(); app.staticTexts["Review sample"].tap()
        let mark = app.buttons["savedBookmark-0"]
        XCTAssertTrue(mark.waitForExistence(timeout: 5))
        if mark.label == "Remove bookmark" { mark.tap() }
        mark.tap(); XCTAssertEqual(mark.label, "Remove bookmark")
        app.buttons["Bookmarks"].tap()
        XCTAssertFalse(app.staticTexts["No bookmarks yet"].exists)
        let noteButton = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "noteBookmark-")).firstMatch
        XCTAssertTrue(noteButton.waitForExistence(timeout: 5)); noteButton.tap()
        let note = app.descendants(matching: .any).matching(identifier: "bookmarkNoteInput").firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 5)); note.tap(); note.typeText("Practise tomorrow")
        app.navigationBars["Bookmark note"].buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Practise tomorrow"].waitForExistence(timeout: 5))
        let listen = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "listenBookmark-")).firstMatch
        XCTAssertTrue(listen.isEnabled); listen.tap(); XCTAssertEqual(listen.label, "Stop"); listen.tap()
        app.navigationBars["Bookmarks"].buttons["Done"].tap()
        app.buttons["sessionTranslationButton"].tap()
        let translated = app.buttons["translationBookmark-0"]
        XCTAssertTrue(translated.waitForExistence(timeout: 5)); XCTAssertEqual(translated.label, "Remove bookmark")
        translated.tap(); XCTAssertEqual(translated.label, "Save bookmark")
        app.navigationBars["Translation"].buttons["Done"].tap()
        XCTAssertEqual(mark.label, "Save bookmark")
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
        let play = app.buttons["playTranslationParagraph-0"]
        XCTAssertTrue(play.waitForExistence(timeout: 8)); play.tap()
        XCTAssertFalse(app.buttons["recordingPlayButton"].exists, "Inline listening must not open another player")
        XCTAssertEqual(play.label, "Pause")
        play.tap(); XCTAssertEqual(play.label, "Resume")
        app.buttons["stopTranslationParagraph-0"].tap()
        XCTAssertEqual(play.label, "Listen to translation")
        app.segmentedControls["translationLanguagePicker"].buttons["Both"].tap()
        XCTAssertEqual(play.label, "Listen to both")
        play.tap(); XCTAssertEqual(play.label, "Pause")
        XCTAssertEqual(app.staticTexts["inlinePlaybackStatus"].label, "Playing original")
        app.buttons["stopTranslationParagraph-0"].tap()
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "Inline-bilingual-paragraph"; shot.lifetime = .keepAlways; add(shot)
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
        let bookmarkID = translated.identifier.replacingOccurrences(of: "liveTranslated-", with: "liveBookmark-")
        let mark = app.buttons[bookmarkID]
        XCTAssertTrue(mark.exists)
        mark.tap(); XCTAssertEqual(mark.label, "Remove bookmark")
        mark.tap(); XCTAssertEqual(mark.label, "Save bookmark")
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
        app.buttons["editPlaybackParagraphButton"].tap()
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
            app.frame.width > app.frame.height && app.buttons["editPlaybackParagraphButton"].isHittable
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
        app.buttons["Español"].tap()
        XCTAssertTrue(app.tabBars.buttons["Ajustes"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Ajustes"].exists)
        XCTAssertTrue(app.buttons["captureLanguagePicker"].label.contains("English"))
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "Separate-interface-and-capture-languages"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["captureLanguagePicker"].tap()
        app.buttons["Español"].tap()
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
        app.buttons["Español"].tap()
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
        app.buttons["Español"].tap()
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
    func testSpanishSessionTranslationAndPractice() throws {
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
        app.segmentedControls["translationLanguagePicker"].buttons["Español"].tap()
        XCTAssertEqual(paragraph.label, "Hola mundo. Aprendemos juntos.")
        app.buttons["Done"].tap()
        app.buttons["learnEnglishButton"].tap()
        XCTAssertTrue(app.navigationBars["Language practice"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["learningEnglish"].label, "Hola mundo. Aprendemos juntos.")
        app.buttons["revealLearningSpanish"].tap()
        XCTAssertEqual(app.staticTexts["learningSpanish"].label, "Hello world. We learn together.")
        let pronunciation = app.buttons["practicePronunciation"]
        if !pronunciation.isHittable { app.swipeUp() }
        pronunciation.tap()
        XCTAssertTrue(app.staticTexts["pronunciationTarget"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["pronunciationTarget"].label.contains("Hola"))
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "Spanish-pronunciation"; shot.lifetime = .keepAlways; add(shot)
        app.navigationBars["Pronunciation"].buttons["Done"].tap()
    }

    @MainActor
    func testPronunciationPracticeRecordsReplaysAndDiscards() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-media", "--ui-test-translation"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Sessions"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Sessions"].tap()
        app.staticTexts["Review sample"].tap()
        app.buttons["learnEnglishButton"].tap()
        let entry = app.buttons["practicePronunciation"]
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        if !entry.isHittable { app.swipeUp() }
        entry.tap()
        XCTAssertTrue(app.staticTexts["pronunciationTarget"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["pronunciationReplay"].exists)
        XCTAssertFalse(app.alerts.firstMatch.exists) // Opening does not request microphone access.
        app.switches["pronunciationSlow"].tap()
        let before = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        before.name = "Pronunciation-ready"; before.lifetime = .keepAlways; add(before)
        app.buttons["pronunciationRecord"].tap()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if system.alerts.firstMatch.waitForExistence(timeout: 3) {
            let allow = system.alerts.buttons["Allow"]
            if allow.exists { allow.tap() } else { system.alerts.buttons["OK"].tap() }
        }
        expectation(for: NSPredicate(format: "label == 'Finish'"), evaluatedWith: app.buttons["pronunciationRecord"])
        waitForExpectations(timeout: 10)
        // UI actions consume enough time to produce a valid (possibly silent) test take.
        let recording = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        recording.name = "Pronunciation-recording"; recording.lifetime = .keepAlways; add(recording)
        app.buttons["pronunciationRecord"].tap()
        let replay = app.buttons["pronunciationReplay"]
        XCTAssertTrue(replay.waitForExistence(timeout: 5))
        if !replay.isHittable { app.swipeUp() }
        replay.tap()
        let result = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        result.name = "Pronunciation-compare"; result.lifetime = .keepAlways; add(result)
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let landscape = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        landscape.name = "Pronunciation-landscape"; landscape.lifetime = .keepAlways; add(landscape)
        app.navigationBars["Pronunciación"].buttons["Listo"].tap()
        XCUIDevice.shared.orientation = .portrait
        if !entry.isHittable { app.swipeUp() }
        entry.tap()
        XCTAssertTrue(app.staticTexts["pronunciationTarget"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["pronunciationReplay"].exists)
        XCTAssertFalse(app.staticTexts["pronunciationHeard"].exists)
        app.buttons["pronunciationPrompt"].tap()
        app.buttons["useful"].tap()
        XCTAssertEqual(app.staticTexts["pronunciationTarget"].label, "useful")
        app.navigationBars["Pronunciación"].buttons["Listo"].tap()
    }

    @MainActor
    func testEnglishLearningRevealSaveAndReplay() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-review", "--ui-test-media", "--ui-test-translation"]
        app.launch()
        XCTAssertTrue(app.buttons["capturePreferencesButton"].waitForExistence(timeout: 20))
        app.buttons["capturePreferencesButton"].tap()
        XCTAssertTrue(app.switches["saveAudioToggle"].waitForExistence(timeout: 5))
        app.navigationBars["Capture preferences"].buttons["Done"].tap()
        app.tabBars.buttons["Sessions"].tap()
        app.staticTexts["Review sample"].tap()
        app.buttons["learnEnglishButton"].tap()
        XCTAssertTrue(app.staticTexts["learningEnglish"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["learningSpanish"].exists)
        app.buttons["revealLearningSpanish"].tap()
        XCTAssertTrue(app.staticTexts["learningSpanish"].exists)
        app.buttons["learningSpeed"].tap()
        app.buttons["Slow"].tap()
        app.switches["learningRepeat"].tap()
        app.buttons["recordingPlayButton"].tap()
        XCTAssertEqual(app.buttons["recordingPlayButton"].label, "Pause")
        app.buttons["recordingPlayButton"].tap()
        app.buttons["saveLearningExpression"].tap()
        app.buttons["confirmLearningExpression"].tap()
        app.segmentedControls["learningCollection"].buttons["Saved expressions"].tap()
        XCTAssertTrue(app.staticTexts["learningEnglish"].exists)
        XCTAssertFalse(app.staticTexts["learningSpanish"].exists)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Saved-learning-expression"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.navigationBars["Language practice"].buttons["Done"].tap()
        app.buttons["learnEnglishButton"].tap()
        app.segmentedControls["learningCollection"].buttons["Saved expressions"].tap()
        XCTAssertTrue(app.staticTexts["learningEnglish"].exists)
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
        app.segmentedControls["translationLanguagePicker"].buttons["Español"].tap()
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
        play.tap()
        expectation(for: NSPredicate(format: "label == 'Pause'"), evaluatedWith: play)
        waitForExpectations(timeout: 8)
        play.tap()
        XCTAssertEqual(play.label, "Resume")
        XCTAssertTrue(app.staticTexts["playbackCaption"].exists)
        app.buttons["At my pace"].tap()
        app.buttons["playbackOptionsButton"].tap()
        app.buttons["phraseListButton"].tap()
        // Explicitly choose the first paragraph without starting audio.
        let firstPlaybackParagraph = app.buttons["listenPlaybackParagraph-0"]
        XCTAssertTrue(firstPlaybackParagraph.waitForExistence(timeout: 8))
        firstPlaybackParagraph.tap()
        app.buttons["editPlaybackParagraphButton"].tap()
        let playbackEditor = app.textViews["paragraphEditor"]
        XCTAssertTrue(playbackEditor.waitForExistence(timeout: 5))
        playbackEditor.tap(); playbackEditor.typeText(" Corrección durante audio.")
        app.buttons["saveParagraphCorrection"].tap()
        XCTAssertTrue(app.staticTexts["playbackCaption"].label.contains("Corrección durante audio."))
        app.buttons["editPlaybackParagraphButton"].tap()
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
        app.buttons["resumeCaptureButton"].tap()
        expectation(for: NSPredicate(format: "label == 'Pause'"), evaluatedWith: app.buttons["primaryCaptionAction"])
        waitForExpectations(timeout: 10)
        app.buttons["primaryCaptionAction"].tap()
        XCTAssertTrue(app.buttons["resumeCaptureButton"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Settings"].tap()
        app.buttons["interfaceLanguagePicker"].tap()
        app.buttons["Español"].tap()
        app.tabBars.buttons["Subtítulos"].tap()
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
        app.staticTexts["Offline Readiness"].tap()
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
        slider.adjust(toNormalizedSliderPosition: 0.75)
        let selectedSize = slider.value as? String
        app.buttons["Done"].tap()
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        XCTAssertEqual(reader.frame.height, originalFrame.height, accuracy: 2)
        XCTAssertTrue(app.buttons["primaryCaptionAction"].isHittable)
        app.buttons["readingOptionsButton"].tap()
        XCTAssertEqual(app.sliders["Caption size"].value as? String, selectedSize)
        slider.adjust(toNormalizedSliderPosition: 1.0 / 3.0)
        app.buttons["Done"].tap()
        app.buttons["sessionActionsButton"].tap()
        XCTAssertTrue(app.buttons["New Session"].waitForExistence(timeout: 5))
        // iOS may omit disabled actions from a confirmation dialog.
        let save = app.buttons["Save Session"]
        if save.exists { XCTAssertFalse(save.isEnabled) }
        app.buttons["Session information"].tap()
        XCTAssertTrue(app.navigationBars["Session information"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
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
        app.launchArguments = ["--ui-test-reader"]
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        app.launch()
        let reader = app.scrollViews["captionScrollView"]
        XCTAssertTrue(reader.waitForExistence(timeout: 15))
        app.buttons["primaryCaptionAction"].tap()
        XCTAssertTrue(app.buttons["primaryCaptionAction"].waitForExistence(timeout: 5))
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
                return latest.exists && latest.isHittable
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
        let label = paragraph.label
        let oldY = paragraph.frame.minY
        let oldValue = reader.value as? String
        expectation(for: NSPredicate { _, _ in (reader.value as? String) != oldValue }, evaluatedWith: reader)
        waitForExpectations(timeout: 8)
        XCTAssertTrue(paragraph.isHittable)
        XCTAssertEqual(paragraph.frame.minY, oldY, accuracy: 3)
        XCTAssertEqual(app.buttons["primaryCaptionAction"].label, "Pause")
        let markerID = paragraph.identifier.replacingOccurrences(of: "caption-", with: "liveBookmark-")
        let saveMarker = app.buttons[markerID]
        XCTAssertTrue(saveMarker.exists)
        saveMarker.tap()
        XCTAssertEqual(saveMarker.label, "Remove bookmark")
        app.buttons["sessionActionsButton"].tap()
        app.buttons["Bookmarks"].tap()
        XCTAssertTrue(app.staticTexts[label].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
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
        app.segmentedControls["exportContentPicker"].buttons["Bookmarks"].tap()
        XCTAssertTrue(preview.label.contains("Acme makes"))
        XCTAssertFalse(preview.label.contains("Paragraph 2."))
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
    func testDiscardRestoreOriginalAndResumeReadingFromBookmark() throws {
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
        app.buttons["Bookmarks"].tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Paragraph 80.")).firstMatch.tap()
        let last = app.staticTexts["reviewParagraph-79"]
        expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: last)
        waitForExpectations(timeout: 10)
        app.navigationBars.buttons["Sessions"].tap()
        app.staticTexts["Review sample"].tap()
        expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: last)
        waitForExpectations(timeout: 10)
        let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        capture.name = "Review-Restored-position"
        capture.lifetime = .keepAlways
        add(capture)
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
