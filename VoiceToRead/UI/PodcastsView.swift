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
    @State private var fullScreen = false
    @AppStorage("podcastKaraokeTextSize") private var karaokeTextSize = 40.0
    @Environment(AppSettings.self) private var settings
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    init(episode: PodcastEpisode) {
        self.episode = episode
        _playback = State(initialValue: PodcastPlayback(episode: episode))
    }
    private var transcriptReader: some View {
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
        .navigationTitle(locale.language.languageCode?.identifier == "es" ? episode.titleEs : episode.titleEn)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(fullScreen ? .hidden : .visible, for: .navigationBar)
        .toolbar(fullScreen ? .hidden : .visible, for: .tabBar)
        .statusBarHidden(fullScreen)
        .toolbar {
            if !fullScreen {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Full screen", systemImage: "arrow.up.left.and.arrow.down.right") { fullScreen = true }
                        .font(.system(size: 20, weight: .medium)).labelStyle(.iconOnly).frame(width: 44, height: 44)
                        .background(.regularMaterial, in: Circle()).buttonStyle(.plain)
                        .accessibilityIdentifier("podcastFullScreen")
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { playbackControls }
        .onAppear { playback.observeInterruptions() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { playback.pause() } }
        .onDisappear { playback.close() }
    }
    private var karaokePoints: Double {
        karaokeTextSize.isFinite ? min(72, max(28, karaokeTextSize)) : 40
    }
    private var karaokeReader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Fragment \(playback.index + 1) of \(episode.segments.count)")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                Spacer(minLength: 4)
                Menu {
                    Button("Larger text", systemImage: "textformat.size.larger") { karaokeTextSize = min(72, karaokePoints + 4) }
                        .disabled(karaokePoints >= 72).accessibilityIdentifier("podcastLargerText")
                    Button("Smaller text", systemImage: "textformat.size.smaller") { karaokeTextSize = max(28, karaokePoints - 4) }
                        .disabled(karaokePoints <= 28).accessibilityIdentifier("podcastSmallerText")
                    Toggle("Show translation", isOn: $showTranslation)
                    Toggle("Follow narration", isOn: $followNarration)
                } label: {
                    Label("Reading options", systemImage: "textformat.size")
                        .font(.system(size: 20, weight: .medium)).labelStyle(.iconOnly).frame(width: 44, height: 44)
                }.buttonStyle(.plain).accessibilityIdentifier("podcastKaraokeOptions")
                Button("Exit full screen", systemImage: "arrow.down.right.and.arrow.up.left") { fullScreen = false }
                    .font(.system(size: 20, weight: .medium)).labelStyle(.iconOnly).frame(width: 44, height: 44)
                    .background(.regularMaterial, in: Circle()).buttonStyle(.plain)
                    .accessibilityIdentifier("podcastFullScreenExit")
            }.padding(.horizontal, 16).padding(.vertical, 4)
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

/// A single scrolling fragment, using the same measured UTF-16 word ranges as the normal reader.
@MainActor
private struct PodcastKaraokeText: UIViewRepresentable {
    let english: String
    let translation: String?
    let spoken: NSRange?
    let following: Bool
    let points: Double
    let bold: Bool
    let spacing: Double

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> PodcastKaraokeTextView {
        let view = PodcastKaraokeTextView()
        view.isEditable = false; view.isSelectable = true; view.backgroundColor = .clear
        view.textContainerInset = UIEdgeInsets(top: 12, left: 16, bottom: 18, right: 16)
        view.textContainer.lineFragmentPadding = 0
        view.contentInsetAdjustmentBehavior = .never
        view.adjustsFontForContentSizeCategory = true
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.accessibilityIdentifier = "podcastKaraokeText"
        return view
    }
    func updateUIView(_ view: PodcastKaraokeTextView, context: Context) {
        let font = UIFontMetrics(forTextStyle: .largeTitle).scaledFont(
            for: UIFont.systemFont(ofSize: CGFloat(points), weight: bold ? .bold : .medium),
            compatibleWith: view.traitCollection)
        let translationFont = UIFontMetrics(forTextStyle: .body).scaledFont(
            for: UIFont.systemFont(ofSize: CGFloat(max(20, points * 0.65))), compatibleWith: view.traitCollection)
        let color = UIColor.label.resolvedColor(with: view.traitCollection)
        let secondary = UIColor.secondaryLabel.resolvedColor(with: view.traitCollection)
        let text = english + (translation.map { "\n\n" + $0 } ?? "")
        let cache = context.coordinator
        if cache.text != text || cache.font != font || cache.translationFont != translationFont ||
            cache.color != color || cache.secondary != secondary || cache.spacing != spacing {
            let paragraph = NSMutableParagraphStyle(); paragraph.lineSpacing = CGFloat(spacing + 6)
            let value = NSMutableAttributedString(string: text, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph])
            if let translation, !translation.isEmpty {
                value.addAttributes([.font: translationFont, .foregroundColor: secondary],
                    range: NSRange(location: english.utf16.count + 2, length: translation.utf16.count))
            }
            view.attributedText = value
            cache.text = text; cache.font = font; cache.translationFont = translationFont
            cache.color = color; cache.secondary = secondary; cache.spacing = spacing; cache.range = nil
        }
        let next = spoken.flatMap { $0.length > 0 && Range($0, in: english) != nil ? $0 : nil }
        view.followWords = following; view.spokenRange = next
        if cache.range != next {
            view.textStorage.beginEditing()
            if let old = cache.range, NSMaxRange(old) <= view.textStorage.length {
                view.textStorage.removeAttribute(.backgroundColor, range: old)
                view.textStorage.addAttribute(.foregroundColor, value: color, range: old)
            }
            if let next {
                view.textStorage.addAttributes([.backgroundColor: UIColor(red: 1, green: 0.9, blue: 0.4, alpha: 1), .foregroundColor: UIColor.black], range: next)
            }
            view.textStorage.endEditing(); cache.range = next
            view.followSpokenWord()
        } else if following && !cache.wasFollowing { view.followSpokenWord() }
        cache.wasFollowing = following
    }
    final class Coordinator {
        var text: String?
        var font: UIFont?
        var translationFont: UIFont?
        var color: UIColor?
        var secondary: UIColor?
        var spacing: Double?
        var range: NSRange?
        var wasFollowing = false
    }
}

/// Rotation reflows text and keeps the current word visible without touching the audio clock.
@MainActor
private final class PodcastKaraokeTextView: UITextView {
    var spokenRange: NSRange?
    var followWords = true
    private var previousSize = CGSize.zero
    override func layoutSubviews() {
        super.layoutSubviews()
        if previousSize != bounds.size {
            previousSize = bounds.size
            followSpokenWord()
        }
    }
    func followSpokenWord() {
        guard followWords, !isDragging, !isDecelerating, let range = spokenRange,
              range.location != NSNotFound, range.location >= 0, range.length > 0,
              range.location <= textStorage.length, range.length <= textStorage.length - range.location else { return }
        UIView.performWithoutAnimation { scrollRangeToVisible(range) }
    }
}
