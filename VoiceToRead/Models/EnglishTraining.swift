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
    var showPracticeResponse = false
    var slowPracticeExample = true

    init(id: UUID = UUID(), title: String, phrases: [EnglishTrainingPhrase], updatedAt: Date = Date(),
         sourceLanguage: CaptureLanguage = .spanish, targetLanguage: CaptureLanguage = .english) {
        self.id = id; self.title = title; self.phrases = phrases; self.updatedAt = updatedAt
        self.sourceLanguage = sourceLanguage; self.targetLanguage = targetLanguage
    }
    private enum CodingKeys: String, CodingKey { case id, title, phrases, updatedAt, sourceLanguage, targetLanguage, showPracticeResponse, slowPracticeExample }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        phrases = try values.decode([EnglishTrainingPhrase].self, forKey: .phrases)
        updatedAt = try values.decode(Date.self, forKey: .updatedAt)
        // Existing installations have no language keys. Keep their phrases and corrections.
        sourceLanguage = try values.decodeIfPresent(CaptureLanguage.self, forKey: .sourceLanguage) ?? .spanish
        targetLanguage = try values.decodeIfPresent(CaptureLanguage.self, forKey: .targetLanguage) ?? .english
        showPracticeResponse = try values.decodeIfPresent(Bool.self, forKey: .showPracticeResponse) ?? false
        slowPracticeExample = try values.decodeIfPresent(Bool.self, forKey: .slowPracticeExample) ?? true
    }
    var ready: Bool { !phrases.isEmpty && phrases.allSatisfy { !$0.english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
    /// Automatic preparation fills only absent responses; existing corrections are never queued.
    var missingTranslationSource: [ReviewParagraph] {
        phrases.filter { $0.english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { ReviewParagraph(id: $0.id, text: $0.spanish) }
    }
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

    // Everyday source texts; translations continue to use the existing review flow.
    static let additionalPracticeExamples: [(title: String, text: String)] = [
        ("Mi rutina diaria", """
        Me levanto a las siete.
        Primero preparo el desayuno.
        Después me visto para salir.
        Normalmente voy al trabajo en autobús.
        Al mediodía hago una pausa.
        Como con mis compañeros.
        Por la tarde regreso a casa.
        A veces salgo a caminar.
        Por la noche leo un poco.
        Intento acostarme temprano.
        """),
        ("En una cafetería", """
        Buenos días, quisiera un café.
        ¿Tienen leche sin lactosa?
        Prefiero una taza pequeña.
        También quiero un sándwich.
        ¿Qué ingredientes lleva?
        Para llevar, por favor.
        ¿Cuánto cuesta en total?
        ¿Puedo pagar con tarjeta?
        ¿Dónde puedo recoger mi pedido?
        Muchas gracias, que tenga buen día.
        """),
        ("Comprar alimentos", """
        Necesito comprar fruta y verduras.
        ¿Dónde están los tomates?
        Quisiera medio kilo de manzanas.
        ¿Estas naranjas son dulces?
        Busco pan sin semillas.
        ¿Cuánto cuesta esta botella de agua?
        No necesito una bolsa.
        ¿Dónde está la caja?
        Creo que falta un producto.
        Gracias por ayudarme.
        """),
        ("Pedir indicaciones", """
        Disculpe, estoy buscando la estación.
        ¿Está cerca de aquí?
        ¿Puedo llegar caminando?
        ¿Tengo que cruzar esta calle?
        ¿Debo girar a la derecha?
        ¿Cuánto tiempo se tarda?
        ¿Hay algún punto de referencia?
        Creo que me equivoqué de camino.
        ¿Podría mostrarme en el mapa?
        Gracias, ahora entiendo cómo llegar.
        """),
        ("Usar el transporte público", """
        Quiero ir al centro.
        ¿Este autobús pasa por el hospital?
        ¿Dónde compro un billete?
        ¿Cuánto cuesta el viaje?
        ¿Puedo pagar con tarjeta?
        ¿Tengo que cambiar de autobús?
        Avíseme cuando lleguemos, por favor.
        Creo que esta es mi parada.
        ¿A qué hora sale el último tren?
        Muchas gracias por la información.
        """),
        ("Llegar a un hotel", """
        Buenas tardes, tengo una reserva.
        La reserva está a mi nombre.
        Me quedaré tres noches.
        ¿Necesita mi documento de identidad?
        ¿A qué hora sirven el desayuno?
        ¿Dónde está el ascensor?
        ¿La habitación tiene conexión a internet?
        ¿Podría darme otra toalla?
        ¿A qué hora debo dejar la habitación?
        Gracias, la habitación está muy bien.
        """),
        ("Pedir comida", """
        Quisiera ver el menú, por favor.
        ¿Qué plato recomienda?
        Soy alérgico a los frutos secos.
        ¿Este plato lleva leche?
        Prefiero algo sin picante.
        Para beber quiero agua.
        ¿Podemos pedir una porción para compartir?
        La comida está muy rica.
        ¿Podría traer la cuenta?
        Gracias por atendernos.
        """),
        ("Comprar ropa", """
        Estoy buscando una chaqueta.
        ¿Tiene este modelo en otro color?
        Necesito una talla más grande.
        ¿Puedo probármela?
        ¿Dónde están los probadores?
        Me gusta, pero me queda larga.
        ¿Cuánto cuesta esta camisa?
        ¿Puedo cambiarla si no me queda bien?
        Quisiera llevar esta.
        ¿Puede darme el recibo, por favor?
        """),
        ("Organizar una cita", """
        ¿Tienes tiempo para reunirnos?
        Podemos vernos esta semana.
        El martes por la mañana no puedo.
        ¿Te viene bien el jueves?
        Prefiero reunirnos por la tarde.
        ¿A qué hora nos encontramos?
        Podemos ir a la cafetería de la esquina.
        Voy a llegar diez minutos tarde.
        Perdona por el cambio de planes.
        Gracias, nos vemos el jueves.
        """),
        ("Hablar con un compañero", """
        Hola, ¿cómo va tu día?
        ¿En qué estás trabajando?
        Necesito ayuda con este documento.
        ¿Puedes explicarme el primer paso?
        Creo que entendí la idea.
        Voy a revisar los detalles.
        ¿Cuándo tenemos que terminar?
        Podemos dividir el trabajo.
        Te enviaré mi parte esta tarde.
        Gracias por trabajar conmigo.
        """),
        ("Una entrevista de trabajo", """
        Gracias por recibirme.
        Me gustaría contarle sobre mi experiencia.
        He trabajado con equipos pequeños.
        Me gusta aprender cosas nuevas.
        Una de mis fortalezas es la organización.
        Cuando tengo dudas, hago preguntas.
        Estoy mejorando mi inglés.
        Me interesa este puesto por sus responsabilidades.
        ¿Cómo sería un día normal en este trabajo?
        Gracias por considerar mi solicitud.
        """),
        ("Describir mi casa", """
        Vivo en un apartamento pequeño.
        Mi casa tiene dos habitaciones.
        La cocina está junto a la sala.
        Hay una mesa cerca de la ventana.
        Me gusta la luz de la mañana.
        Mi lugar favorito es el balcón.
        Los fines de semana limpio la casa.
        A veces invito a mis amigos.
        El barrio es tranquilo.
        Me siento a gusto en casa.
        """),
        ("Hablar de mi familia", """
        Mi familia vive en otra ciudad.
        Tengo una hermana y un hermano.
        Mi hermana trabaja en una escuela.
        Mi hermano está estudiando.
        Hablamos por teléfono cada semana.
        A mi madre le gusta cocinar.
        A mi padre le gusta caminar.
        Cuando nos reunimos, comemos juntos.
        Tenemos muchas historias divertidas.
        Me gustaría visitarlos pronto.
        """),
        ("Mis pasatiempos", """
        En mi tiempo libre me gusta leer.
        También disfruto escuchar música.
        Los sábados salgo a caminar.
        A veces cocino una receta nueva.
        Me gustaría aprender a tocar la guitarra.
        Prefiero las actividades tranquilas.
        Mi amigo disfruta jugar al fútbol.
        A veces hacemos planes juntos.
        No necesito gastar mucho para divertirme.
        ¿Qué te gusta hacer a ti?
        """),
        ("Planes para un viaje", """
        Me gustaría viajar el próximo mes.
        Quiero visitar una ciudad nueva.
        Primero necesito elegir las fechas.
        Voy a comparar los precios.
        Prefiero un vuelo por la mañana.
        Todavía no he reservado el hotel.
        Quiero conocer los lugares más importantes.
        También necesito tiempo para descansar.
        Voy a llevar una maleta pequeña.
        Espero disfrutar mucho del viaje.
        """),
        ("Pedir ayuda con el teléfono", """
        Mi teléfono no se conecta a internet.
        ¿Puedes ayudarme un momento?
        No encuentro esta opción.
        ¿Dónde tengo que presionar?
        Creo que olvidé mi contraseña.
        Voy a intentarlo otra vez.
        Ahora veo el mensaje.
        ¿Puedes explicarlo más despacio?
        Ya funciona correctamente.
        Gracias por tu paciencia.
        """),
        ("Expresar gustos y opiniones", """
        Me gusta aprender con ejemplos.
        Prefiero escuchar antes de responder.
        Creo que esta idea puede funcionar.
        Estoy de acuerdo con la primera parte.
        Tengo una opinión diferente.
        ¿Puedes contarme por qué piensas eso?
        No estoy seguro de haber entendido.
        Para mí, lo más importante es practicar.
        Podemos buscar otra solución.
        Gracias por compartir tu punto de vista.
        """),
        ("Contar lo que hice ayer", """
        Ayer me levanté un poco tarde.
        Desayuné antes de salir.
        Por la mañana fui al supermercado.
        Después hablé con un amigo.
        Preparamos algo sencillo para comer.
        Por la tarde empezó a llover.
        Decidí quedarme en casa.
        Vi una película en inglés.
        Aprendí algunas palabras nuevas.
        Fue un día tranquilo.
        """),
        ("Mis metas de aprendizaje", """
        Quiero comunicarme con más confianza.
        Mi meta es practicar un poco cada día.
        Voy a empezar con frases cortas.
        Necesito escuchar diferentes ejemplos.
        A veces me cuesta recordar las palabras.
        No pasa nada si cometo errores.
        Puedo repetir una frase varias veces.
        Voy a revisar lo que aprendí.
        Me gustaría mantener una conversación sencilla.
        Cada pequeño paso me ayuda a mejorar.
        """),
    ]
    static func samplePractices() throws -> [Self] {
        let entries = [(title: sampleTitle, text: samplePracticeText)] + additionalPracticeExamples
        let date = Date()
        return try entries.enumerated().map { index, entry in
            var practice = try edited(title: entry.title, text: entry.text)
            let suffix = String(index + 1)
            practice.id = UUID(uuidString: "72E00000-0000-4000-8000-" + String(repeating: "0", count: 12 - suffix.count) + suffix)!
            practice.updatedAt = date.addingTimeInterval(-Double(index))
            return practice
        }
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
                if (archive.sampleRevision ?? 0) < 2 {
                    // Preserve the complete previous archive before removing the retired story example.
                    let backup = folder.appendingPathComponent("trainings-before-samples-v2.json")
                    if !FileManager.default.fileExists(atPath: backup.path) {
                        try Data(contentsOf: file).write(to: backup, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                    }
                    let retired = trainings.filter { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare("Los tres cerditos") == .orderedSame }
                    trainings.removeAll { practice in retired.contains { $0.id == practice.id } }
                    for var sample in try EnglishTraining.samplePractices() {
                        if trainings.contains(where: { $0.id == sample.id || $0.title == sample.title }) { continue }
                        if sample.title == EnglishTraining.sampleTitle, let old = retired.first { sample.id = old.id }
                        trainings.append(sample)
                    }
                    try persist(trainings)
                }
            } catch { throw EnglishTrainingFailure.unsupportedFile }
        } else {
            trainings = try EnglishTraining.samplePractices()
            try persist(trainings)
        }
    }
    func training(_ id: UUID) -> EnglishTraining? { trainings.first { $0.id == id } }
    private func persist(_ values: [EnglishTraining]) throws {
        let data = try JSONEncoder().encode(Archive(trainings: values, sampleRevision: 2))
        try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    func save(_ training: EnglishTraining) throws {
        guard training.valid else { throw EnglishTrainingFailure.invalidInput }
        var values = trainings
        if let index = values.firstIndex(where: { $0.id == training.id }) { values[index] = training }
        else { values.append(training) }
        try persist(values); trainings = values
    }
    func setPracticePresentation(_ id: UUID, showResponse: Bool? = nil, slowExample: Bool? = nil) throws {
        guard var training = training(id) else { throw EnglishTrainingFailure.changed }
        if let showResponse { training.showPracticeResponse = showResponse }
        if let slowExample { training.slowPracticeExample = slowExample }
        // A display preference does not alter phrases, corrections or library ordering.
        try save(training)
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
            guard let index = training.phrases.firstIndex(where: { $0.id == original.id && $0.spanish == original.text && ($0.english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || snapshot != nil) }) else { throw EnglishTrainingFailure.changed }
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
