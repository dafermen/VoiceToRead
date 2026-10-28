import Foundation
import Observation

struct EnglishTrainingPhrase: Codable, Equatable, Identifiable {
    var id = UUID()
    // Keep the original JSON keys: these hold source/translated text for any language pair.
    var spanish: String
    var english = ""
    var reviewed = false
    var needsPractice = true
}

struct EnglishTraining: Codable, Equatable, Identifiable {
    var id = UUID()
    var title: String
    var phrases: [EnglishTrainingPhrase]
    var updatedAt = Date()
    var sourceLanguage: CaptureLanguage = .spanish
    var targetLanguage: CaptureLanguage = .english

    init(id: UUID = UUID(), title: String, phrases: [EnglishTrainingPhrase], updatedAt: Date = Date(),
         sourceLanguage: CaptureLanguage = .spanish, targetLanguage: CaptureLanguage = .english) {
        self.id = id; self.title = title; self.phrases = phrases; self.updatedAt = updatedAt
        self.sourceLanguage = sourceLanguage; self.targetLanguage = targetLanguage
    }
    private enum CodingKeys: String, CodingKey { case id, title, phrases, updatedAt, sourceLanguage, targetLanguage }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        phrases = try values.decode([EnglishTrainingPhrase].self, forKey: .phrases)
        updatedAt = try values.decode(Date.self, forKey: .updatedAt)
        // Existing installations have no language keys. Keep their phrases and corrections.
        sourceLanguage = try values.decodeIfPresent(CaptureLanguage.self, forKey: .sourceLanguage) ?? .spanish
        targetLanguage = try values.decodeIfPresent(CaptureLanguage.self, forKey: .targetLanguage) ?? .english
    }
    var ready: Bool { !phrases.isEmpty && phrases.allSatisfy { !$0.english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
    var source: [ReviewParagraph] { phrases.map { ReviewParagraph(id: $0.id, text: $0.spanish) } }
    var valid: Bool {
        sourceLanguage != targetLanguage &&
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && title.count <= 100 &&
        !phrases.isEmpty && phrases.count <= 200 && Set(phrases.map(\.id)).count == phrases.count &&
        phrases.allSatisfy { !$0.spanish.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.spanish.count <= 1000 && $0.english.count <= 1000 }
    }

    static func edited(title: String, text: String, previous: Self? = nil,
                       sourceLanguage: CaptureLanguage? = nil, targetLanguage: CaptureLanguage? = nil) throws -> Self {
        let sourceLanguage = sourceLanguage ?? previous?.sourceLanguage ?? .spanish
        let targetLanguage = targetLanguage ?? previous?.targetLanguage ?? .english
        guard sourceLanguage != targetLanguage else { throw EnglishTrainingFailure.sameLanguage }
        let changedPair = previous.map { $0.sourceLanguage != sourceLanguage || $0.targetLanguage != targetLanguage } ?? false
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !title.isEmpty, title.count <= 100, !lines.isEmpty, lines.count <= 200,
              lines.allSatisfy({ $0.count <= 1000 }) else { throw EnglishTrainingFailure.invalidInput }
        var retained = previous?.phrases ?? []
        let phrases = lines.map { line -> EnglishTrainingPhrase in
            if let index = retained.firstIndex(where: { $0.spanish == line }) {
                var phrase = retained.remove(at: index)
                if changedPair { phrase.english = ""; phrase.reviewed = false; phrase.needsPractice = true }
                return phrase
            }
            return EnglishTrainingPhrase(spanish: line)
        }
        var result = previous ?? Self(title: title, phrases: [])
        result.title = title; result.phrases = phrases; result.updatedAt = Date()
        result.sourceLanguage = sourceLanguage; result.targetLanguage = targetLanguage
        return result
    }

    static let sampleTitle = "Presentarme y conversar"
    static let samplePracticeText = """
    Hola, me llamo Alex.
    Vivo cerca del centro de la ciudad.
    Trabajo con un equipo pequeño.
    Estoy aprendiendo inglés para comunicarme mejor.
    Me gustaría practicar contigo.
    ¿Cómo te llamas?
    ¿A qué te dedicas?
    En mi tiempo libre me gusta caminar.
    También disfruto escuchar música.
    Normalmente empiezo a trabajar por la mañana.
    Hoy tengo una reunión importante.
    Necesito explicar una idea con claridad.
    ¿Podrías hablar un poco más despacio?
    No entendí la última parte.
    ¿Puedes repetir esa frase, por favor?
    Déjame comprobar si entendí bien.
    Prefiero hacer una pregunta antes de continuar.
    Mañana voy a practicar otra vez.
    Poco a poco me siento más seguro al hablar.
    Gracias por escucharme. ¿Tienes alguna pregunta?
    """
    static func samplePractice() throws -> Self {
        try edited(title: sampleTitle, text: samplePracticeText)
    }

    // Legacy text remains for existing stories and safe identification of an untouched starter.

    static let firstText = """
    Había una vez tres cerditos.
    Los tres hermanos vivían cerca de un bosque.
    Un día, cada cerdito decidió construir una casa.
    El primer cerdito hizo una casa de paja.
    El segundo cerdito hizo una casa de madera.
    El tercer cerdito hizo una casa de ladrillos.
    Los dos primeros terminaron pronto y salieron a jugar.
    El tercer cerdito trabajó un poco más.
    Una mañana, un lobo llegó a la casa de paja.
    El cerdito cerró la puerta.
    El lobo sopló y la casa se cayó.
    El cerdito corrió a la casa de su hermano.
    El lobo llegó a la casa de madera y sopló otra vez.
    La casa de madera también se cayó.
    Los dos cerditos corrieron a la casa de ladrillos.
    Su hermano abrió la puerta y los dejó entrar.
    El lobo sopló con fuerza, pero la casa no se cayó.
    Al final, el lobo se cansó y se fue.
    Los tres hermanos se quedaron juntos en la casa segura.
    Los cerditos aprendieron a trabajar con cuidado y a ayudarse.
    """
}

enum EnglishTrainingFailure: LocalizedError {
    case invalidInput, changed, invalidTranslation, unsupportedFile, sameLanguage
    var errorDescription: String? {
        switch self {
        case .invalidInput: "Use a title of up to 100 characters and 1–200 source phrases, one per line, up to 1,000 characters each."
        case .changed: "This training changed. Reopen it and try again. Your saved phrases are unchanged."
        case .invalidTranslation: "The translated responses are incomplete. Review the phrases and try again."
        case .unsupportedFile: "The training file could not be opened. It has not been replaced or deleted."
        case .sameLanguage: "Choose different source and practice languages."
        }
    }
}

/// Separate local storage: never opens, migrates, deletes or rewrites the session database.
@MainActor @Observable
final class EnglishTrainingStore {
    private struct Archive: Codable { var version = 2; var trainings: [EnglishTraining]; var sampleRevision: Int? }
    private(set) var trainings: [EnglishTraining]
    private let file: URL

    init(directory: URL? = nil) throws {
        var folder = try directory ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("VoiceToRead/EnglishTraining", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try folder.setResourceValues(values)
        file = folder.appendingPathComponent("trainings.json")
        if FileManager.default.fileExists(atPath: file.path) {
            do {
                let archive = try JSONDecoder().decode(Archive.self, from: Data(contentsOf: file))
                guard [1, 2].contains(archive.version), Set(archive.trainings.map(\.id)).count == archive.trainings.count,
                      archive.trainings.allSatisfy(\.valid) else {
                    throw EnglishTrainingFailure.unsupportedFile
                }
                trainings = archive.trainings
                if archive.sampleRevision == nil, let index = trainings.firstIndex(where: { $0.title == "Los tres cerditos" }) {
                    let old = trainings[index]
                    let legacyLines = EnglishTraining.firstText.components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                    let untouched = old.sourceLanguage == .spanish && old.targetLanguage == .english &&
                        old.phrases.map(\.spanish) == legacyLines &&
                        old.phrases.allSatisfy { $0.english.isEmpty && !$0.reviewed && $0.needsPractice }
                    if untouched {
                        var sample = try EnglishTraining.samplePractice(); sample.id = old.id
                        trainings[index] = sample
                    } else if !trainings.contains(where: { $0.title == EnglishTraining.sampleTitle }) {
                        trainings.append(try EnglishTraining.samplePractice())
                    }
                    try persist(trainings)
                }
            } catch { throw EnglishTrainingFailure.unsupportedFile }
        } else {
            trainings = [try EnglishTraining.samplePractice()]
            try persist(trainings)
        }
    }
    func training(_ id: UUID) -> EnglishTraining? { trainings.first { $0.id == id } }
    private func persist(_ values: [EnglishTraining]) throws {
        let data = try JSONEncoder().encode(Archive(trainings: values, sampleRevision: 1))
        try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    func save(_ training: EnglishTraining) throws {
        guard training.valid else { throw EnglishTrainingFailure.invalidInput }
        var values = trainings
        if let index = values.firstIndex(where: { $0.id == training.id }) { values[index] = training }
        else { values.append(training) }
        try persist(values); trainings = values
    }
    func saveEnglish(_ id: UUID, source: [ReviewParagraph], values: [UUID: String],
                     language: CaptureLanguage = .spanish, targetLanguage: CaptureLanguage = .english) throws {
        guard var training = training(id), training.source == source,
              training.sourceLanguage == language, training.targetLanguage == targetLanguage else { throw EnglishTrainingFailure.changed }
        guard Set(values.keys) == Set(training.phrases.map(\.id)), values.values.allSatisfy({ $0.count <= 1000 }) else { throw EnglishTrainingFailure.invalidTranslation }
        for index in training.phrases.indices {
            let text = values[training.phrases[index].id]!.trimmingCharacters(in: .whitespacesAndNewlines)
            if training.phrases[index].english != text {
                training.phrases[index].english = text
                training.phrases[index].reviewed = false; training.phrases[index].needsPractice = true
            }
        }
        training.updatedAt = Date(); try save(training)
    }
    func acceptTranslation(_ id: UUID, source: [ReviewParagraph], responses: [ReviewParagraph],
                           language: CaptureLanguage = .spanish, targetLanguage: CaptureLanguage = .english,
                           replacing snapshot: EnglishTraining? = nil) throws {
        guard var training = training(id), Set(source.map(\.id)).count == source.count,
              training.sourceLanguage == language, training.targetLanguage == targetLanguage else { throw EnglishTrainingFailure.changed }
        if let snapshot {
            guard training == snapshot, source == training.source else { throw EnglishTrainingFailure.changed }
        }
        guard source.map(\.id) == responses.map(\.id), responses.allSatisfy({ !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.text.count <= 1000 }) else { throw EnglishTrainingFailure.invalidTranslation }
        for (original, translated) in zip(source, responses) {
            guard let index = training.phrases.firstIndex(where: { $0.id == original.id && $0.spanish == original.text && ($0.english.isEmpty || snapshot != nil) }) else { throw EnglishTrainingFailure.changed }
            training.phrases[index].english = translated.text.trimmingCharacters(in: .whitespacesAndNewlines)
            training.phrases[index].reviewed = false; training.phrases[index].needsPractice = true
        }
        training.updatedAt = Date(); try save(training)
    }
    func mark(_ id: UUID, phraseID: UUID, needsPractice: Bool) throws {
        guard var training = training(id), let index = training.phrases.firstIndex(where: { $0.id == phraseID }) else { throw EnglishTrainingFailure.changed }
        training.phrases[index].reviewed = true; training.phrases[index].needsPractice = needsPractice
        training.updatedAt = Date(); try save(training)
    }
}

/// Word differences describe recognition, not pronunciation quality or translation validity.
enum TrainingComparison {
    struct Word: Equatable { let text: String; let matched: Bool; var separator = " " }
    static func compare(expected: String, heard: String) -> (expected: [Word], heard: [Word]) {
        let unspaced = SubtitleExport.containsUnspacedScript(expected) || SubtitleExport.containsUnspacedScript(heard)
        let a = unspaced ? expected.map(String.init) : expected.split(whereSeparator: \.isWhitespace).map(String.init)
        let b = unspaced ? heard.map(String.init) : heard.split(whereSeparator: \.isWhitespace).map(String.init)
        let ka = a.map { PracticeRecognition.words($0).joined(separator: " ") }
        let kb = b.map { PracticeRecognition.words($0).joined(separator: " ") }
        let width = b.count + 1
        var lengths = [Int](repeating: 0, count: (a.count + 1) * width)
        if !a.isEmpty && !b.isEmpty {
            for i in stride(from: a.count - 1, through: 0, by: -1) {
                for j in stride(from: b.count - 1, through: 0, by: -1) {
                    lengths[i * width + j] = !ka[i].isEmpty && ka[i] == kb[j]
                        ? 1 + lengths[(i + 1) * width + j + 1]
                        : max(lengths[(i + 1) * width + j], lengths[i * width + j + 1])
                }
            }
        }
        var matchedA = Set<Int>(), matchedB = Set<Int>(), i = 0, j = 0
        while i < a.count && j < b.count {
            if !ka[i].isEmpty && ka[i] == kb[j] { matchedA.insert(i); matchedB.insert(j); i += 1; j += 1 }
            else if lengths[(i + 1) * width + j] >= lengths[i * width + j + 1] { i += 1 }
            else { j += 1 }
        }
        return (a.enumerated().map { Word(text: $0.element, matched: ka[$0.offset].isEmpty || matchedA.contains($0.offset), separator: unspaced ? "" : " ") },
                b.enumerated().map { Word(text: $0.element, matched: kb[$0.offset].isEmpty || matchedB.contains($0.offset), separator: unspaced ? "" : " ") })
    }
}


/// In-memory results for one round. No history, self-assessment or session writes.
struct EnglishTrainingRound {
    let phraseIDs: [UUID]
    private(set) var results: [UUID: Bool] = [:]
    var matchedCount: Int { results.values.filter { $0 }.count }
    var differentIDs: [UUID] { phraseIDs.filter { results[$0] == false } }
    var unattemptedCount: Int { phraseIDs.count - results.count }

    mutating func record(phraseID: UUID, expected: String, heard: String) {
        guard phraseIDs.contains(phraseID), !PracticeRecognition.words(heard).isEmpty,
              !PracticeRecognition.words(expected).isEmpty else { return }
        // Revisiting/retrying a phrase replaces its result rather than adding a count.
        results[phraseID] = PracticeRecognition.matches(heard, target: expected)
    }
    mutating func clearResult(for phraseID: UUID) { results.removeValue(forKey: phraseID) }
}
