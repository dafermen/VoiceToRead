import XCTest
@testable import VoiceToRead

final class VerbConjugationTests: XCTestCase {
    private func verb(_ base: String) throws -> ConjugationVerb {
        try XCTUnwrap(ConjugationVerb.load().first { $0.base == base })
    }
    func testCatalogPatternsAndSearchFindInflectionsAndAccentedMeanings() throws {
        let catalog = try ConjugationVerb.load()
        XCTAssertEqual(catalog.count, 28)
        for (word, pattern) in [("cut", VerbPattern.aaa), ("buy", .abb), ("write", .abc), ("come", .aba), ("beat", .aab), ("study", .regular)] {
            XCTAssertEqual(try verb(word).pattern, pattern)
        }
        XCTAssertEqual(ConjugationVerb.matching(catalog, query: "written", pattern: .all, tense: .all).map(\.base), ["write"])
        XCTAssertEqual(ConjugationVerb.matching(catalog, query: "ensenar", pattern: .all, tense: .all).map(\.base), ["teach"])
        XCTAssertTrue(ConjugationVerb.matching(catalog, query: "", pattern: .aab, tense: .all).allSatisfy { $0.base == "beat" })
        XCTAssertFalse(ConjugationVerb.matching(catalog, query: "", pattern: .all, tense: .presentContinuous).contains { $0.base == "know" })
    }
    func testAuxiliariesUseBaseFormAndThirdPersonIsNotDuplicated() throws {
        let write = try verb("write")
        XCTAssertEqual(write.sentence(tense: .presentSimple, form: .affirmative, subject: .she), "She writes a message.")
        XCTAssertEqual(write.sentence(tense: .presentSimple, form: .negative, subject: .she), "She does not write a message.")
        XCTAssertEqual(write.sentence(tense: .presentSimple, form: .question, subject: .she), "Does she write a message?")
        XCTAssertEqual(write.sentence(tense: .pastSimple, form: .affirmative, subject: .i), "I wrote a message.")
        XCTAssertEqual(write.sentence(tense: .pastSimple, form: .negative, subject: .i), "I did not write a message.")
        XCTAssertEqual(write.sentence(tense: .pastSimple, form: .question, subject: .i), "Did I write a message?")
        XCTAssertEqual(write.sentence(tense: .presentPerfect, form: .question, subject: .she), "Has she written a message?")
        XCTAssertEqual(write.sentence(tense: .presentContinuous, form: .negative, subject: .i), "I am not writing a message.")
        XCTAssertEqual(write.sentence(tense: .presentPerfectContinuous, form: .affirmative, subject: .they), "They have been writing a message.")
        XCTAssertEqual(try verb("study").sentence(tense: .presentSimple, form: .affirmative, subject: .he), "He studies English.")
        XCTAssertEqual(try verb("have").sentence(tense: .presentSimple, form: .question, subject: .she), "Does she have lunch?")
        XCTAssertEqual(try verb("do").sentence(tense: .presentSimple, form: .question, subject: .he), "Does he do the homework?")
    }
    func testBeUsesInversionAndContinuousMeaningRestrictionsAreExplicit() throws {
        let be = try verb("be")
        XCTAssertEqual(be.sentence(tense: .presentSimple, form: .question, subject: .i), "Am I ready?")
        XCTAssertEqual(be.sentence(tense: .presentSimple, form: .negative, subject: .she), "She is not ready.")
        XCTAssertEqual(be.sentence(tense: .pastSimple, form: .affirmative, subject: .we), "We were ready.")
        XCTAssertEqual(be.sentence(tense: .pastSimple, form: .question, subject: .he), "Was he ready?")
        XCTAssertEqual(be.sentence(tense: .presentPerfect, form: .negative, subject: .he), "He has not been ready.")
        XCTAssertNil(be.sentence(tense: .presentContinuous, form: .affirmative, subject: .i))
        XCTAssertNil(try verb("know").sentence(tense: .presentPerfectContinuous, form: .affirmative, subject: .i))
        XCTAssertNil(be.sentence(tense: .all, form: .affirmative, subject: .i))
    }
    func testEverySupportedCombinationHasACompleteSentence() throws {
        for verb in try ConjugationVerb.load() {
            for tense in VerbTense.concrete {
                for form in VerbSentenceForm.concrete {
                    for subject in VerbSubject.concrete {
                        let sentence = verb.sentence(tense: tense, form: form, subject: subject)
                        if verb.supports(tense) {
                            let value = try XCTUnwrap(sentence)
                            XCTAssertFalse(value.contains("  "))
                            XCTAssertTrue(value.hasSuffix(form == .question ? "?" : "."))
                            XCTAssertFalse(value.contains("was / were"))
                        } else { XCTAssertNil(sentence) }
                    }
                }
            }
        }
    }
}

