import SwiftUI
import AVFoundation
import UIKit
import SwiftData

@MainActor
struct SettingsView: View {
    @Bindable var settings: AppSettings
    let coordinator: SessionCoordinator

    var body: some View {
        Form {
            Section("Accessibility and ease of use") {
                Toggle("Simple mode", isOn: $settings.simpleMode).disabled(coordinator.caption.state.active || coordinator.caption.state.busy).accessibilityIdentifier("simpleModeToggle")
                Toggle("Show button names", isOn: $settings.showButtonNames).accessibilityIdentifier("buttonNamesToggle")
                Toggle("Vibrate when listening pauses", isOn: $settings.pauseHaptics)
                Toggle("Focused reading", isOn: $settings.focusedReading).accessibilityIdentifier("focusedReadingToggle")
                Text("Simple mode keeps essential actions visible. Focused reading shows one paragraph at a time and waits for you to continue.").font(.caption)
                NavigationLink("Write a response") { WrittenResponseView(coordinator: coordinator) }
            }
            Section("App interface") {
                Picker("Menus and buttons", selection: $settings.interfaceLanguage) {
                    ForEach(InterfaceLanguage.allCases, id: \.self) { Text($0.name).tag($0) }
                }.accessibilityIdentifier("interfaceLanguagePicker")
                Text("Changes the app's menus and messages. It does not change speech recognition, recordings or translations.")
                    .font(.caption)
            }
            Section("Voice capture and captions") {
                Picker("Spoken language", selection: $settings.captureLanguage) {
                    ForEach(CaptureLanguage.allCases, id: \.self) { Text($0.name).tag($0) }
                }.disabled(!coordinator.caption.canChooseCaptureOptions)
                    .accessibilityIdentifier("captureLanguagePicker")
                Text(uiKey(coordinator.caption.canChooseCaptureOptions
                     ? "Elige el idioma que se habla. Inglés es el predeterminado; la traducción utiliza el otro idioma."
                     : "Esta sesión conserva su idioma. Termina y guarda o descarta la sesión; crea una nueva para cambiarlo."))
                    .font(.caption)
                LabeledContent("Idioma de esta sesión", value: coordinator.caption.language.name)
            }
            Section("Offline preparation") {
                NavigationLink("Offline Readiness") { OfflineReadinessView(coordinator: coordinator) }
                NavigationLink("Microphone Check") { MicrophoneCheckView() }
                    .disabled(coordinator.caption.state.active || coordinator.caption.state.busy)
            }
            CaptureOptionsView(model: coordinator.caption, settings: settings)
            Section("Personal vocabulary") {
                NavigationLink("Names & translation terms") { PersonalVocabularyView() }
            }
            Section("Captions") {
                CaptionSizeControl(size: $settings.captionSize)
                Toggle("Keep screen awake while listening", isOn: $settings.keepAwake)
                Picker("Appearance", selection: $settings.appearance) {
                    ForEach(AppAppearance.allCases, id: \.self) { appearance in
                        Text(LocalizedStringKey(appearance.rawValue.capitalized)).tag(appearance)
                    }
                }
            }
            ReaderPaperOptions(settings: settings)
            Section("Local sessions") {
                Text("While listening, a recovery draft saves final captions and optional audio on this device. After Stop, choose Save Session to keep it or Discard to delete it. Unfinished drafts appear separately in Sessions after reopening the app.")
                    .font(.caption)
                Text("Saved sessions are excluded from device backup. Export anything you need to keep.")
                    .font(.caption)
            }
            Section("Privacy") {
                NavigationLink("Privacy Policy") { PrivacyPolicyView() }
                Text("No accounts, analytics or tracking. Session audio is optional; pronunciation practice records temporary attempts only when you tap its microphone.")
            }
        }
        .navigationTitle(Text(verbatim: InterfaceLocalization.string("Settings", language: settings.interfaceLanguage)))
        .onChange(of: settings.captureLanguage) { _, _ in Task { await coordinator.changeCaptureLanguage() } }
    }
}

@MainActor
struct OfflineReadinessView: View {
    let coordinator: SessionCoordinator
    @Environment(\.scenePhase) private var phase
    @State private var permission = MicrophonePermission.undetermined
    @State private var storage = StorageReadiness(availableBytes: nil)
    @State private var instructions = false
    @State private var demo = false
    @State private var translationJob: TranslationJob?
    @State private var translationMessage = "Not checked on this visit"
    @Environment(\.dismiss) private var dismiss

