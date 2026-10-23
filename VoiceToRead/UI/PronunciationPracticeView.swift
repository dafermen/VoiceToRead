import SwiftUI
import AVFoundation
import Speech

/// A text match describes recognition, never pronunciation quality or a phoneme score.
enum PracticeRecognition {
    static func words(_ text: String) -> [String] {
        if SubtitleExport.containsUnspacedScript(text) {
            return text.lowercased().filter { $0.isLetter || $0.isNumber }.map { String($0) }
        }
        return text.lowercased().replacingOccurrences(of: "’", with: "'")
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "'" }).map(String.init)
    }
    static func matches(_ heard: String, target: String) -> Bool {
        let expected = words(target)
        return !expected.isEmpty && words(heard) == expected
    }
    /// Short chunks avoid a long, tiring recording. Single words are also selectable.
    static func prompts(_ text: String) -> [String] {
        let words = SubtitleExport.textUnits(text)
        let separator = SubtitleExport.containsUnspacedScript(text) ? "" : " "
        var values: [String] = []
        for start in stride(from: 0, to: words.count, by: 8) {
            values.append(words[start..<min(start + 8, words.count)].joined(separator: separator))
        }
        values += words.map { $0.trimmingCharacters(in: .punctuationCharacters) }.filter { !$0.isEmpty }
        var seen = Set<String>()
        return values.filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }
    static func request(url: URL) -> SFSpeechURLRecognitionRequest {
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        // Do not hint the expected answer: doing so would bias a practice check.
        request.contextualStrings = []
        return request
    }
}

/// Only this dedicated temporary directory is removed; session media is never touched.
enum PracticeFiles {
    static var root: URL { FileManager.default.temporaryDirectory.appendingPathComponent("PronunciationPractice", isDirectory: true) }
    static func removeAbandonedAttempts(in directory: URL = Self.root) { try? FileManager.default.removeItem(at: directory) }
    static func createDirectory(in root: URL = Self.root) throws -> URL {
        var directory = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete])
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        return directory
    }
}

/// Owns one short, temporary take. Generation IDs reject late permission/recognition callbacks.
/// All audio actions are exclusive; leaving/interruption cancels and removes the take.
@MainActor @Observable
final class PronunciationPractice {
    enum Activity { case idle, permission, recording, example, playback, checking }
    private(set) var activity: Activity = .idle
    private(set) var elapsed = 0.0
    private(set) var level = 0.0
    private(set) var take: URL?
    private(set) var heard: String?
    var message: String?
    private(set) var needsSettings = false
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var synthesizer = AVSpeechSynthesizer()
    private var recognizer: SFSpeechRecognizer?
    private var recognition: SFSpeechRecognitionTask?
    private var ticker: Task<Void, Never>?
    private var generation = UUID()
    private var directory: URL?
    private var observers: [NSObjectProtocol] = []
    let language: CaptureLanguage
    private let microphonePermission: () async -> Bool

