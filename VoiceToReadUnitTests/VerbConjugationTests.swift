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