    private var ready: Bool {
        permission == .granted && coordinator.caption.readiness == .ready && storage.ready
    }

    var body: some View {
        Form {
            Section {
                Text("Prepare once, then start when you are ready. Permission requests happen only when you choose the corresponding button. Recording never starts here.")
                Button("See a short demonstration") { demo = true }
            }
            Section("Listening languages") {
                LabeledContent("Capture language", value: InterfaceLocalization.string(coordinator.settings.captureLanguage.name, language: coordinator.settings.interfaceLanguage))
                LabeledContent("Translation", value: InterfaceLocalization.string(coordinator.settings.captureLanguage.opposite.name, language: coordinator.settings.interfaceLanguage))
                Text("Change the capture language in Settings before starting.").font(.caption)
                ForEach(CaptureLanguage.allCases, id: \.self) { language in
                    LabeledContent(LocalizedStringKey(language.name)) {
                        Text(uiKey(AVSpeechSynthesisVoice(language: language.rawValue) == nil ? "Voice unavailable" : "Voice available"))
                    }
                }
                Text("If a voice is unavailable, open device Settings → Accessibility → Spoken Content → Voices to download it. Test playback before your meeting.").font(.caption)
                NavigationLink("Microphone Check") { MicrophoneCheckView() }
            }
            Section("Required checks") {
                LabeledContent("Microphone") { Text(uiKey(permission == .granted ? "Ready" : "Permission needed")) }
                LabeledContent("Speech recognition") { Text(LocalizedStringKey(coordinator.caption.readiness.description)) }
                LabeledContent("Local storage") { Text(LocalizedStringKey(storage.description)) }
                LabeledContent("Offline transcription") { Text(uiKey(ready ? "Ready for offline test" : "Not ready")) }
                if permission == .undetermined {
                    Button("Allow Microphone") {
                        Task {
                            _ = await AVAudioApplication.requestRecordPermission()
                            refreshPermission()
                        }
                    }
                } else if permission == .denied {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }
                if coordinator.caption.readiness == .authorizationRequired {
                    Button("Allow Speech Recognition") {
                        Task { await coordinator.caption.requestSpeechPermission() }
                    }
                    .disabled(coordinator.caption.state.active || coordinator.caption.state.busy)
                } else if coordinator.caption.readiness == .authorizationDenied {
                    Button("Open Speech Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                }
                if coordinator.caption.readiness == .missingAssets {
                    Button("Install Selected Language Model") {
                        Task { await coordinator.caption.installAssets() }
                    }
                    .disabled(coordinator.caption.state.active || coordinator.caption.state.busy)
                    Text("Model installation needs Internet and may require additional storage.")
                }
                Button("Refresh Checks") { Task { await refresh() } }
            }
            Section("Translation preparation") {
                Text(LocalizedStringKey(translationMessage))
                Text("Translation is optional. Captions and recordings work without it. Apple may ask to download the selected languages.").font(.caption)
                Button("Prepare translation") {
                    let source = [ReviewParagraph(id: UUID(), text: coordinator.settings.captureLanguage == .english ? "Hello" : "Hola")]
                    translationJob = TranslationJob(plan: IncrementalTranslation(source: source, previous: nil, language: coordinator.settings.captureLanguage))
                    translationMessage = "Preparing translation…"
                }.disabled(translationJob != nil || coordinator.caption.state.active || coordinator.caption.state.busy)
                if translationJob != nil { ProgressView(); Button("Cancel") { translationJob = nil; translationMessage = "Not checked on this visit" } }
            }
            Section {
                Button("Test Offline Mode") { instructions = true }
                Text("Only a real offline test verifies your device. This screen does not detect Airplane Mode.")
                    .font(.caption)
            }
        }
        .navigationTitle("Offline Readiness")
        .toolbar(.visible, for: .navigationBar)
        .background {
            if let job = translationJob {
                TranslationRunner(job: job, progress: { _ in }) { result in
                    guard translationJob?.id == job.id else { return }
                    translationJob = nil
                    switch result {
                    case .success: translationMessage = "Translation test succeeded"
                    case .failure(let error): translationMessage = error.localizedDescription
                    }
                }.id(job.id)
            }
        }
        .sheet(isPresented: $demo) { AccessibilityDemoView() }
        .toolbar { Button("Done") { coordinator.settings.preparationSeen = true; dismiss() } }
        .onDisappear { translationJob = nil }
        .task { await refresh() }
        .onChange(of: phase) { _, phase in
            if phase == .active { Task { await refresh() } }
        }
        .sheet(isPresented: $instructions) {
            NavigationStack {
                List {
                    Text("1. While online, allow microphone and speech access as requested. Resolve the readiness checks. If recognition is unavailable, prepare Dictation for the selected language in device Settings. Install a model here only if that option is offered.")
                    Text("2. Enable Airplane Mode in Control Center or Settings, and turn Wi-Fi off.")
                    Text("3. Return to Captions, tap Start Listening, and speak a full sentence in your selected language.")
                    Text("4. Verify live and final captions appear; tap Stop and check the saved session.")
                    Text("5. Repeat before attending a conference. If a check fails, prepare the device while online.")
                }
                .navigationTitle("Test Offline Mode")
                .toolbar { Button("Done") { instructions = false } }
            }
        }
    }

    private func refreshPermission() {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: permission = .granted
        case .denied: permission = .denied
        case .undetermined: permission = .undetermined
        @unknown default: permission = .unavailable
        }
    }

    private func refresh() async {
        refreshPermission()
        storage = StorageReadiness.check(at: coordinator.repository.storageURL)
        await coordinator.caption.checkReadiness()
    }
}


struct PersonalVocabularyView: View {
    @AppStorage(PersonalVocabulary.key) private var saved = ""
    @State private var draft = ""
    @State private var applied = false
    var body: some View {
        Form {
            Section {
                Text("One short name or term per line. Use English = español for preferred translations. The pair is reversed for Spanish sessions.")
                Text("VoiceToRead\nmeeting = reunión\nOpenAI").font(.callout.monospaced()).foregroundStyle(.secondary)
                TextEditor(text: $draft).frame(minHeight: 200).autocorrectionDisabled()
                    .accessibilityLabel("Personal vocabulary").accessibilityIdentifier("vocabularyEditor")
                Text("\(PersonalVocabulary.terms(draft).count)/100 valid terms. Duplicate or empty terms and overlong entries are ignored.").font(.caption)
                Button(uiKey(applied ? "Saved" : "Save vocabulary")) {
                    saved = PersonalVocabulary.terms(draft).map { $0.source + " = " + $0.target }.joined(separator: "\n")
                    draft = saved; applied = true
                }.accessibilityIdentifier("saveVocabularyButton")
            } footer: {
                Text("Stored on this device. Recognition hints apply on the next recognition start. New translations use your preferred terms; saved translations stay unchanged until you replace them. Review grammar around translated terms.")
            }
        }
        .navigationTitle("Personal vocabulary")
        .onAppear { draft = saved }
        .onChange(of: draft) { _, _ in applied = draft == saved }
    }
}

/// The demonstration uses fixed text, never a microphone or stored user material.
struct AccessibilityDemoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0
    private let steps = ["Tap the microphone when you are ready. Words will appear as the person speaks.",
                         "Pause stops listening temporarily. Resume continues only when you choose it.",
                         "Stop finishes the recording and starts translation. Save keeps it; Discard permanently removes this draft.",
                         "In Audio & subtitles, choose what to hear and what to read. Previous and Next select silently; Play starts the selected paragraph."]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Demonstration · no recording").font(.headline)
                    Text("Step \(step + 1) of \(steps.count)").font(.subheadline)
                    Text(LocalizedStringKey(steps[step])).font(.title2)
                    HStack {
                        Button("Previous") { step -= 1 }.disabled(step == 0)
                        Spacer()
                        Button("Next") { step += 1 }.disabled(step == steps.count - 1)
                    }.buttonStyle(.bordered).controlSize(.large)
                }.padding()
            }.navigationTitle("Quick guide")
                .toolbar { Button("Done") { dismiss() } }
        }
    }
}