extension VerbConjugationTests {
    func testEveryDisplayedWordHasAGlossInEverySupportLanguage() throws {
        for verb in try ConjugationVerb.load() {
            let keys = ["base", "participle", "third", "ing"] + (verb.base == "be" ? ["past-was", "past-were"] : ["past"])
            for language in CaptureLanguage.allCases {
                XCTAssertFalse(verb.meaning(in: language).isEmpty)
                for key in keys { XCTAssertFalse(try XCTUnwrap(verb.translatedForm(key, language: language)).isEmpty) }
            }
        }
        let be = try verb("be")
        XCTAssertEqual(be.translatedForm("base", language: .spanish), "ser / estar")
        XCTAssertEqual(be.translatedForm("third", language: .spanish), "es / está")
        XCTAssertNotEqual(be.translatedForm("past-was", language: .spanish), be.translatedForm("past-were", language: .spanish))
        XCTAssertEqual(try verb("write").translatedForm("base", language: .french), "écrire")
        XCTAssertEqual(try verb("write").translatedForm("base", language: .japanese), "書く")
        XCTAssertEqual(try verb("study").translatedForm("base", language: .chinese), "学习")
    }
    func testTranslationDefaultAndManualOverrideFollowAppSettings() {
        XCTAssertEqual(VerbTranslationPreference.language(saved: "", interfaceAtSelection: "", currentInterface: "es"), .spanish)
        XCTAssertEqual(VerbTranslationPreference.language(saved: "", interfaceAtSelection: "", currentInterface: "en"), .english)
        XCTAssertEqual(VerbTranslationPreference.language(saved: "fr-FR", interfaceAtSelection: "es", currentInterface: "es"), .french)
        XCTAssertEqual(VerbTranslationPreference.language(saved: "fr-FR", interfaceAtSelection: "es", currentInterface: "en"), .english)
        XCTAssertEqual(VerbTranslationPreference.language(saved: "invalid", interfaceAtSelection: "es", currentInterface: "es"), .spanish)
        XCTAssertEqual(VerbTranslationPreference.language(saved: "", interfaceAtSelection: "", currentInterface: "fr"), .french)
    }
    func testSearchFindsMeaningsInTheAdditionalLanguages() throws {
        let verbs = try ConjugationVerb.load()
        for (text, base) in [("acheter", "buy"), ("書く", "write"), ("마시다", "drink"), ("学习", "study")] {
            XCTAssertEqual(ConjugationVerb.matching(verbs, query: text, pattern: .all, tense: .all).map(\.base), [base])
        }
    }
}

extension VerbConjugationTests {
    func testEveryWordFormHasIPAIndependentOfTranslationLanguage() throws {
        for verb in try ConjugationVerb.load() {
            let forms = ["base", "participle", "third", "ing"] + (verb.base == "be" ? ["past-was", "past-were"] : ["past"])
            for form in forms {
                let ipa = try XCTUnwrap(verb.pronunciation(form))
                XCTAssertTrue(ipa.hasPrefix("/") && ipa.hasSuffix("/"))
                for language in CaptureLanguage.allCases {
                    let display = verb.translatedPronunciation(form, language: language)
                    XCTAssertTrue(display.hasSuffix(ipa))
                    XCTAssertTrue(display.hasPrefix(try XCTUnwrap(verb.translatedForm(form, language: language))))
                }
            }
        }
        XCTAssertEqual(try verb("become").translatedPronunciation("base", language: .spanish), "convertirse en  /bɪˈkʌm/")
        XCTAssertEqual(try verb("do").pronunciation("third"), "/dʌz/")
        XCTAssertEqual(try verb("be").pronunciation("participle"), "/bɪn/")
        XCTAssertEqual(try verb("work").pronunciation("past"), "/wɝːkt/")
    }
    func testVerbMarksToggleIndependentlyAndSurvivePreferenceReload() throws {
        let suite = "VerbMarksTests-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var marks = VerbLibraryMarks()
        marks.toggleFavorite("become")
        XCTAssertTrue(marks.favorites.contains("become"))
        XCTAssertFalse(marks.completed.contains("become"))
        marks.toggleCompleted("become")
        marks.toggleFavorite("write")
        defaults.set(marks.data, forKey: "verbReferenceMarks")
        let restored = VerbLibraryMarks(data: try XCTUnwrap(defaults.data(forKey: "verbReferenceMarks")))
        XCTAssertEqual(restored, marks)
        marks.toggleFavorite("become")
        XCTAssertFalse(marks.favorites.contains("become"))
        XCTAssertTrue(marks.completed.contains("become"))
        marks.toggleCompleted("become")
        XCTAssertFalse(marks.completed.contains("become"))
        XCTAssertTrue(marks.favorites.contains("write"))
        XCTAssertEqual(VerbLibraryMarks(data: Data("invalid".utf8)), VerbLibraryMarks())
    }
    func testVerbMarkFiltersCombineByIntersectionWithTheExistingFilters() throws {
        let verbs = try ConjugationVerb.load()
        let marks = VerbLibraryMarks(favorites: ["become", "run", "write"], completed: ["run", "buy"])
        func matches(favorites: Bool, completed: Bool, pattern: VerbPattern = .all, query: String = "") -> [String] {
            ConjugationVerb.matching(verbs, query: query, pattern: pattern, tense: .all)
                .filter { marks.includes($0.id, favoritesOnly: favorites, completedOnly: completed) }.map(\.id)
        }
        XCTAssertEqual(matches(favorites: false, completed: false).count, verbs.count)
        XCTAssertEqual(matches(favorites: true, completed: false), ["become", "run", "write"])
        XCTAssertEqual(matches(favorites: false, completed: true), ["buy", "run"])
        XCTAssertEqual(matches(favorites: true, completed: true), ["run"])
        XCTAssertEqual(matches(favorites: true, completed: false, pattern: .aba), ["become", "run"])
        XCTAssertEqual(matches(favorites: true, completed: true, query: "written"), [])
        XCTAssertEqual(marks.favorites, ["become", "run", "write"], "Filtering never changes the marks")
    }
}
