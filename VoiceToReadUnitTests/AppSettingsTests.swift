import XCTest
import UIKit
import CoreText
import SwiftUI
@testable import VoiceToRead

@MainActor
final class AppSettingsTests: XCTestCase {
    func testJapaneseAndSimplifiedChineseSettingsSurviveReopening() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        settings.captureLanguage = .japanese
        settings.translationLanguage = .chinese
        settings.japaneseColor = .green
        settings.chineseColor = .blue
        let reopened = AppSettings(defaults: defaults)
        XCTAssertEqual(reopened.captureLanguage, .japanese)
        XCTAssertEqual(reopened.translationLanguage, .chinese)
        XCTAssertEqual(reopened.color(for: .japanese), .green)
        XCTAssertEqual(reopened.color(for: .chinese), .blue)
        XCTAssertEqual(reopened.interfaceLanguage, settings.interfaceLanguage)
    }


    func testConversationHomeDefaultsAndReversiblePreferencePreserveCaptureSettings() {
        let name = UUID().uuidString; let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        XCTAssertTrue(settings.conversationHome)
        XCTAssertTrue(settings.showButtonNames)
        settings.captureLanguage = .korean
        settings.showButtonNames = false
        settings.conversationHome = false
        let restored = AppSettings(defaults: defaults)
        XCTAssertFalse(restored.conversationHome)
        XCTAssertFalse(restored.showButtonNames)
        XCTAssertEqual(restored.captureLanguage, .korean)
        restored.conversationHome = true
        XCTAssertTrue(AppSettings(defaults: defaults).conversationHome)
        XCTAssertEqual(restored.captureLanguage, .korean)
    }

    func testFourLanguagesPersistSeparateFromInterfaceAndPreventSamePair() {
        let name = UUID().uuidString; let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.captureLanguage, .english)
        XCTAssertEqual(settings.translationLanguage, .spanish)
        settings.captureLanguage = .french; settings.translationLanguage = .korean
        settings.frenchColor = .orange
        let restored = AppSettings(defaults: defaults)
        XCTAssertEqual(restored.captureLanguage, .french)
        XCTAssertEqual(restored.translationLanguage, .korean)
        XCTAssertEqual(restored.interfaceLanguage, .english)
        XCTAssertEqual(restored.color(for: .french), .orange)
        restored.captureLanguage = .korean
        XCTAssertNotEqual(restored.captureLanguage, restored.translationLanguage)
        defaults.set("ko-KR", forKey: "translationLanguage")
        let repaired = AppSettings(defaults: defaults)
        XCTAssertNotEqual(repaired.captureLanguage, repaired.translationLanguage)
    }

    func testLanguageColorsPersistRestoreAndDoNotChangeLanguages() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.color(for: .english), .blue)
        XCTAssertEqual(settings.color(for: .spanish), .green)
        settings.captureLanguage = .spanish; settings.interfaceLanguage = .english
        settings.englishColor = .orange; settings.spanishColor = .purple
        let restored = AppSettings(defaults: defaults)
        XCTAssertEqual(restored.color(for: .english), .orange)
        XCTAssertEqual(restored.color(for: .spanish), .purple)
        XCTAssertEqual(restored.captureLanguage, .spanish)
        XCTAssertEqual(restored.interfaceLanguage, .english)
        restored.restoreLanguageColors()
        XCTAssertEqual(AppSettings(defaults: defaults).englishColor, .blue)
        XCTAssertEqual(AppSettings(defaults: defaults).spanishColor, .green)
        XCTAssertEqual(restored.captureLanguage, .spanish)
        defaults.set("obsolete-color", forKey: "englishLanguageColor")
        defaults.set("obsolete-color", forKey: "spanishLanguageColor")
        XCTAssertEqual(AppSettings(defaults: defaults).englishColor, .blue)
        XCTAssertEqual(AppSettings(defaults: defaults).spanishColor, .green)
    }

    func testLanguagePaletteContrastWithBlackOrWhiteText() {
        func luminance(_ color: Color) -> Double {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            XCTAssertTrue(UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a))
            func linear(_ c: CGFloat) -> Double { c <= 0.04045 ? Double(c) / 12.92 : pow((Double(c) + 0.055) / 1.055, 2.4) }
            return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
        }
        for color in LanguageColor.allCases {
            XCTAssertGreaterThan((luminance(color.background(.light)) + 0.05) / 0.05, 7)
            XCTAssertGreaterThan(1.05 / (luminance(color.background(.dark)) + 0.05), 7)
            XCTAssertEqual(luminance(color.background(.light, highContrast: true)), 1, accuracy: 0.001)
            XCTAssertEqual(luminance(color.background(.dark, highContrast: true)), 0, accuracy: 0.001)
        }
    }

    func testAccessiblePreferencesPersistWithoutChangingCaptureLanguage() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        XCTAssertFalse(settings.simpleMode); XCTAssertTrue(settings.showButtonNames)
        settings.simpleMode = true; settings.showButtonNames = true
        settings.focusedReading = true; settings.pauseHaptics = false; settings.preparationSeen = true
        let restored = AppSettings(defaults: defaults)
        XCTAssertTrue(restored.simpleMode && restored.showButtonNames && restored.focusedReading && restored.preparationSeen)
        XCTAssertFalse(restored.pauseHaptics)
        XCTAssertEqual(restored.captureLanguage, .english)
    }

    func testExpandedCaptionSizePersistsAndPreservesExistingChoices() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        XCTAssertEqual(AppSettings(defaults: defaults).captionSize, 28)
        for size in [14.0, 16, 28, 44, 60] {
            let settings = AppSettings(defaults: defaults)
            settings.captionSize = size
            XCTAssertEqual(AppSettings(defaults: defaults).captionSize, size)
        }
        defaults.set(-5, forKey: "captionSize")
        XCTAssertEqual(AppSettings(defaults: defaults).captionSize, 14)
        XCTAssertEqual(CaptionTextSize.clamped(.nan), 28)
        XCTAssertEqual(CaptionTextSize.clamped(.infinity), 28)
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
        XCTAssertEqual(settings.captionSize, 60)
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