/// A response exists only in view memory; it never becomes a recording or a saved transcript.
@MainActor
struct WrittenResponseView: View {
    let coordinator: SessionCoordinator
    @Environment(\.scenePhase) private var phase
    @State private var text = ""
    @State private var language = CaptureLanguage.english
    @State private var speed = TranslationSpeechSpeed.normal
    @State private var speech = TranslationSpeechPlayer()
    @FocusState private var typing: Bool
    private var captureBusy: Bool { coordinator.caption.state.active || coordinator.caption.state.busy }
    var body: some View {
        Form {
            Section {
                Text("Write what you want to say. The voice reads exactly this text in the language you choose; it does not translate it.")
                Picker("Voice language", selection: $language) {
                    ForEach(CaptureLanguage.allCases, id: \.self) { Text($0.name).tag($0) }
                }.disabled(speech.state != .idle)
                Picker("Reading speed", selection: $speed) {
                    ForEach(TranslationSpeechSpeed.allCases) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
                }.disabled(speech.state != .idle)
                TextEditor(text: $text).frame(minHeight: 150).focused($typing)
                    .accessibilityLabel("Your response").accessibilityIdentifier("writtenResponseText")
                    .disabled(speech.state != .idle)
                Text("Your response is not saved. It is cleared when you leave this screen.").font(.caption)
            }
            Section {
                if captureBusy { Text("Pause or stop listening before speaking a response.").font(.headline) }
                Button(uiKey(speech.state == .speaking ? "Pause" : speech.state == .paused ? "Resume" : "Speak response"), systemImage: speech.state == .speaking ? "pause.fill" : "speaker.wave.2.fill") {
                    typing = false
                    if speech.state == .idle { speech.start([ReviewParagraph(id: UUID(), text: text)], language: language, speed: speed) }
                    else { speech.togglePause() }
                }.disabled(captureBusy || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("speakWrittenResponse").keyboardShortcut(.return, modifiers: .command)
                Button("Stop", systemImage: "stop.fill") { speech.stop() }.disabled(speech.state == .idle)
                Button("Clear response", systemImage: "eraser") { speech.stop(); text = "" }
                if let message = speech.message {
                    Text(LocalizedStringKey(message == "Translation interrupted. Tap Play to restart this paragraph." ? "Speech interrupted. Tap Speak response to start again." : message))
                }
                if speech.completedParagraphID != nil { Text("Response finished") }
            }
        }.navigationTitle("Write a response")
            .toolbar(.visible, for: .navigationBar)
            .toolbar { if typing { Button("Done") { typing = false } } }
            .onAppear { language = coordinator.settings.captureLanguage; speech.observeInterruptions() }
            .onDisappear { speech.close(); text = "" }
            .onChange(of: phase) { _, phase in if phase != .active { speech.interrupt() } }
            .onChange(of: captureBusy) { _, busy in if busy { speech.stop() } }
    }
}

@MainActor
struct SimpleHomeView: View {
    let coordinator: SessionCoordinator
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("What would you like to do?").font(.title2.bold())
                NavigationLink { LiveCaptionView(coordinator: coordinator) } label: { Label("Listen now", systemImage: "mic.fill").frame(maxWidth: .infinity, minHeight: 60) }
                    .accessibilityIdentifier("simpleListenNow")
                NavigationLink { SessionHistoryView(coordinator: coordinator) } label: { Label("My sessions", systemImage: "clock").frame(maxWidth: .infinity, minHeight: 60) }
                NavigationLink { PracticeSessionPicker(coordinator: coordinator) } label: { Label("Language practice", systemImage: "book").frame(maxWidth: .infinity, minHeight: 60) }
                NavigationLink("Write a response") { WrittenResponseView(coordinator: coordinator) }
                NavigationLink("Prepare VoiceToRead") { OfflineReadinessView(coordinator: coordinator) }
            }.buttonStyle(.bordered).font(.headline).padding()
        }.navigationTitle("VoiceToRead")
    }
}

@MainActor
struct PracticeSessionPicker: View {
    let coordinator: SessionCoordinator
    @Query(sort: \ConferenceSession.createdAt, order: .reverse) private var sessions: [ConferenceSession]
    @Query private var drafts: [SessionDraft]
    @Query private var trash: [SessionTrash]
    var body: some View {
        List {
            Text("Choose a saved session to practise its phrases. First record and save a session if your library is empty.")
            ForEach(sessions.filter { s in !drafts.contains { $0.sessionID == s.id } && !trash.contains { $0.sessionID == s.id } }) { session in
                NavigationLink(session.title) { EnglishLearningView(session: session, repository: coordinator.repository) }
                    .disabled(coordinator.caption.state.active || coordinator.caption.state.busy)
            }
        }.navigationTitle("Language practice")
    }
}
