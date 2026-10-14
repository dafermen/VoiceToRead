import SwiftUI
import UIKit

@MainActor
struct MicrophoneCheckView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var model = ListeningViewModel(audio: AudioCaptureService())

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("English or Spanish captions, on your device.")
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text("Microphone capture")
                        .font(.title2.bold())
                    Label(LocalizedStringKey(model.state.title), systemImage: model.state == .listening ? "mic.fill" : "mic")
                        .font(.headline)
                        .accessibilityIdentifier("listeningStatus")
                    if case .error(let failure) = model.state {
                        Text(LocalizedStringKey(failure.message))
                            .foregroundStyle(.primary)
                            .accessibilityIdentifier("captureError")
                    }
                    if let notice = model.notice {
                        Text(LocalizedStringKey(notice)).font(.callout)
                    }
                    ProgressView(value: Double(model.level), total: 1)
                        .accessibilityLabel("Microphone input level")
                        .accessibilityValue("\(Int(model.level * 100)) percent")
                    Text("This check monitors volume only. Use Captions for live transcription.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    VStack(spacing: 12) {
                        Button {
                            Task { await model.start() }
                        } label: {
                            Label("Start Listening", systemImage: "mic.fill")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!model.state.canStart)
                        Button("Stop") { model.stop() }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .buttonStyle(.bordered)
                            .disabled(!model.state.canStop)
                        if model.showSettings {
                            Button("Open Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    openURL(url)
                                }
                            }
                            .frame(minHeight: 44)
                        }
                    }
                    Text("Audio stays in memory while listening. No audio is saved or uploaded.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
                .frame(maxWidth: 640, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Microphone Check")
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: model.enteredBackground()
            case .active: model.enteredForeground()
            case .inactive: break // A permission sheet temporarily makes the scene inactive.
            @unknown default: model.enteredBackground()
            }
        }
        .onDisappear { model.enteredBackground() }
        .onAppear { model.enteredForeground() }
    }
}

#Preview {
    MicrophoneCheckView()
}
