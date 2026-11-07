import SwiftUI
import UIKit

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
                        (Text(CaptureLanguage.english.pickerLabel) + Text(verbatim: " · \(episode.level) · \(Int((episode.normalDuration / 60).rounded(.up))) min"))
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
    @State private var fullScreen = false
    @AppStorage("podcastKaraokeTextSize") private var karaokeTextSize = 40.0
    @Environment(AppSettings.self) private var settings
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize
    init(episode: PodcastEpisode) {
        self.episode = episode
        _playback = State(initialValue: PodcastPlayback(episode: episode))
    }
    private var transcriptReader: some View {
        ScrollViewReader { proxy in
            List {
                Section {
                    (Text(CaptureLanguage.english.pickerLabel) + Text(verbatim: " · \(episode.level)"))
                        .font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("podcastLanguageAndLevel")
                    Picker("Playback speed", selection: Binding(get: { playback.slow }, set: { playback.slow = $0 })) {
                        Text("Slow · 0.85×").tag(true)
                        Text("Normal · 1×").tag(false)
                    }.pickerStyle(.segmented).accessibilityIdentifier("podcastSpeed")
                    Toggle("Show transcript", isOn: $showTranscript).accessibilityIdentifier("podcastShowTranscript")
                    DisclosureGroup("Reading options") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Full-screen text size").font(.subheadline)
                            Slider(value: $karaokeTextSize, in: 28...72, step: 4)
                                .accessibilityLabel("Full-screen text size").accessibilityIdentifier("podcastKaraokeTextSize")
                        }
                        Toggle("Show translation", isOn: $showTranslation).accessibilityIdentifier("podcastShowTranslation")
                        Toggle("Follow narration", isOn: $followNarration)
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
                                        AppControlSymbol(symbol: "play.fill")
                                    }.buttonStyle(.borderless)
                                        .accessibilityLabel(Text("Play fragment \(segment.number)"))
                                        .accessibilityIdentifier("podcastFragment-\(segment.number)")
                                }
                                if showTranslation && !typeSize.isAccessibilitySize {
                                    ViewThatFits(in: .horizontal) {
                                        HStack(alignment: .top, spacing: 12) {
                                            transcriptCard(segment, index: index, translated: false).frame(minWidth: 300)
                                            transcriptCard(segment, index: index, translated: true).frame(minWidth: 300)
                                        }
                                        VStack(spacing: 12) {
                                            transcriptCard(segment, index: index, translated: false)
                                            transcriptCard(segment, index: index, translated: true)
                                        }
                                    }
                                } else {
                                    transcriptCard(segment, index: index, translated: false)
                                    if showTranslation { transcriptCard(segment, index: index, translated: true) }
                                }
                            }.padding(.vertical, 4).id(segment.number)
                        }
                    }
                } else {
                    ContentUnavailableView("Listening without text", systemImage: "headphones",
                        description: Text("Turn on Show transcript whenever you want to check the words."))
                }
            }
            .onAppear {
                if showTranscript && followNarration && (playback.index > 0 || playback.state != .idle) {
                    proxy.scrollTo(episode.segments[playback.index].number, anchor: .center)
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
    }
    var body: some View {
        // Keep a stable outer container: switching readers must not run playback.close().
        ZStack {
            if fullScreen { karaokeReader }
            else { transcriptReader }
        }
        .modifier(ReaderFullScreenPresentation(active: $fullScreen, identifier: "podcastFullScreen", exitIdentifier: "podcastFullScreenExit"))
        .navigationTitle(locale.language.languageCode?.identifier == "es" ? episode.titleEs : episode.titleEn)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(fullScreen ? .hidden : .visible, for: .navigationBar)
        .toolbar(fullScreen ? .hidden : .visible, for: .tabBar)
        .statusBarHidden(fullScreen)

        .safeAreaInset(edge: .bottom, spacing: 0) { if !fullScreen { playbackControls } }
        .onAppear { playback.observeInterruptions() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { playback.pause() } }
        .onDisappear { playback.close() }
    }
    private var karaokePoints: Double {
        karaokeTextSize.isFinite ? min(72, max(28, karaokeTextSize)) : 40
    }
    private var karaokeReader: some View {
        VStack(spacing: 0) {
            if let message = playback.message {
                Text(LocalizedStringKey(message)).font(.caption).foregroundStyle(.secondary).padding(.horizontal)
            }
            let segment = episode.segments[playback.index]
            PodcastKaraokeText(english: segment.en, translation: showTranslation ? segment.es : nil,
                spoken: playback.range, following: followNarration, points: karaokePoints,
                bold: settings.boldCaptions, spacing: settings.lineSpacing)
                .id(segment.number)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        .accessibilityIdentifier("podcastKaraokeReader")
    }

    private var playbackControls: some View {
        VStack(spacing: fullScreen ? 4 : 8) {
            ProgressView(value: playback.progress).accessibilityLabel("Episode progress")
            HStack {
                if !fullScreen {
                    Text("Fragment \(playback.index + 1) of \(episode.segments.count)").accessibilityIdentifier("podcastCurrentFragment")
                }
                Spacer()
                Text(verbatim: clock(playback.elapsed * episode.baseSpeed) + " / " + clock(episode.normalDuration)).monospacedDigit()
                    .accessibilityIdentifier("podcastTimeline")
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
        }.padding(.horizontal).padding(.vertical, fullScreen ? 4 : 10).background(.regularMaterial)
    }
    private func control(_ title: String, symbol: String, enabled: Bool = true, prominent: Bool = false,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: AppInterface.controlSpacing) {
                AppControlSymbol(symbol: symbol, surface: prominent ? .prominent : .neutral)
                if settings.showButtonNames { Text(LocalizedStringKey(title)).font(.caption).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("visibleControlName") }
            }.frame(maxWidth: .infinity)
        }.buttonStyle(.plain).disabled(!enabled).accessibilityLabel(Text(LocalizedStringKey(title)))
    }
    private func transcriptCard(_ segment: PodcastEpisode.Segment, index: Int, translated: Bool) -> some View {
        let language: CaptureLanguage = translated ? .spanish : .english
        return VStack(alignment: .leading, spacing: 8) {
            Text(uiKey(translated ? "Translation \(language.name)" : "Original \(language.name)"))
                .font(.caption.weight(.semibold))
            Text(translated ? AttributedString(segment.es) : highlight(segment, index: index))
                .font(translated ? .body : .system(size: CGFloat(settings.captionSize), weight: settings.boldCaptions ? .bold : .regular))
                .lineSpacing(CGFloat(settings.lineSpacing)).textSelection(.enabled)
                .accessibilityIdentifier((translated ? "podcastTranslation-" : "podcastText-") + String(segment.number))
        }.modifier(LiveLanguageCard(color: settings.color(for: language), highContrast: settings.highContrast))
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


/// One scrolling pair per audio fragment. Sentence ranges retain the original cue offsets.
@MainActor
private struct PodcastKaraokeText: View {
    let english: String
    let translation: String?
    let spoken: NSRange?
    let following: Bool
    let points: Double
    let bold: Bool
    let spacing: Double
    @Environment(AppSettings.self) private var settings
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .largeTitle) private var scale = 1.0
    @State private var followedSentence: Int?
    private var ranges: [NSRange] { PodcastReadingParagraphs.ranges(in: english) }
    private var activeSentence: Int? {
        guard let spoken, Range(spoken, in: english) != nil else { return nil }
        return ranges.firstIndex { NSIntersectionRange($0, spoken).length > 0 }
    }
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    let columns = translation != nil && geometry.size.width >= 700 && !typeSize.isAccessibilitySize
                    (columns ? AnyLayout(HStackLayout(alignment: .top, spacing: 12)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 12))) {
                        languageCard(english, language: .english, translated: false)
                            .accessibilityIdentifier("podcastKaraokeText")
                        if let translation {
                            languageCard(translation, language: .spanish, translated: true)
                                .accessibilityIdentifier("podcastKaraokeTranslation")
                        }
                    }.padding(16)
                }
                .accessibilityIdentifier("podcastKaraokeScroll")
                .onAppear { follow(proxy, force: true) }
                .onChange(of: activeSentence) { _, _ in follow(proxy) }
                .onChange(of: following) { _, _ in follow(proxy, force: true) }
                .onChange(of: geometry.size) { _, _ in follow(proxy, force: true) }
            }
        }
    }
    private func languageCard(_ text: String, language: CaptureLanguage, translated: Bool) -> some View {
        let paragraphs = PodcastReadingParagraphs.ranges(in: text)
        return VStack(alignment: .leading, spacing: max(16, spacing + 12)) {
            Text(uiKey(translated ? "Translation \(language.name)" : "Original \(language.name)"))
                .font(.caption.weight(.semibold))
            ForEach(paragraphs.indices, id: \.self) { index in
                Text(highlight(text, range: paragraphs[index], translated: translated))
                    .font(.system(size: CGFloat(points * scale), weight: bold ? .bold : .medium))
                    .lineSpacing(CGFloat(spacing + 6)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id((translated ? "podcastTranslation-" : "podcastSentence-") + String(index))
            }
        }
        .modifier(LiveLanguageCard(color: settings.color(for: language), highContrast: settings.highContrast))
        .accessibilityElement(children: .contain)
    }
    private func highlight(_ text: String, range: NSRange, translated: Bool) -> AttributedString {
        let value = (text as NSString).substring(with: range)
        var attributed = AttributedString(value)
        if !translated, let spoken, Range(spoken, in: text) != nil {
            let intersection = NSIntersectionRange(range, spoken)
            if intersection.length > 0 {
                let local = NSRange(location: intersection.location - range.location, length: intersection.length)
                if let selected = Range<AttributedString.Index>(local, in: attributed) {
                    attributed[selected].backgroundColor = Color(red: 1, green: 0.9, blue: 0.4)
                    attributed[selected].foregroundColor = .black
                }
            }
        }
        return attributed
    }
    private func follow(_ proxy: ScrollViewProxy, force: Bool = false) {
        guard following, let activeSentence, force || followedSentence != activeSentence else { return }
        // Silent gaps between word cues must not repeatedly jump back to the sentence's start.
        followedSentence = activeSentence
        proxy.scrollTo("podcastSentence-" + String(activeSentence), anchor: .top)
    }
}