    init(language: CaptureLanguage = .english, microphonePermission: @escaping () async -> Bool = { await AVAudioApplication.requestRecordPermission() }) {
        self.language = language
        self.microphonePermission = microphonePermission
    }
    func observeInterruptions() {
        guard observers.isEmpty else { return }
        for name in [AVAudioSession.interruptionNotification, AVAudioSession.routeChangeNotification,
                     AVAudioSession.mediaServicesWereResetNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                // Category changes are caused by our own playback/recording transitions.
                if name == AVAudioSession.routeChangeNotification {
                    let reason = (notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? NSNumber)?.uintValue
                    guard reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue ||
                          reason == AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue else { return }
                }
                Task { @MainActor [weak self] in
                    guard let self, self.activity != .idle else { return }
                    self.reset(); self.message = "La práctica se interrumpió. Cuando estés listo, inténtalo otra vez."
                }
            })
        }
    }
    private func activate(_ category: AVAudioSession.Category, mode: AVAudioSession.Mode) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(category, mode: mode, options: category == .playAndRecord ? [.defaultToSpeaker, .allowBluetooth] : [])
        try session.setActive(true)
    }
    private func stopActivity() {
        generation = UUID()
        ticker?.cancel(); ticker = nil
        recognition?.cancel(); recognition = nil; recognizer = nil
        recorder?.stop(); recorder = nil
        player?.stop(); player = nil
        synthesizer.stopSpeaking(at: .immediate)
        activity = .idle; level = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    func reset() {
        stopActivity()
        take = nil; heard = nil; message = nil; needsSettings = false; elapsed = 0
        if let directory { try? FileManager.default.removeItem(at: directory) }
        directory = nil
    }
    func close() {
        reset()
        observers.forEach(NotificationCenter.default.removeObserver); observers = []
    }
    func stopPlayback() { stopActivity() }

    func listen(_ text: String, slow: Bool) {
        stopActivity(); message = nil; needsSettings = false
        guard let voice = PlaybackVoicePreference.voice(for: language) else {
            needsSettings = true
            message = "No hay una voz para este idioma disponible. Revisa las voces del idioma elegido en Ajustes del dispositivo."; return
        }
        do {
            try activate(.playback, mode: .spokenAudio)
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = voice; utterance.rate = slow ? 0.35 : AVSpeechUtteranceDefaultSpeechRate
            synthesizer.speak(utterance); activity = .example
            let token = generation
            ticker = Task { @MainActor [weak self] in
                // Give the speech engine time to start before checking completion.
                try? await Task.sleep(for: .milliseconds(500))
                while let self, self.generation == token, !Task.isCancelled {
                    if !self.synthesizer.isSpeaking { self.stopActivity(); return }
                    do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                }
            }
        } catch { stopActivity(); message = "No se pudo reproducir el ejemplo. Inténtalo de nuevo." }
    }
    func startRecording() async {
        reset(); activity = .permission
        let token = generation
        let allowed = await microphonePermission()
        guard generation == token, !Task.isCancelled else { return }
        guard allowed else {
            activity = .idle
            message = "Permite el micrófono en Ajustes del dispositivo → VoiceToRead para practicar. Puedes seguir escuchando ejemplos."
            return
        }
        do {
            try activate(.playAndRecord, mode: .default)
            let folder = try PracticeFiles.createDirectory(); directory = folder
            let url = folder.appendingPathComponent("attempt.wav")
            let recorder = try AVAudioRecorder(url: url, settings: [AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 16000, AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false])
            self.recorder = recorder
            guard recorder.prepareToRecord() else { throw RecordingFailure.unavailable }
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
            recorder.isMeteringEnabled = true
            guard recorder.record(forDuration: 15) else { throw RecordingFailure.unavailable }
            activity = .recording
            ticker = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                    guard let self, self.generation == token, let recorder = self.recorder else { return }
                    recorder.updateMeters()
                    self.level = max(0, min(1, Double((recorder.averagePower(forChannel: 0) + 60) / 60)))
                    self.elapsed = min(15, recorder.currentTime)
                    if !recorder.isRecording { self.finishRecording(); return }
                }
            }
        } catch { reset(); message = "No se pudo grabar. Comprueba el micrófono y vuelve a intentar." }
    }
    func finishRecording() {
        guard activity == .recording, let recorder else { return }
        let url = recorder.url
        stopActivity()
        do {
            let audio = try AVAudioPlayer(contentsOf: url)
            guard audio.duration >= 0.4 else { reset(); message = "La grabación fue muy corta. Toca el micrófono y di la frase con calma."; return }
            take = url; elapsed = audio.duration
        } catch { reset(); message = "No se pudo abrir tu grabación. Inténtalo otra vez." }
    }
    func listenToTake() {
        guard let take else { return }
        stopActivity(); message = nil
        do {
            try activate(.playback, mode: .spokenAudio)
            let player = try AVAudioPlayer(contentsOf: take); self.player = player
            guard player.play() else { throw RecordingFailure.unavailable }
            activity = .playback
            let token = generation
            ticker = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                    guard let self, self.generation == token else { return }
                    if self.player?.isPlaying != true { self.stopActivity(); return }
                }
            }
        } catch { stopActivity(); message = "No se pudo reproducir tu voz. Puedes volver a grabar." }
    }
    func checkWords() async {
        guard let take else { return }
        stopActivity(); heard = nil; message = nil; activity = .checking
        let token = generation
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { _ in continuation.resume() }
            }
        }
        guard generation == token, !Task.isCancelled else { return }
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            stopActivity(); message = "Para mostrar qué entendió el dispositivo, permite reconocimiento de voz en Ajustes. Aún puedes escuchar y comparar."; return
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language.rawValue)),
              recognizer.supportsOnDeviceRecognition, recognizer.isAvailable else {
            stopActivity(); message = "El reconocimiento local del idioma elegido no está disponible. Puedes escuchar tu voz y compararla con el ejemplo."; return
        }
        self.recognizer = recognizer
        recognition = recognizer.recognitionTask(with: PracticeRecognition.request(url: take)) { [weak self] result, error in
            let text = result?.isFinal == true ? result?.bestTranscription.formattedString : nil
            let failed = error != nil
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.stopActivity(); self.heard = text
                } else if failed || text != nil {
                    self.stopActivity(); self.message = "No se entendió suficiente audio. Busca un lugar tranquilo y vuelve a intentar; esto no califica tu pronunciación."
                }
            }
        }
        ticker = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(15)) } catch { return }
            guard let self, self.generation == token else { return }
            self.stopActivity(); self.message = "El reconocimiento tardó demasiado. Puedes escuchar tu voz o intentarlo otra vez."
        }
    }
}

