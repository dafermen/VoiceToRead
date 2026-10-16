import XCTest
import UIKit
import CoreText
@testable import VoiceToRead

@MainActor
final class AppSettingsTests: XCTestCase {
    func testAccessiblePreferencesPersistWithoutChangingCaptureLanguage() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        XCTAssertFalse(settings.simpleMode); XCTAssertFalse(settings.showButtonNames)
        settings.simpleMode = true; settings.showButtonNames = true
        settings.focusedReading = true; settings.pauseHaptics = false; settings.preparationSeen = true
        let restored = AppSettings(defaults: defaults)
        XCTAssertTrue(restored.simpleMode && restored.showButtonNames && restored.focusedReading && restored.preparationSeen)
        XCTAssertFalse(restored.pauseHaptics)
        XCTAssertEqual(restored.captureLanguage, .english)
    }

    func testPreferencesPersistAndInvalidValuesUseSafeDefaults() {
        let name = "VoiceToReadTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(200, forKey: "captionSize")
        defaults.set("invalid", forKey: "appearance")
        let settings = AppSettings(defaults: defaults)
        XCTAssertTrue(settings.saveAudio)
        XCTAssertFalse(settings.continueInBackground)
        XCTAssertEqual(settings.captionSize, 44)
        XCTAssertEqual(settings.appearance, .system)
        settings.lineSpacing = 12
        settings.boldCaptions = true
        settings.highContrast = true
        settings.saveAudio = true
        settings.continueInBackground = true
        settings.keepAwake = false
        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.lineSpacing, 12)
        XCTAssertTrue(reloaded.boldCaptions)
        XCTAssertTrue(reloaded.highContrast)
        XCTAssertTrue(reloaded.saveAudio)
        XCTAssertTrue(reloaded.continueInBackground)
        XCTAssertFalse(reloaded.keepAwake)
    }

    func testCaptureLanguageAndPaperPersistWithEnglishDefault() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.captureLanguage, .english)
        XCTAssertEqual(settings.readerPaper, .system)
        XCTAssertFalse(settings.ruledPaper)
        settings.captureLanguage = .spanish; settings.readerPaper = .purple; settings.ruledPaper = true
        let restored = AppSettings(defaults: defaults)
        XCTAssertEqual(restored.captureLanguage, .spanish)
        XCTAssertEqual(restored.transcriptionLanguage, "es-ES")
        XCTAssertEqual(restored.readerPaper, .purple); XCTAssertTrue(restored.ruledPaper)
        defaults.set("unknown", forKey: "captureLanguage"); defaults.set("unknown", forKey: "readerPaper")
        XCTAssertEqual(AppSettings(defaults: defaults).captureLanguage, .english)
        XCTAssertEqual(AppSettings(defaults: defaults).readerPaper, .system)
    }

    func testAudioDefaultMigrationPreservesExistingChoices() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        AppSettings.registerAudioDefault(existingInstallation: true, defaults: defaults)
        XCTAssertFalse(AppSettings(defaults: defaults).saveAudio)
        AppSettings.registerAudioDefault(existingInstallation: false, defaults: defaults)
        XCTAssertFalse(AppSettings(defaults: defaults).saveAudio)
        defaults.removeObject(forKey: "saveAudio")
        AppSettings.registerAudioDefault(existingInstallation: false, defaults: defaults)
        XCTAssertTrue(AppSettings(defaults: defaults).saveAudio)
        AppSettings.registerAudioDefault(existingInstallation: true, defaults: defaults)
        XCTAssertTrue(AppSettings(defaults: defaults).saveAudio)
    }

    func testInterfaceLanguagePersistsIndependentlyOfSpokenLanguage() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.interfaceLanguage, .english)
        settings.interfaceLanguage = .spanish
        XCTAssertEqual(settings.captureLanguage, .english)
        settings.captureLanguage = .spanish
        settings.interfaceLanguage = .english
        let restored = AppSettings(defaults: defaults)
        XCTAssertEqual(restored.interfaceLanguage, .english)
        XCTAssertEqual(restored.captureLanguage, .spanish)
        defaults.set("unknown", forKey: "interfaceLanguage")
        XCTAssertEqual(AppSettings(defaults: defaults).interfaceLanguage, .english)
        XCTAssertEqual(InterfaceLocalization.string("Save Session", language: .spanish), "Guardar sesión")
        XCTAssertEqual(InterfaceLocalization.string("Practicar idioma", language: .english), "Language practice")
    }

    func testNotebookRulesReflowBelowGlyphsWithoutOverlappingNextLine() {
        let view = NotebookTextView()
        let text = "Reading gyp. Pause and resume without moving the rules. A longer paragraph wraps on narrow screens.\nNext paragraph with descenders: gyjpq."
        for size: CGFloat in [20, 28, 44, 70] {
            for spacing: Double in [0, 4, 16] {
                view.configure(text: text, points: size, spacing: spacing, bold: true, dark: false)
                var heights: [CGFloat] = []
                for width: CGFloat in [280, 700, 280] {
                    let measured = view.measuredSize(width: width)
                    heights.append(measured.height)
                    let layout = view.layoutManager as! NotebookLayoutManager
                    let range = layout.glyphRange(for: view.textContainer)
                    let rules = layout.rules(for: range)
                    var glyphBounds: [CGRect] = []
                    // Check actual ink bounds independently from the rule's UIFont metrics.
                    let font = CTFontCreateWithName(UIFont.systemFont(ofSize: size, weight: .semibold).fontName as CFString, size, nil)
                    layout.enumerateLineFragments(forGlyphRange: range) { fragment, _, _, glyphs, _ in
                        var ink = CGRect.null
                        for index in glyphs.location..<NSMaxRange(glyphs) {
                            var glyph = layout.glyph(at: index)
                            var box = CGRect.zero
                            CTFontGetBoundingRectsForGlyphs(font, .horizontal, &glyph, &box, 1)
                            if box.isEmpty { continue }
                            let baseline = fragment.minY + layout.location(forGlyphAt: index).y
                            ink = ink.union(CGRect(x: 0, y: baseline - box.maxY, width: 1, height: box.height))
                        }
                        glyphBounds.append(ink)
                    }
                    XCTAssertEqual(rules.count, glyphBounds.count)
                    XCTAssertGreaterThan(rules.count, 1)
                    for index in rules.indices {
                        XCTAssertGreaterThan(rules[index].minY, glyphBounds[index].maxY)
                        XCTAssertLessThan(rules[index].maxY, measured.height)
                        XCTAssertEqual(rules[index].width, width)
                        if index + 1 < rules.count {
                            XCTAssertLessThanOrEqual(rules[index].maxY, glyphBounds[index + 1].minY)
                        }
                    }
                }
                XCTAssertGreaterThan(heights[0], heights[1])
                XCTAssertEqual(heights[0], heights[2], "Restoring portrait must restore the same line positions")
            }
        }
    }

    func testNoiseReductionIsOptInAndPersistsIndependently() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        XCTAssertFalse(settings.reduceBackgroundNoise)
        settings.reduceBackgroundNoise = true
        let restored = AppSettings(defaults: defaults)
        XCTAssertTrue(restored.reduceBackgroundNoise)
        XCTAssertTrue(restored.saveAudio)
        XCTAssertEqual(restored.captureLanguage, .english)
        restored.reduceBackgroundNoise = false
        XCTAssertFalse(AppSettings(defaults: defaults).reduceBackgroundNoise)
    }

    func testUnknownOrLowCapacityIsNotReportedReady() {
        XCTAssertFalse(StorageReadiness(availableBytes: nil).ready)
        XCTAssertFalse(StorageReadiness(availableBytes: 1).ready)
        XCTAssertTrue(StorageReadiness(availableBytes: StorageReadiness.minimumBytes).ready)
    }
}
