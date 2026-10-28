import Foundation
import Observation

struct SavedStoryTranslation: Codable, Equatable {
    var snapshot: TranslationSnapshot
    var reviewed: Bool
}

struct StoryDocument: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var sourceLanguage: CaptureLanguage
    var targetLanguage: CaptureLanguage
    var paragraphs: [ReviewParagraph]
    var translation: TranslationSnapshot?
    var translationReviewed = false
    // Optional so archives written before multilingual storage still decode unchanged.
    var savedTranslations: [String: SavedStoryTranslation]? = nil
    var hasTranslations: Bool { translation != nil || !(savedTranslations ?? [:]).isEmpty }
    mutating func rememberTranslation() {
        if let translation {
            var saved = savedTranslations ?? [:]
            saved[targetLanguage.rawValue] = SavedStoryTranslation(snapshot: translation, reviewed: translationReviewed)
            savedTranslations = saved
        }
    }
    mutating func selectTarget(_ target: CaptureLanguage) {
        guard target != targetLanguage else { return }
        rememberTranslation()
        targetLanguage = target
        let saved = savedTranslations?[target.rawValue]
        translation = saved?.snapshot
        translationReviewed = saved?.reviewed ?? false
    }
    var updatedAt = Date()
    var sourceText: String { paragraphs.map(\.text).joined(separator: "\n\n") }
    var translatedText: String { translation?.translated.map(\.text).joined(separator: "\n\n") ?? "" }
    var translatedReady: Bool { translationReviewed && translation?.isCurrent(paragraphs) == true }
    var valid: Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, title.count <= 100,
              sourceLanguage != targetLanguage, !paragraphs.isEmpty, paragraphs.count <= 200,
              sourceText.count <= 20_000, Set(paragraphs.map(\.id)).count == paragraphs.count,
              paragraphs.allSatisfy({ !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.text.count <= 1_000 }) else { return false }
        if let translation {
            guard translation.language == sourceLanguage, translation.target == targetLanguage,
                  translation.isCurrent(paragraphs),
                  translation.translated.allSatisfy({ $0.text.count <= 2_000 }) else { return false }
            do { try translation.validate() } catch { return false }
        } else if translationReviewed { return false }
        for (locale, saved) in savedTranslations ?? [:] {
            guard let target = CaptureLanguage(rawValue: locale), target != sourceLanguage,
                  saved.snapshot.language == sourceLanguage, saved.snapshot.target == target,
                  saved.snapshot.isCurrent(paragraphs),
                  saved.snapshot.translated.allSatisfy({ $0.text.count <= 2_000 }) else { return false }
            do { try saved.snapshot.validate() } catch { return false }
        }
        return true
    }
    static func edited(title: String, text: String, source: CaptureLanguage, target: CaptureLanguage,
                       previous: Self? = nil) throws -> Self {
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        var result = previous ?? Self(title: title, sourceLanguage: source, targetLanguage: target, paragraphs: [])
        let changed = previous.map { $0.paragraphs.map(\.text) != lines || $0.sourceLanguage != source } ?? true
        if changed {
            result.paragraphs = lines.map { ReviewParagraph(id: UUID(), text: $0) }
            result.translation = nil; result.translationReviewed = false; result.savedTranslations = nil
        }
        if !changed { result.selectTarget(target) }
        result.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        result.sourceLanguage = source; result.targetLanguage = target; result.updatedAt = Date()
        guard result.valid else { throw StoryFailure.invalid }
        return result
    }
}

enum StoryFailure: LocalizedError {
    case invalid, changed, unreadable
    var errorDescription: String? {
        switch self {
        case .invalid: "Use a title of up to 100 characters and a story of up to 20,000 characters, with different source and translation languages. Each paragraph can have up to 1,000 characters."
        case .changed: "This story changed. Reopen it and try again. Your saved story is unchanged."
        case .unreadable: "The story library could not be opened. Its files have not been replaced or deleted."
        }
    }
}

