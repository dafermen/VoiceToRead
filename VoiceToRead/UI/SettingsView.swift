import SwiftUI
import AVFoundation
import UIKit

@MainActor
struct SettingsView: View {
    @Bindable var settings: AppSettings
    let coordinator: SessionCoordinator

    var body: some View {
        Form {
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
                Slider(value: $settings.captionSize, in: 20...44, step: 2) { Text("Caption size") }
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

    private var ready: Bool {
        permission == .granted && coordinator.caption.readiness == .ready && storage.ready
    }

    var body: some View {
        Form {
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
            Section {
                Button("Test Offline Mode") { instructions = true }
                Text("Only a real offline test verifies your device. This screen does not detect Airplane Mode.")
                    .font(.caption)
            }
        }
        .navigationTitle("Offline Readiness")
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
