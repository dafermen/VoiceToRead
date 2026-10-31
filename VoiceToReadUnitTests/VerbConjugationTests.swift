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