/// Independent files: no session database or training archive is read, migrated or modified.
@MainActor @Observable
final class StoryStore {
    private struct Archive: Codable {
        var version = 1
        var stories: [StoryDocument]
        var installedExamples: [UUID]?
    }
    private var installedExamples: Set<UUID> = []
    private(set) var stories: [StoryDocument]
    private let file: URL
    init(directory: URL? = nil) throws {
        var folder = try directory ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("VoiceToRead/Stories", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        var values = URLResourceValues(); values.isExcludedFromBackup = true; try folder.setResourceValues(values)
        file = folder.appendingPathComponent("stories.json")
        if FileManager.default.fileExists(atPath: file.path) {
            do {
                let archive = try JSONDecoder().decode(Archive.self, from: Data(contentsOf: file))
                guard archive.version == 1, archive.stories.allSatisfy(\.valid),
                      Set(archive.stories.map(\.id)).count == archive.stories.count else { throw StoryFailure.unreadable }
                stories = archive.stories
                installedExamples = Set(archive.installedExamples ?? [])
            } catch { throw StoryFailure.unreadable }
        } else {
            stories = []
        }
        // Persist additions and installation markers together. Deleted examples stay deleted.
        var changed = false
        for entry in StoryExampleCatalog.entries where !installedExamples.contains(entry.id) {
            if !stories.contains(where: { entry.matches($0) }) {
                stories.append(try entry.document())
            }
            installedExamples.insert(entry.id)
            changed = true
        }
        if changed { try persist(stories) }
    }
    func story(_ id: UUID) -> StoryDocument? { stories.first { $0.id == id } }
    private func persist(_ values: [StoryDocument]) throws {
        let data = try JSONEncoder().encode(Archive(stories: values, installedExamples: installedExamples.sorted { $0.uuidString < $1.uuidString }))
        try data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    func save(_ story: StoryDocument, replacing previous: StoryDocument? = nil) throws {
        guard story.valid else { throw StoryFailure.invalid }
        if let previous { guard self.story(previous.id) == previous else { throw StoryFailure.changed } }
        var values = stories
        if let i = values.firstIndex(where: { $0.id == story.id }) { values[i] = story }
        else { values.append(story) }
        try persist(values); stories = values
    }
    func selectTarget(_ previous: StoryDocument, target: CaptureLanguage) throws {
        guard target != previous.sourceLanguage else { throw StoryFailure.invalid }
        guard story(previous.id) == previous else { throw StoryFailure.changed }
        guard target != previous.targetLanguage else { return }
        var result = previous
        result.selectTarget(target)
        result.updatedAt = Date()
        try save(result, replacing: previous)
    }
    func acceptTranslation(_ previous: StoryDocument, responses: [ReviewParagraph], target: CaptureLanguage? = nil) throws {
        guard story(previous.id) == previous else { throw StoryFailure.changed }
        var result = previous
        // Preserve every other language, including legacy single-translation archives.
        result.rememberTranslation()
        result.targetLanguage = target ?? previous.targetLanguage
        guard result.targetLanguage != previous.sourceLanguage else { throw StoryFailure.invalid }
        var snapshot = TranslationSnapshot(source: previous.paragraphs, generated: responses)
        snapshot.sourceLocale = previous.sourceLanguage.rawValue; snapshot.targetLocale = result.targetLanguage.rawValue
        try snapshot.validate()
        result.translation = snapshot; result.translationReviewed = false; result.updatedAt = Date()
        try save(result, replacing: previous)
    }
    func review(_ previous: StoryDocument, corrections: [UUID: String]) throws {
        guard var snapshot = previous.translation, corrections.count == previous.paragraphs.count,
              previous.paragraphs.allSatisfy({ !(corrections[$0.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { throw StoryFailure.invalid }
        snapshot.edits = Dictionary(uniqueKeysWithValues: corrections.map { ($0.key.uuidString, $0.value.trimmingCharacters(in: .whitespacesAndNewlines)) })
        var result = previous
        result.translation = snapshot; result.translationReviewed = true; result.updatedAt = Date()
        try save(result, replacing: previous)
    }
    func delete(_ previous: StoryDocument) throws {
        guard story(previous.id) == previous else { throw StoryFailure.changed }
        let values = stories.filter { $0.id != previous.id }
        try persist(values); stories = values
    }
}

/// Original short retellings; The Little Prince is a brief summary, not the book.
enum StoryExampleCatalog {
    // Covers are derived from the example identity; user archives are never rewritten.
    static func coverName(for story: StoryDocument) -> String? {
        guard let entry = entries.first(where: { $0.id == story.id }) ?? entries.first(where: { $0.matches(story) }) else { return nil }
        return "story-" + entry.id.uuidString.lowercased()
    }
    struct Entry {
        let id: UUID
        let title: String
        let aliases: [String]
        let text: String
        func matches(_ story: StoryDocument) -> Bool {
            func normalized(_ value: String) -> String {
                value.trimmingCharacters(in: .whitespacesAndNewlines)
                    .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es"))
            }
            return story.id == id || ([title] + aliases).contains { normalized($0) == normalized(story.title) }
        }
        func document() throws -> StoryDocument {
            var story = try StoryDocument.edited(title: title, text: text, source: .spanish, target: .english)
            story.id = id
            return story
        }
    }
    static let entries: [Entry] = [
        Entry(id: UUID(uuidString: "57100000-0000-4000-8000-000000000001")!, title: "Caperucita Roja", aliases: [], text: """
Una niña llevaba una capa roja.
Todos la llamaban Caperucita Roja.
Una mañana, su madre preparó una cesta de comida.
La abuela estaba enferma y necesitaba descansar.
Caperucita salió por el camino del bosque.
Su madre le pidió que no se apartara del sendero.
Un lobo apareció entre los árboles.
Le preguntó a dónde iba y la niña se lo contó.
El lobo tomó un atajo hasta la casa de la abuela.
La abuela lo vio llegar y se escondió en un armario.
El lobo se puso su gorro y se acostó en la cama.
Cuando llegó Caperucita, notó algo extraño.
Aquella voz y aquellas orejas no eran las de su abuela.
La niña retrocedió y pidió ayuda desde la puerta.
Una persona que cuidaba el bosque escuchó sus gritos.
Entró en la casa y el lobo huyó asustado.
La abuela salió de su escondite y abrazó a su nieta.
Después compartieron la comida y hablaron de cómo cuidarse.
"""),
        Entry(id: UUID(uuidString: "57100000-0000-4000-8000-000000000002")!, title: "Rapunzel", aliases: ["Rapunsel"], text: """
Rapunzel vivía en una torre muy alta.
Tenía el cabello largo y le gustaba cantar.
Una hechicera no la dejaba salir de la torre.
Cuando quería entrar, le pedía que bajara su trenza.
Un día, un joven escuchó una canción junto al bosque.
Miró hacia arriba y vio a Rapunzel en la ventana.
Ella le contó que soñaba con conocer el mundo.
El joven regresó con hilo para hacer una escalera.
Rapunzel tejía un poco cada día.
Pero la hechicera descubrió su plan.
Le cortó la trenza y la llevó a un lugar lejano.
El joven buscó a su amiga por muchos caminos.
Rapunzel también caminó en busca de ayuda.
Una tarde comenzó a cantar para darse ánimo.
El joven reconoció la canción y la encontró.
Juntos llegaron a un pueblo donde fueron bien recibidos.
Rapunzel pudo elegir su hogar y hacer nuevos amigos.
Por fin cantaba con la ventana y la puerta abiertas.
"""),
        Entry(id: UUID(uuidString: "57100000-0000-4000-8000-000000000003")!, title: "Los tres cerditos", aliases: [], text: EnglishTraining.firstText),
        Entry(id: UUID(uuidString: "57100000-0000-4000-8000-000000000004")!, title: "El patito feo", aliases: [], text: """
En una granja nacieron varios patitos.
El último salió de un huevo grande.
Era más alto y tenía las plumas grises.
Algunos animales se burlaban de él por ser diferente.
El pequeño se sintió solo y se fue de la granja.
Caminó hasta un estanque rodeado de árboles.
Allí encontró agua y un lugar para descansar.
Cuando llegó el invierno, tuvo mucho frío.
Una familia lo ayudó y le dio refugio.
Con la primavera, el pequeño volvió al estanque.
Sus alas eran ahora grandes y fuertes.
Vio unos cisnes blancos sobre el agua.
Se acercó despacio, esperando que lo aceptaran.
Entonces miró su reflejo en el estanque.
Él también era un cisne.
Los otros cisnes lo recibieron con alegría.
Ya no se sentía solo.
Comprendió que ser diferente nunca había sido un defecto.
"""),
        Entry(id: UUID(uuidString: "57100000-0000-4000-8000-000000000005")!, title: "Pinocho", aliases: [], text: """
Gepeto era un carpintero que vivía en una casa pequeña.
Un día hizo un muñeco de madera y lo llamó Pinocho.
Un hada le dio vida al muñeco.
Gepeto lo abrazó y le preparó ropa para ir a la escuela.
Pinocho tenía curiosidad por todo.
En el camino, siguió a unos desconocidos hasta un teatro.
Se olvidó de la escuela y después no supo volver.
Cuando el hada le preguntó qué había pasado, dijo una mentira.
Su nariz de madera comenzó a crecer.
Pinocho contó la verdad y pidió ayuda.
El hada le enseñó el camino de regreso.
Pero Gepeto había salido a buscarlo cerca del mar.
Una gran criatura marina se había tragado su barca.
Pinocho fue a rescatarlo y también acabó dentro.
Juntos encendieron una pequeña fogata para hacerla estornudar.
Así lograron salir y llegar a la orilla.
Pinocho cuidó de Gepeto y se esforzó por cumplir sus promesas.
Al ver su cariño y su valentía, el hada lo convirtió en un niño.
"""),
        Entry(id: UUID(uuidString: "57100000-0000-4000-8000-000000000006")!, title: "Blancanieves", aliases: ["Blanca nieves"], text: """
Blancanieves vivía en un castillo con una reina orgullosa.
La reina sentía celos de la joven y quería alejarla.
Blancanieves buscó refugio en el bosque.
Al caer la tarde, encontró una casita con siete sillas pequeñas.
Allí vivían siete amigos que trabajaban en una mina.
Ellos la recibieron y compartieron su hogar.
Blancanieves los ayudaba y aprendía a vivir en el bosque.
La reina descubrió dónde estaba y se disfrazó de vendedora.
Llevó una manzana encantada hasta la casita.
Blancanieves probó un trozo y cayó en un sueño profundo.
Sus amigos regresaron y la encontraron dormida.
Pidieron ayuda a todas las personas que conocían.
Un viajero llegó al bosque y se ofreció a colaborar.
Al mover con cuidado a Blancanieves, se soltó el trozo de manzana.
Ella abrió los ojos y volvió a respirar con normalidad.
Todos celebraron su despertar.
La joven decidió vivir rodeada de personas que la querían.
La reina ya no pudo decidir por ella.
"""),
        Entry(id: UUID(uuidString: "57100000-0000-4000-8000-000000000007")!, title: "Cenicienta", aliases: [], text: """
Cenicienta vivía con su madrastra y sus dos hermanastras.
Le dejaban todas las tareas y pocas veces la trataban con cariño.
Un día llegó una invitación para un baile en el palacio.
Cenicienta también quería asistir.
Pero su familia se marchó y la dejó en casa.
Entonces apareció su hada madrina.
Con su magia, preparó un vestido y una carroza.
También le dio unos zapatos de cristal.
Le explicó que la magia terminaría a medianoche.
En el baile, Cenicienta conoció al príncipe y bailó con él.
Cuando oyó el reloj, salió corriendo.
En la escalera perdió uno de sus zapatos.
El príncipe recorrió el reino para encontrar a su dueña.
Muchas personas probaron el zapato, pero no les quedaba.
Cuando llegó a la casa de Cenicienta, ella pidió probarlo.
El zapato le quedó perfectamente.
El príncipe la reconoció y la invitó a volver al palacio.
Cenicienta pudo comenzar una vida en la que la trataran con respeto.
"""),
        Entry(id: UUID(uuidString: "57100000-0000-4000-8000-000000000008")!, title: "Hansel y Gretel", aliases: ["Hänsel y Gretel"], text: """
Hansel y Gretel eran dos hermanos que vivían cerca de un bosque.
Una mañana se alejaron de casa y perdieron el camino.
Hansel dejó migas de pan para recordar por dónde habían pasado.
Pero los pájaros se comieron las migas.
Los hermanos caminaron hasta encontrar una casa de dulces.
Tenía paredes de galleta y ventanas de azúcar.
Una anciana los invitó a entrar y les dio comida.
En realidad, era una bruja que no quería dejarlos salir.
Encerró a Hansel y obligó a Gretel a trabajar.
Los hermanos hablaron en voz baja y buscaron un plan.
Un día, la bruja le pidió a Gretel que mirara dentro del horno.
Gretel le dijo que no sabía cómo hacerlo.
Cuando la bruja se acercó para enseñarle, Gretel cerró la puerta de la cocina.
Después tomó la llave y liberó a Hansel.
Los dos salieron de la casa sin detenerse.
Junto al río encontraron a un leñador que conocía el camino.
Él los acompañó hasta su hogar.
Los hermanos se abrazaron, felices de volver juntos y a salvo.
"""),
        Entry(id: UUID(uuidString: "57100000-0000-4000-8000-000000000009")!, title: "El gato con botas", aliases: [], text: """
Un joven recibió un gato como única herencia.
El gato le pidió una bolsa y un par de botas.
El joven se sorprendió, pero decidió ayudarlo.
Con sus botas nuevas, el gato salió a buscar fortuna.
Llevó varios regalos al rey en nombre de su dueño.
Decía que venían de un importante marqués.
Un día supo que el rey pasaría junto al río.
Le pidió al joven que se bañara mientras él preparaba un plan.
Cuando llegó la carroza, el gato pidió ropa para su dueño.
El rey lo invitó a viajar con él y con su hija.
Mientras tanto, el gato corrió hasta el castillo de un ogro.
El ogro presumía de poder convertirse en cualquier animal.
El gato le preguntó si también podía hacerse tan pequeño como un ratón.
El ogro se transformó y el gato lo persiguió hasta que huyó del castillo.
Cuando llegó el rey, el gato recibió a todos en la entrada.
El joven contó después la verdad sobre su origen humilde.
La hija del rey valoró su sinceridad y quiso conocerlo mejor.
El joven nunca olvidó la ayuda de su ingenioso gato.
"""),
        Entry(id: UUID(uuidString: "57100000-0000-4000-8000-000000000010")!, title: "El flautista de Hamelín", aliases: ["El flautista de hamelin"], text: """
En la ciudad de Hamelín había demasiados ratones.
Entraban en las casas y se comían la comida.
Los vecinos no sabían cómo resolver el problema.
Un día llegó un músico con una flauta.
Prometió llevarse a los ratones a cambio de una recompensa.
Las autoridades aceptaron su propuesta.
El músico comenzó a tocar una melodía por las calles.
Los ratones salieron de todos los rincones y lo siguieron.
El flautista los llevó lejos de la ciudad.
Cuando regresó, las autoridades no quisieron pagarle.
El músico se marchó muy decepcionado.
Al día siguiente volvió a tocar, esta vez otra melodía.
Los niños lo siguieron hasta una colina cercana.
Las familias salieron a buscarlos y pidieron que regresaran.
Las autoridades reconocieron que habían faltado a su palabra.
Pagaron la recompensa y pidieron disculpas al músico.
Él acompañó a los niños de vuelta a sus casas.
Desde entonces, los vecinos recordaron la importancia de cumplir sus promesas.
"""),
        Entry(id: UUID(uuidString: "57100000-0000-4000-8000-000000000011")!, title: "El principito · Resumen breve", aliases: ["El principito"], text: """
Este es un resumen breve de una historia sobre la amistad.
Un piloto tiene un problema con su avión y aterriza en el desierto.
Allí conoce a un niño que viene de un planeta muy pequeño.
El niño le cuenta que en su hogar hay una rosa a la que cuida.
Antes de llegar a la Tierra, ha visitado otros planetas.
En ellos ha conocido a personas preocupadas por mandar, recibir elogios o poseer cosas.
Sus encuentros le hacen pensar en lo que cada persona considera importante.
En la Tierra conoce también a un zorro.
Con él descubre que la amistad necesita tiempo y atención.
El niño comprende mejor el cariño que siente por su rosa.
Mientras escucha sus viajes, el piloto comienza a ver el mundo de otra manera.
En medio del desierto, ambos buscan agua y se acompañan.
El niño desea regresar a su hogar y el piloto debe continuar su camino.
Aunque se separan, el recuerdo de su amistad permanece.
La historia invita a cuidar nuestros vínculos y a mirar con curiosidad.
""")
    ]
}
