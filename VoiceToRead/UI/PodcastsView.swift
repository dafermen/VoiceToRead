import SwiftUI

@MainActor
struct PodcastLibraryView: View {
    @State private var episodes: [PodcastEpisode] = []
    @State private var failed = false
    @Environment(\.locale) private var locale
    var body: some View {
        List {
            Section {
                Text("Listen to short English episodes, follow the words and replay a fragment at your pace.")
                    .font(.subheadline)
            }
            ForEach(episodes) { episode in
                NavigationLink { PodcastReaderView(episode: episode) } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(title(episode), systemImage: "headphones").font(.headline)
                        Text(verbatim: locale.language.languageCode?.identifier == "es" ? episode.summaryEs : episode.summaryEn)
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text(verbatim: "\(CaptureLanguage.english.pickerLabel) · \(episode.level) · \(Int((episode.normalDuration / 60).rounded(.up))) min")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 8)
                }.accessibilityIdentifier("podcast-" + episode.id)
            }
            if failed {
                Text("The podcasts could not be opened. Please try again.")
                Button("Retry") { load() }
            }
        }
        .navigationTitle("Podcasts").navigationBarTitleDisplayMode(.inline)
        .task { if episodes.isEmpty { load() } }
    }
    private func title(_ episode: PodcastEpisode) -> String {
        locale.language.languageCode?.identifier == "es" ? episode.titleEs : episode.titleEn
    }
    private func load() {
        do { episodes = try PodcastEpisode.load(); failed = false }
        catch { failed = true }
    }
}

@MainActor
private struct PodcastReaderView: View {
    let episode: PodcastEpisode
    @State private var playback: PodcastPlayback
    @State private var showTranscript = true
    @State private var showTranslation = false
    @State private var followNarration = true
    @Environment(AppSettings.self) private var settings
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    init(episode: PodcastEpisode) {
        self.episode = episode
        _playback = State(initialValue: PodcastPlayback(episode: episode))
    }
    var body: some View {
        ScrollViewReader { proxy in
            List {
                Section {
                    Text(verbatim: "\(CaptureLanguage.english.pickerLabel) · \(episode.level)").font(.caption).foregroundStyle(.secondary)
                    Picker("Playback speed", selection: Binding(get: { playback.slow }, set: { playback.slow = $0 })) {
                        Text("Slow · 0.85×").tag(true)
                        Text("Normal · 1×").tag(false)
                    }.pickerStyle(.segmented).accessibilityIdentifier("podcastSpeed")
                    Toggle("Show transcript", isOn: $showTranscript).accessibilityIdentifier("podcastShowTranscript")
                    if showTranscript {
                        DisclosureGroup("Reading options") {
                            Toggle("Show translation", isOn: $showTranslation)
                            Toggle("Follow narration", isOn: $followNarration)
                        }
                    }
                    Text("AI-generated voice by OpenAI · Marin").font(.caption).foregroundStyle(.secondary)
                    if let message = playback.message { Text(LocalizedStringKey(message)).foregroundStyle(.secondary) }
                }
                if showTranscript {
                    Section("Transcript") {
                        ForEach(Array(episode.segments.enumerated()), id: \.element.number) { index, segment in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Fragment \(segment.number)").font(.caption).foregroundStyle(.secondary)
                                    Spacer()
                                    Button { playback.startSegment(index) } label: {
                                        Image(systemName: "play.fill").frame(minWidth: 44, minHeight: 44)
                                    }.buttonStyle(.plain)
                                        .accessibilityLabel(Text("Play fragment \(segment.number)"))
                                        .accessibilityIdentifier("podcastFragment-\(segment.number)")
                                }
                                Text(highlight(segment, index: index))
                                    .font(.system(size: CGFloat(settings.captionSize), weight: settings.boldCaptions ? .bold : .regular))
                                    .lineSpacing(CGFloat(settings.lineSpacing)).textSelection(.enabled)
                                    .accessibilityIdentifier("podcastText-\(segment.number)")
                                if showTranslation {
                                    Text(verbatim: segment.es).font(.body).foregroundStyle(.secondary).textSelection(.enabled)
                                }
                            }.padding(.vertical, 4).id(segment.number)
                        }
                    }
                } else {
                    ContentUnavailableView("Listening without text", systemImage: "headphones",
                        description: Text("Turn on Show transcript whenever you want to check the words."))
                }
            }
            .onChange(of: playback.index) { _, index in
                if showTranscript && followNarration && playback.state == .playing {
                    proxy.scrollTo(episode.segments[index].number, anchor: .center)
                }
            }
            .onChange(of: playback.state) { _, state in
                if state == .playing && showTranscript && followNarration {
                    proxy.scrollTo(episode.segments[playback.index].number, anchor: .center)
                }
            }
        }
        .navigationTitle(locale.language.languageCode?.identifier == "es" ? episode.titleEs : episode.titleEn)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) { playbackControls }
        .onAppear { playback.observeInterruptions() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { playback.pause() } }
        .onDisappear { playback.close() }
    }
    private var playbackControls: some View {
        VStack(spacing: 8) {
            ProgressView(value: playback.progress).accessibilityLabel("Episode progress")
            HStack {
                Text("Fragment \(playback.index + 1) of \(episode.segments.count)").accessibilityIdentifier("podcastCurrentFragment")
                Spacer()
                Text(verbatim: clock(playback.elapsed * episode.baseSpeed) + " / " + clock(episode.normalDuration)).monospacedDigit()
            }.font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 8) {
                control("Previous", symbol: "backward.end.fill", enabled: playback.index > 0) { playback.select(playback.index - 1) }
                control(playback.state == .playing ? "Pause" : "Play", symbol: playback.state == .playing ? "pause.fill" : "play.fill", prominent: true) {
                    if playback.state == .playing { playback.pause() } else { playback.play() }
                }.accessibilityIdentifier("podcastPlayPause")
                control("Stop", symbol: "stop.fill", enabled: playback.state != .idle || playback.elapsed > 0) { playback.stop() }
                    .accessibilityIdentifier("podcastStop")
                control("Next", symbol: "forward.end.fill", enabled: playback.index + 1 < episode.segments.count) { playback.select(playback.index + 1) }
            }
        }.padding(.horizontal).padding(.vertical, 10).background(.regularMaterial)
    }
    private func control(_ title: String, symbol: String, enabled: Bool = true, prominent: Bool = false,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(prominent ? Color.white : Color.accentColor)
                    .frame(width: 48, height: 48)
                    .background(prominent ? Color.accentColor : Color.secondary.opacity(0.12), in: Circle())
                if settings.showButtonNames { Text(LocalizedStringKey(title)).font(.caption).multilineTextAlignment(.center) }
            }.frame(maxWidth: .infinity)
        }.buttonStyle(.plain).disabled(!enabled).accessibilityLabel(Text(LocalizedStringKey(title)))
    }
    private func highlight(_ segment: PodcastEpisode.Segment, index: Int) -> AttributedString {
        var text = AttributedString(segment.en)
        if playback.index == index, let spoken = playback.range,
           let range = Range<AttributedString.Index>(spoken, in: text) {
            text[range].backgroundColor = Color(red: 1, green: 0.9, blue: 0.4)
            text[range].foregroundColor = .black
        }
        return text
    }
    private func clock(_ seconds: Double) -> String {
        let value = max(0, Int(seconds))
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
}