@MainActor
struct PronunciationPracticeView: View {
    let text: String
    let language: CaptureLanguage
    init(text: String, language: CaptureLanguage = .english) {
        self.text = text; self.language = language
        _practice = State(initialValue: PronunciationPractice(language: language))
    }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var practice: PronunciationPractice
    @State private var selection = 0
    @State private var slow = false
    private var prompts: [String] { PracticeRecognition.prompts(text) }
    private var target: String { prompts.indices.contains(selection) ? prompts[selection] : language.greeting }
    private var busy: Bool { practice.activity == .recording || practice.activity == .permission || practice.activity == .checking }
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let message = practice.message {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Practice notice", systemImage: "exclamationmark.circle.fill").font(.headline)
                            Text(LocalizedStringKey(message)).fixedSize(horizontal: false, vertical: true)
                            if practice.needsSettings {
                                Text("For voices, open device Settings → Accessibility → Spoken Content → Voices and download a voice for the spoken language. Names may vary by iOS version.").font(.subheadline)
                                Button("Open Settings") {
                                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                                }.buttonStyle(.borderedProminent)
                            }
                        }.padding().frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                            .accessibilityIdentifier("pronunciationNotice").id("practiceNotice")
                    }
                    Text("Escucha · Pronuncia · Compara").font(.subheadline).foregroundStyle(.secondary)
                    Text(target).font(.title2.bold()).textSelection(.enabled).accessibilityIdentifier("pronunciationTarget")
                    Menu {
                        Picker("Palabra o frase", selection: $selection) {
                            ForEach(prompts.indices, id: \.self) { index in Text(prompts[index]).tag(index) }
                        }
                    } label: { Label("Cambiar palabra o frase", systemImage: "text.cursor") }
                        .disabled(busy).accessibilityIdentifier("pronunciationPrompt")
                    VStack(alignment: .leading, spacing: 12) {
                        Text("1. Escucha el ejemplo").font(.headline)
                        Button(uiKey(practice.activity == .example ? "Detener ejemplo" : "Escuchar ejemplo"),
                               systemImage: practice.activity == .example ? "stop.fill" : "speaker.wave.2.fill") {
                            if practice.activity == .example { practice.stopPlayback() } else { practice.listen(target, slow: slow) }
                        }.buttonStyle(.bordered).disabled(busy).labelStyle(AccessibleControlLabelStyle()).accessibilityIdentifier("pronunciationExample")
                        Toggle("Más lento", isOn: $slow).disabled(busy).accessibilityIdentifier("pronunciationSlow")
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("2. Ahora tú").font(.headline)
                        Button {
                            if practice.activity == .recording { practice.finishRecording() }
                            else { Task { await practice.startRecording() } }
                        } label: {
                            Label(uiKey(practice.activity == .recording ? "Terminar" : (practice.take == nil ? "Pronunciar" : "Volver a grabar")),
                                  systemImage: practice.activity == .recording ? "stop.circle.fill" : "mic.circle.fill")
                                .frame(maxWidth: .infinity).padding(.vertical, 6)
                        }.buttonStyle(.borderedProminent).controlSize(.large)
                            .disabled(practice.activity == .permission || practice.activity == .checking)
                            .labelStyle(AccessibleControlLabelStyle()).accessibilityIdentifier("pronunciationRecord")
                        if practice.activity == .recording {
                            ProgressView(value: practice.level).accessibilityLabel("Nivel del micrófono")
                            Text("Grabando · \(Int(practice.elapsed)) / 15 s").monospacedDigit()
                        } else if practice.activity == .permission { ProgressView("Esperando permiso…") }
                        else { Text("Habla con calma. Se detiene a los 15 segundos.").font(.caption).foregroundStyle(.secondary) }
                    }
                    if practice.take != nil {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("3. Escucha y compara").font(.headline)
                            Button(uiKey(practice.activity == .playback ? "Detener mi voz" : "Escuchar mi voz"),
                                   systemImage: practice.activity == .playback ? "stop.fill" : "play.fill") {
                                if practice.activity == .playback { practice.stopPlayback() } else { practice.listenToTake() }
                            }.buttonStyle(.bordered).disabled(busy).labelStyle(AccessibleControlLabelStyle()).accessibilityIdentifier("pronunciationReplay")
                            Text("Alterna entre el ejemplo y tu voz. Prueba despacio y luego a tu ritmo.").font(.subheadline)
                            if practice.activity == .checking { ProgressView("Reconociendo en el dispositivo…") }
                            else {
                                Button(uiKey("¿Qué entendió el dispositivo?"), systemImage: "text.bubble") {
                                    Task { await practice.checkWords() }
                                }.disabled(busy).labelStyle(AccessibleControlLabelStyle()).accessibilityIdentifier("pronunciationCheck")
                            }
                            if let heard = practice.heard {
                                Text(heard).font(.title3).accessibilityIdentifier("pronunciationHeard")
                                Text(uiKey(PracticeRecognition.matches(heard, target: target)
                                     ? "El dispositivo reconoció el texto esperado. Escucha ambos audios para seguir practicando."
                                     : "El dispositivo entendió algo distinto. Puede influir el ruido o el reconocimiento; escucha ambos audios y prueba otra vez."))
                            }
                            Text("Esto comprueba palabras reconocidas, no evalúa sonidos ni califica tu pronunciación.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Text("Tu práctica queda en este dispositivo y se borra al salir, cambiar de palabra o volver a grabar.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding()
            }
            .onChange(of: practice.message) { _, message in
                if message != nil { withAnimation { proxy.scrollTo("practiceNotice", anchor: .top) } }
            }
            }
            .navigationTitle("Pronunciación").navigationBarTitleDisplayMode(.inline)
            .toolbar { DoneToolbar { practice.close(); dismiss() } }
            .onAppear { practice.observeInterruptions() }
            .onChange(of: selection) { _, _ in practice.reset() }
            .onChange(of: phase) { _, value in
                if value == .background { practice.reset(); practice.message = "Práctica pausada al salir de la app. Puedes empezar otra vez cuando quieras." }
            }
            .onDisappear { practice.close() }
        }
    }
}
