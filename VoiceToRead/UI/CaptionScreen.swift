import SwiftUI
import UIKit

@MainActor
struct CaptionScreen: View {
    @Bindable var model: CaptionViewModel
    @Bindable var settings: AppSettings
    var newSession: (() async -> Void)? = nil
    var saveSession: (() -> Void)? = nil
    var saveAndNewSession: (() async -> Void)? = nil
    var discardSession: (() async -> Void)? = nil
    var needsSessionDecision = false
    var sessionTitle: Binding<String>? = nil
    var speakAndTranslate: (() -> Void)? = nil
    var canSpeakAndTranslate = true
    var writeResponse: (() -> Void)? = nil
    var communicationLayout = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title) private var scaledSize: CGFloat = 28
    @FocusState private var titleFocused: Bool
    @GestureState private var pinchScale: CGFloat = 1
    @State private var readingStartID: UUID?
    @State private var isFullScreen = false
    @AppStorage("liveCaptionDisplay") private var liveDisplay: LiveCaptionDisplay = .original
    @State private var followLive = true
    @State private var confirmNewSession = false
    @State private var showingOptions = false
    @State private var showingLiveDisplay = false
    @State private var showingCaptureOptions = false
    @State private var confirmDiscard = false
    @State private var showingStatus = false
    @State private var showingActions = false
    @State private var followScrollTask: Task<Void, Never>?

    private var showControlNames: Bool { settings.showButtonNames }

    private var readerLayout: some View {
        GeometryReader { geometry in
            let compact = !communicationLayout && geometry.size.width > geometry.size.height && !dynamicTypeSize.isAccessibilitySize && !showControlNames
            AccessibilityScrollingContent {
            VStack(spacing: 0) {
                if communicationLayout && !isFullScreen {
                    CommunicationHeader {
                        LanguagePairOptions(model: model, settings: settings, homeLayout: true)
                    } status: { status }
                }
                if !communicationLayout && !compact && !isFullScreen {
                    Group {
                        if dynamicTypeSize.isAccessibilitySize || showControlNames {
                            VStack(alignment: .leading, spacing: 8) { status; utilities }
                        } else {
                            HStack { status; Spacer(minLength: 8); utilities }
                        }
                    }.padding(.horizontal, 16)
                }
                if model.canResume { resumePanel }
                else if needsPreparation { preparationPanel }
                else if let message = statusMessage { captureNotice(message) }
                Group {
                    if supportsLiveTranslation && liveDisplay != .original {
                        LiveSpanishView(paragraphs: model.transcript.finalized.suffix(40).map {
                            ReviewParagraph(id: $0.id, text: $0.text)
                        }, fontSize: Double(scaledSize) * settings.captionSize / 28,
                           language: model.language, target: settings.translationLanguage, display: liveDisplay, provisionalText: model.transcript.partial.map(\.text).joined(separator: "\n"),
                           lineSpacing: settings.lineSpacing, bold: settings.boldCaptions, ruled: settings.ruledPaper && !settings.highContrast, highContrast: settings.highContrast,
                           englishColor: settings.englishColor, spanishColor: settings.spanishColor, frenchColor: settings.frenchColor, koreanColor: settings.koreanColor)
                            .id(model.language.rawValue + settings.translationLanguage.rawValue)
                    } else { transcript }
                }
                    .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 320 : nil,
                           maxHeight: dynamicTypeSize.isAccessibilitySize ? 400 : .infinity)
                    .background(ReaderSurface(settings: settings))
                    .environment(\.colorScheme, settings.readerPaper != .system && !settings.highContrast ? .light : colorScheme)
                if model.state == .ended && needsSessionDecision {
                    Divider()
                    resolutionControls.padding(.horizontal, 16).padding(.vertical, 4)
                }
                if model.canChooseCaptureOptions && !communicationLayout {
                    VStack(spacing: 0) { LanguagePairOptions(model: model, settings: settings, compact: true); quickPreferences }.padding(.horizontal, 16)
                }
                if communicationLayout || isFullScreen || compact || model.state != .ended {
                    Divider()
                    Group {
                        if isFullScreen && (showControlNames || dynamicTypeSize.isAccessibilitySize) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top, spacing: 12) {
                                    status
                                    Spacer(minLength: 0)
                                    primaryButton(iconOnly: true)
                                    if model.state != .ended { stopButton(iconOnly: true) }
                                }
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 150 : 104))], alignment: .leading) {
                                    translationButton; capturePreferencesButton; fullScreenButton
                                }
                            }
                        } else {
                            HStack(spacing: 8) {
                                if isFullScreen {
                                    status
                                    Spacer(minLength: 0)
                                    primaryButton(iconOnly: true)
                                    if model.state != .ended { stopButton(iconOnly: true) }
                                    translationButton
                                    capturePreferencesButton
                                    fullScreenButton
                                } else {
                                    if compact { status; Spacer(minLength: 0) }
                                    if communicationLayout || model.state != .ended { captureControls }
                                    if compact { utilities }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, communicationLayout ? 8 : 6)
                    .frame(minHeight: communicationLayout && !isFullScreen ? 100 : nil)
                    .background(.bar)
                }
            }
            }
        }
    }

    private var presentedReader: some View {
        readerLayout
        .navigationTitle("VoiceToRead")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(communicationLayout && !isFullScreen ? .visible : .hidden, for: .navigationBar)
        .toolbar {
            if communicationLayout && !isFullScreen {
                ToolbarItem(placement: .topBarLeading) {
                    Menu { sessionActionButtons } label: {
                        Label("Session actions", systemImage: "ellipsis.circle")
                    }.labelStyle(AccessibleControlLabelStyle()).accessibilityIdentifier("sessionActionsButton")
                }
            }
        }
        .toolbar(isFullScreen ? .hidden : .visible, for: .tabBar)
        .statusBarHidden(isFullScreen)
        .sheet(isPresented: $showingOptions) { readingOptions }
        .sheet(isPresented: $showingCaptureOptions) {
            NavigationStack {
                Form { LanguagePairOptions(model: model, settings: settings); CaptureOptionsView(model: model, settings: settings) }
                    .navigationTitle("Capture preferences")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { DoneToolbar { showingCaptureOptions = false } }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingStatus) { statusDetails }
    }

    var body: some View {
        presentedReader
            .confirmationDialog("Live caption display", isPresented: $showingLiveDisplay, titleVisibility: .visible) {
                Button("Original \(model.language.name)") { liveDisplay = .original }
                Button("Translation \(settings.translationLanguage.name)") { liveDisplay = .translation }
                Button("Both") { liveDisplay = .both }
                Button("Cancel", role: .cancel) { }
            }
        .confirmationDialog("Session actions", isPresented: $showingActions, titleVisibility: .visible) {
            sessionActionButtons
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Recovery drafts stay on this device until you save or discard them.")
        }
        .confirmationDialog(uiKey("Keep this session before starting another?"),
                            isPresented: $confirmNewSession, titleVisibility: .visible) {
            Button("Save and new session") {
                Task { await saveAndNewSession?(); resetReaderPosition() }
            }
            Button("Discard and new session", role: .destructive) {
                Task { await discardSession?(); resetReaderPosition() }
            }
            Button("Cancel", role: .cancel) { }
        } message: { Text("Discard permanently deletes this session's transcript and any recorded audio.") }
        .confirmationDialog(uiKey("Discard this session?"), isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard Session", role: .destructive) {
                Task { await discardSession?(); resetReaderPosition() }
            }
            Button("Cancel", role: .cancel) { }
        } message: { Text("This permanently deletes the transcript and any audio from this session.") }
        .task { model.refreshMicrophonePermission(); await model.checkReadiness() }
        .onChange(of: model.state) { _, _ in applyWakePreference() }
        .onChange(of: model.canResume) { wasPaused, paused in
            if paused && !wasPaused {
                if settings.pauseHaptics { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
                UIAccessibility.post(notification: .announcement,
                    argument: InterfaceLocalization.string("Listening paused. Microphone is off. Tap Resume recording to continue.", language: settings.interfaceLanguage))
            }
        }
        .onChange(of: settings.keepAwake) { _, _ in applyWakePreference() }
        .onAppear { applyWakePreference() }
        .onDisappear { followScrollTask?.cancel(); UIApplication.shared.isIdleTimerDisabled = false }
    }

    @ViewBuilder private var sessionActionButtons: some View {
            if let writeResponse { Button("Write and speak", action: writeResponse).disabled(model.state.active || model.state.busy) }
            Button("Reading options") { showingOptions = true }
            Button("Capture preferences") { showingCaptureOptions = true }
            Button("Full screen") { isFullScreen.toggle() }
            if supportsLiveTranslation { Button("Reading language") { showingLiveDisplay = true } }
            if let saveSession {
                Button("Save Session", action: saveSession)
                    .disabled(model.state != .ended || !needsSessionDecision)
            }
            if model.state == .ended && needsSessionDecision {
                Button("Discard Session", role: .destructive) { confirmDiscard = true }
            }
            Button("New Session") { Task { await beginNewSession() } }
                .disabled(model.state.active || model.state.busy || model.preparationPending || needsSessionDecision)
            Button("Session information") { showingStatus = true }
    }

    private var needsPreparation: Bool {
        guard !model.state.active, !model.state.busy, model.state != .ended else { return false }
        return model.microphonePermission != .granted || model.readiness != .ready
    }

    private var preparationPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Prepare to listen", systemImage: "exclamationmark.bubble.fill")
                .font(.headline).accessibilityAddTraits(.isHeader)
            Text("Allow access and prepare the spoken language before starting. Nothing is recorded until you tap the microphone.")
                .font(.subheadline).fixedSize(horizontal: false, vertical: true)
            if model.microphonePermission != .granted {
                Text("Microphone access is needed to hear the conversation.").font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                if model.microphonePermission == .undetermined {
                    Button("Allow Microphone") { Task { await model.requestMicrophonePermission() } }
                        .accessibilityIdentifier("prepareMicrophoneButton")
                } else { openSystemSettingsButton }
            } else {
                Text(LocalizedStringKey(model.readiness.description)).font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                switch model.readiness {
                case .authorizationRequired:
                    Button("Allow Speech Recognition") { Task { await model.requestSpeechPermission() } }
                        .accessibilityIdentifier("prepareSpeechButton")
                case .missingAssets:
                    Button("Download speech model") { Task { await model.installAssets() } }
                        .accessibilityIdentifier("prepareModelButton")
                    Text("Internet and free storage are needed for this download.").font(.caption)
                case .authorizationDenied, .systemModelUnavailable:
                    openSystemSettingsButton
                    Button("Refresh Checks") { Task { await model.checkReadiness() } }
                case .checking, .downloading:
                    ProgressView()
                default:
                    Button("View preparation details") { showingStatus = true }
                }
            }
        }.buttonStyle(.borderedProminent).controlSize(.large)
            .disabled(model.preparationPending)
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.15))
            .accessibilityIdentifier("capturePreparationPanel")
    }

    private var openSystemSettingsButton: some View {
        Button("Open Settings") {
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        }
    }

    private var resumeActions: some View {
        HStack {
            Button { Task { await model.start() } } label: {
                Label("Resume recording", systemImage: "play.fill")
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 44)
            }.buttonStyle(.borderedProminent).accessibilityIdentifier("resumeCaptureButton")
            Button("Detalles", systemImage: "info.circle") { showingStatus = true }
                .labelStyle(AccessibleControlLabelStyle()).font(.system(size: 22)).frame(minWidth: 44, minHeight: 44)
        }
    }

    private var resumePanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            // At the largest text sizes, keep the recovery action above the explanation.
            if dynamicTypeSize.isAccessibilitySize { resumeActions }
            Label("Escucha en pausa · Micrófono apagado", systemImage: "pause.circle.fill")
                .font(.headline).accessibilityIdentifier("pausedCaptureBanner")
            Text("No se están capturando nuevas palabras. Pulsa Resume para continuar.")
                .font(.subheadline)
            if !dynamicTypeSize.isAccessibilitySize { resumeActions }
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.15))
            .accessibilityElement(children: .contain)
    }

    private func captureNotice(_ message: String) -> some View {
        HStack(spacing: 0) {
            Button { showingStatus = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: isProblem || model.permissionDenied ? "exclamationmark.circle" : "info.circle")
                    interfaceMessage(message).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right").font(.caption)
                }
                .font(.subheadline).padding(.horizontal, 16).frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel(interfaceMessage(message) + Text(". Show details"))
            .accessibilityIdentifier("captionStatusDetails")
            if model.canResume {
                Button { Task { await model.start() } } label: {
                    Label("Resume", systemImage: "play.fill").font(.subheadline).frame(minHeight: 44)
                }
                .padding(.trailing, 16).accessibilityIdentifier("resumeCaptureButton")
            }
        }
    }

    private var microphoneMeter: some View {
        ProgressView(value: Double(model.inputLevel)).frame(width: 44)
            .tint(model.isRecordingAudio ? Color.red : Color.accentColor)
            .accessibilityLabel("Microphone level")
            .accessibilityValue("\(Int(model.inputLevel * 100)) percent")
            .accessibilityIdentifier("captureLevelMeter")
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(uiKey(model.isRecordingAudio ? "Recording" : LocalizedStringKey(statusTitle)),
                  systemImage: model.isRecordingAudio ? "record.circle.fill" : (model.state == .listening ? "mic.fill" : "mic"))
                .foregroundStyle(model.isRecordingAudio ? Color.red : Color.primary)
                .font(.subheadline.weight(.semibold))
                .accessibilityLabel(uiKey(model.isRecordingAudio ? "Recording audio and captions" : (model.state == .listening ? "Transcribing without saving audio" : LocalizedStringKey(model.state.title))))
                .accessibilityIdentifier("listeningStatus")
            TimelineView(.periodic(from: Date(), by: 1)) { context in
                HStack(spacing: 6) {
                Text(SessionClock.format(model.currentDuration(at: context.date)))
                    .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                    .accessibilityLabel("Listening time")
                    .accessibilityValue(SessionClock.format(model.currentDuration(at: context.date)))
                if model.state == .listening {
                    microphoneMeter
                }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(minHeight: 44)
    }

    /// Named controls wrap into rows. Icon-only mode retains the compact toolbar.
    @ViewBuilder private var utilities: some View {
        if settings.simpleMode {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { simpleUtilityButtons(vertical: false) }
                VStack(alignment: .leading, spacing: 8) { simpleUtilityButtons(vertical: true) }
            }.buttonStyle(.plain).tint(.accentColor)
        } else if showControlNames {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 150 : 104), alignment: .top)], alignment: .leading, spacing: 8) {
                utilityButtons
            }
        } else {
            HStack(spacing: 0) { utilityButtons }
        }
    }
    /// Simple mode reduces actions; the independent names preference still controls their labels.
    @ViewBuilder private func simpleUtilityButtons(vertical: Bool) -> some View {
        if model.state == .ended { newSessionButton }
        if !vertical { Spacer(minLength: 0) }
        Button { showingActions = true } label: {
            Label("Session actions", systemImage: "ellipsis.circle")
                .labelStyle(AccessibleControlLabelStyle())
                .frame(minWidth: 44, minHeight: 44)
        }.foregroundStyle(Color.accentColor).accessibilityIdentifier("sessionActionsButton")
    }
    @ViewBuilder private var utilityButtons: some View {
        if model.state == .ended { newSessionButton }
        if !settings.simpleMode {
            translationButton; conversationButton; fullScreenButton
            Button { showingOptions = true } label: { readerControlLabel("Reading options", symbol: "textformat.size") }
                .accessibilityLabel("Reading options").accessibilityIdentifier("readingOptionsButton")
        }
        Button { showingActions = true } label: { readerControlLabel("Session actions", symbol: "ellipsis.circle") }
            .accessibilityLabel("Session actions").accessibilityIdentifier("sessionActionsButton")
    }
    /// Read the observable settings instance, rather than a second global UserDefaults binding.
    private func readerControlLabel(_ title: String, symbol: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 22)).frame(height: 26)
            if showControlNames {
                Text(LocalizedStringKey(title)).font(.caption)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("controlName-" + title)
            }
        }.padding(.top, showControlNames ? 8 : 0)
            .frame(maxWidth: showControlNames ? .infinity : nil, minHeight: showControlNames ? 72 : 44,
                   alignment: showControlNames ? .top : .center)
            .frame(minWidth: 44).contentShape(Rectangle())
    }

    private var supportsLiveTranslation: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-live-translation") { return true }
        #endif
        #if canImport(Translation)
        if #available(iOS 18.0, *) { return true }
        #endif
        return false
    }

    @ViewBuilder private var translationButton: some View {
        if supportsLiveTranslation {
            Button { showingLiveDisplay = true } label: {
                readerControlLabel("Live caption display", symbol: "character.bubble")
                    .foregroundStyle(liveDisplay == .original ? Color.primary : Color.accentColor)
            }
            .accessibilityLabel("Live caption display")
            .accessibilityValue(Text(uiKey(liveDisplay == .original ? "Original \(model.language.name)" : liveDisplay == .translation ? "Translation \(settings.translationLanguage.name)" : "Both")))
            .accessibilityIdentifier("liveSpanishButton")

        }
    }

    private var fullScreenButton: some View {
        Button { isFullScreen.toggle() } label: {
            readerControlLabel(isFullScreen ? "Exit full screen" : "Full screen",
                               symbol: isFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
        }
        .accessibilityLabel(uiKey(isFullScreen ? "Exit full screen" : "Full screen"))
        .accessibilityIdentifier("fullScreenButton")
    }

    private var firstVisibleIndex: Int {
        if followLive { return max(0, model.transcript.finalized.count - 300) }
        guard let readingStartID else { return 0 }
        return model.transcript.finalized.firstIndex { $0.id == readingStartID } ?? 0
    }

    private var followBinding: Binding<Bool> {
        Binding(get: { followLive }, set: { enabled in
            if enabled { followLive = true } else { pauseFollowing() }
        })
    }

    private func pauseFollowing() {
        guard followLive else { return }
        readingStartID = model.transcript.finalized.dropFirst(firstVisibleIndex).first?.id
        followLive = false
    }

    private var resizeGesture: some Gesture {
        MagnificationGesture()
            .updating($pinchScale) { value, scale, _ in scale = value }
            .onEnded { value in
                settings.captionSize = CaptionTextSize.clamped(settings.captionSize * Double(value))
            }
    }

    private var captionPoints: CGFloat {
        scaledSize * CGFloat(CaptionTextSize.clamped(settings.captionSize * Double(pinchScale))) / 28
    }

    private var captionFont: Font {
        let magnified: Double = settings.captionSize * Double(pinchScale)
        let bounded: Double = CaptionTextSize.clamped(magnified)
        let points: CGFloat = scaledSize * CGFloat(bounded) / 28.0
        let weight: Font.Weight = settings.boldCaptions ? .semibold : .regular
        return Font.system(size: points, weight: weight)
    }

    private func captionRow(_ segment: CaptionSegment) -> some View {
        ReaderParagraph(text: segment.text, points: captionPoints, spacing: settings.lineSpacing, bold: settings.boldCaptions, ruled: settings.ruledPaper && !settings.highContrast)
            .accessibilityIdentifier("caption-" + segment.id.uuidString)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Home entry, beside the live language selector.
    @ViewBuilder private var conversationButton: some View {
        if let speakAndTranslate {
            Button(action: speakAndTranslate) { readerControlLabel("Conversation", symbol: "bubble.left.and.bubble.right") }
                .accessibilityLabel("Conversation")
                .help("Conversation").disabled(!canSpeakAndTranslate)
                .accessibilityIdentifier("speakTranslateEntry")
        }
    }

    private func captionContent(height: CGFloat) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if !hasCaptions {
                    Text("Live \(model.language.name) captions will appear here.")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("captionPlaceholder")
                }
                if firstVisibleIndex > 0 {
                    Button("Load Earlier Captions") {
                        let index = max(0, firstVisibleIndex - 300)
                        pauseFollowing()
                        readingStartID = model.transcript.finalized[index].id
                    }
                    .font(.body).frame(minHeight: 44)
                }
                ForEach(model.transcript.finalized.dropFirst(firstVisibleIndex)) { segment in
                    captionRow(segment)
                }
                // A single stable container avoids replacing the entire provisional view
                // whenever the recognizer revises its audio range or identifier.
                if !model.transcript.partial.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Live · may change").font(.caption)
                        ReaderParagraph(text: model.transcript.partial.map(\.text).joined(separator: "\n"), points: captionPoints, spacing: settings.lineSpacing, bold: settings.boldCaptions, ruled: settings.ruledPaper && !settings.highContrast)
                            .accessibilityIdentifier("provisionalCaption")
                    }
                    .id("provisionalCaption")
                }
                Color.clear.frame(height: 1).id("liveBottom")
            }
            .font(captionFont)
            .lineSpacing(settings.lineSpacing)
            .frame(maxWidth: .infinity, minHeight: max(0, height - 32), alignment: .topLeading)
            .padding(16)
            .transaction { $0.animation = nil }
        }
    }

    private func styledCaptionContent(height: CGFloat) -> some View {
        captionContent(height: height)
        .defaultScrollAnchor(followLive ? .bottom : nil)
        .foregroundStyle(settings.highContrast ? (colorScheme == .dark ? Color.white : Color.black) : settings.readerPaper != .system ? Color.black : Color.primary)
        .accessibilityIdentifier("captionScrollView")
        .accessibilityValue(Text("\(model.transcript.finalized.count) finished paragraphs. ") + Text(uiKey(followLive ? "Following live captions" : "Reading earlier captions")))
    }

    private func interactiveCaptionContent(height: CGFloat) -> some View {
        styledCaptionContent(height: height)
        .simultaneousGesture(DragGesture(minimumDistance: 10).onChanged { value in
            if hasCaptions && value.translation.height > 10 && value.translation.height > abs(value.translation.width) {
                pauseFollowing()
            }
        })
        .simultaneousGesture(resizeGesture)
        .accessibilityAction(named: Text("Increase text size")) { settings.captionSize = CaptionTextSize.clamped(settings.captionSize + 2) }
        .accessibilityAction(named: Text("Decrease text size")) { settings.captionSize = CaptionTextSize.clamped(settings.captionSize - 2) }
        .accessibilityAction(named: "Read earlier captions") { pauseFollowing() }
        .overlay(alignment: .bottomTrailing) {
            if !followLive && hasCaptions {
                ReturnToLiveButton { followLive = true }
                    .accessibilityIdentifier("backToLiveButton").padding(12)
            }
        }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            GeometryReader { viewport in
                interactiveCaptionContent(height: viewport.size.height)
                .onChange(of: model.transcript.finalized) { _, _ in scrollToLive(proxy) }
                .onChange(of: model.transcript.partial) { _, _ in scrollToLive(proxy) }
                .onChange(of: followLive) { _, enabled in if enabled { scrollToLive(proxy) } }
                .onChange(of: isFullScreen) { _, _ in scrollToLive(proxy) }
                .onChange(of: viewport.size) { _, _ in scrollToLive(proxy) }
            }
        }
    }

    private var quickPreferences: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { quickPreferenceButtons }.fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: 8) { quickPreferenceButtons }
        }.font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var quickPreferenceButtons: some View {
            Button {
                settings.saveAudio.toggle()
                model.saveAudio = settings.saveAudio
            } label: {
                CapturePreferenceLabel(title: "Save audio", enabled: settings.saveAudio)
            }
            .accessibilityLabel("Save audio")
            .accessibilityValue(uiKey(settings.saveAudio ? "On" : "Off"))
            .accessibilityIdentifier("quickAudioPreference")
            Button {
                settings.reduceBackgroundNoise.toggle()
                model.reduceBackgroundNoise = settings.reduceBackgroundNoise
            } label: {
                CapturePreferenceLabel(title: "Reduce noise", enabled: settings.reduceBackgroundNoise)
            }
            .accessibilityLabel("Reduce background noise")
            .accessibilityValue(uiKey(settings.reduceBackgroundNoise ? "On" : "Off"))
            .help("Reduce background noise")
            .accessibilityIdentifier("quickNoisePreference")
            Button {
                settings.continueInBackground.toggle()
                model.continueInBackground = settings.continueInBackground
            } label: {
                CapturePreferenceLabel(title: "Background", enabled: settings.continueInBackground)
            }
            .accessibilityLabel("Continue in background")
            .accessibilityValue(uiKey(settings.continueInBackground ? "On" : "Off"))
            .accessibilityIdentifier("quickBackgroundPreference")
    }

    private var resolutionControls: some View {
        VStack(alignment: .leading, spacing: 4) {
        if let sessionTitle {
            HStack(spacing: 4) {
                TextField("Session name (optional)", text: sessionTitle)
                    .font(.subheadline).focused($titleFocused)
                    .submitLabel(.done).onSubmit { titleFocused = false }
                    .accessibilityIdentifier("sessionTitleField")
                if titleFocused && !sessionTitle.wrappedValue.isEmpty {
                    Button { sessionTitle.wrappedValue = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Clear session name").accessibilityIdentifier("clearSessionName")
                }
            }
            .padding(.horizontal, 8).frame(minHeight: 36)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
        (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16)) : AnyLayout(HStackLayout(spacing: 16))) {
            Button { titleFocused = false; saveSession?() } label: { Label("Save Session", systemImage: "square.and.arrow.down") }
                .accessibilityIdentifier("saveSessionButton")
            Spacer(minLength: 0)
            Button(role: .destructive) { confirmDiscard = true } label: { Label("Discard", systemImage: "trash") }
                .accessibilityIdentifier("discardSessionButton")
        }
        .font(.subheadline).frame(minHeight: 44)
        }
    }

    private var captureControls: some View {
        (dynamicTypeSize.isAccessibilitySize && settings.showButtonNames ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))) {
            primaryButton(iconOnly: true).frame(maxWidth: communicationLayout ? .infinity : nil)
            stopButton(iconOnly: true).frame(maxWidth: communicationLayout ? .infinity : nil)
            if !dynamicTypeSize.isAccessibilitySize && !communicationLayout { Spacer(minLength: 0) }
        }
    }

    private var capturePreferencesButton: some View {
            Button { showingCaptureOptions = true } label: {
                readerControlLabel("Capture preferences", symbol: "slider.horizontal.3")
            }
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Capture preferences")
            .accessibilityValue(Text(uiKey(model.saveAudio ? "Audio on" : "Audio off")) + Text(". Background: ") + Text(uiKey(model.continueInBackground ? "On" : "Off")))
            .accessibilityIdentifier("capturePreferencesButton")
    }

    private var newSessionButton: some View {
        Button {
            if needsSessionDecision { confirmNewSession = true }
            else { Task { await beginNewSession() } }
        } label: {
            NamedCircleControl(title: "New Session", symbol: "plus", prominent: true,
                               names: settings.showButtonNames)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New Session").accessibilityIdentifier("primaryCaptionAction")
    }

    @ViewBuilder private func primaryButton(iconOnly: Bool) -> some View {
        if model.state == .ended { newSessionButton }
        else {
            Button {
                Task { if model.state == .listening { await model.pause() } else { await model.start() } }
            } label: {
                NamedCircleControl(title: primaryTitle, symbol: primaryIcon, prominent: true,
                                   names: settings.showButtonNames)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(LocalizedStringKey(primaryTitle))
            .accessibilityIdentifier("primaryCaptionAction")
            .keyboardShortcut("r", modifiers: .command)
            .disabled(model.state.busy || model.preparationPending)
        }
    }

    private func stopButton(iconOnly: Bool) -> some View {
        Button { Task { await model.stop() } } label: {
            NamedCircleControl(title: "Stop", symbol: "stop.fill", prominent: false,
                               names: settings.showButtonNames)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Stop")
        .accessibilityIdentifier("stopCaptionAction")
        .keyboardShortcut(".", modifiers: .command)
        .disabled(model.state == .stopping || (!model.state.active && model.state != .paused && !isProblem))
    }

    private var readingOptions: some View {
        NavigationStack {
            Form {
                Section("Text size") {
                    Text("Make every word easy to read.")
                        .font(captionFont)
                        .lineSpacing(settings.lineSpacing)
                    CaptionSizeControl(size: $settings.captionSize)
                }
                Section("Reading style") {
                    Slider(value: $settings.lineSpacing, in: 0...16, step: 2) {
                        Text("Line spacing")
                    }
                    .accessibilityLabel("Line spacing")
                    .accessibilityValue("\(Int(settings.lineSpacing)) points")
                    Toggle("Bold text", isOn: $settings.boldCaptions)
                    Toggle("High contrast", isOn: $settings.highContrast)
                }
                ReaderPaperOptions(settings: settings)
                CaptureOptionsView(model: model, settings: settings)
                Section {
                    Toggle("Follow live captions", isOn: followBinding)
                    Toggle("Keep screen awake while listening", isOn: $settings.keepAwake)
                } footer: {
                    Text("Scroll back to reread without interrupting listening. Tap Back to live to follow again.")
                }
                Section {
                    Text("Final captions are protected in a recovery draft. After Stop, choose Save Session or Discard.")
                }
            }
            .navigationTitle("Reading options").navigationBarTitleDisplayMode(.inline)
            .toolbar { DoneToolbar { showingOptions = false } }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var statusDetails: some View {
        NavigationStack {
            Form {
                if case .problem(let message) = model.state {
                    Section("Capture problem") { interfaceMessage(message).accessibilityIdentifier("captureError") }
                }
                if let notice = model.notice { Section("Notice") { Text(LocalizedStringKey(notice)) } }
                Section("Speech recognition") {
                    Text(LocalizedStringKey(model.readiness.description))
                    if model.readiness == .authorizationRequired {
                        Button("Allow Speech Recognition") { Task { await model.requestSpeechPermission() } }
                            .disabled(model.state.active || model.state.busy || model.preparationPending)
                    }
                    if model.readiness == .missingAssets {
                        Button("Install Selected Language Model (Internet required)") { Task { await model.installAssets() } }
                            .disabled(model.state.active || model.state.busy || model.preparationPending)
                    }
                    if model.permissionDenied || model.readiness == .authorizationDenied {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }
                    }
                }
                Section("Privacy and saving") {
                    Text("Recovery drafts remain on this device. Save Session keeps them in your library; Discard deletes the transcript and recorded audio.")
                    Text("On-device captions in the selected language. Accuracy varies with distance, noise and speech.")
                }
            }
            .navigationTitle("Session information").navigationBarTitleDisplayMode(.inline)
            .toolbar { DoneToolbar { showingStatus = false } }
        }
    }

    private var statusMessage: String? {
        if case .problem(let message) = model.state {
            return model.canResume && needsSessionDecision ? "Capture interrupted · draft available" : message
        }
        if model.state == .paused { return "Paused · microphone off" }
        if model.permissionDenied { return "Microphone access needed" }
        switch model.readiness {
        case .ready: break
        case .checking: return "Checking speech recognition…"
        case .authorizationRequired: return "Enable speech recognition"
        case .authorizationDenied: return "Speech recognition access needed"
        case .authorizationRestricted: return "Speech recognition is restricted"
        case .missingAssets, .systemModelUnavailable: return "Selected speech model needed"
        case .downloading: return "Installing Selected speech model…"
        case .unsupportedDevice, .unsupportedLanguage: return "Selected language unavailable"
        case .problem: return "Speech recognition needs attention"
        }
        if let notice = model.notice { return notice }

        return nil
    }

    private var statusTitle: String {
        switch model.state {
        case .idle: return "Ready"
        case .preparing: return "Preparing"
        case .listening: return "Transcribing"
        case .stopping: return "Finishing"
        default: return model.state.title
        }
    }

    private var primaryTitle: String {
        switch model.state {
        case .listening: return "Pause"
        case .paused, .problem: return "Resume"
        case .preparing: return "Preparing…"
        case .stopping: return "Finishing…"
        case .ended: return "New Session"
        case .idle: return settings.saveAudio ? "Start Recording" : "Start Listening"
        }
    }

    private var primaryIcon: String {
        switch model.state {
        case .listening: return "pause.fill"
        case .paused, .problem: return "play.fill"
        case .ended: return "plus"
        default: return "mic.fill"
        }
    }

    private var hasCaptions: Bool { !model.transcript.finalized.isEmpty || !model.transcript.partial.isEmpty }
    private var isProblem: Bool { if case .problem = model.state { true } else { false } }

    private func beginNewSession() async {
        if let newSession { await newSession() } else { await model.reset() }
        resetReaderPosition()
    }

    private func resetReaderPosition() {
        guard model.state == .idle else { return }
        readingStartID = nil
        followLive = true
    }

    private func applyWakePreference() {
        UIApplication.shared.isIdleTimerDisabled = settings.keepAwake && model.state == .listening
    }

    private func scrollToLive(_ proxy: ScrollViewProxy) {
        guard followLive else { return }
        // A lazy stack can still have the previous content size during onChange.
        // Coalesce bursts and repeat after layout; never jump after the user scrolls back.
        followScrollTask?.cancel()
        proxy.scrollTo("liveBottom", anchor: .bottom)
        followScrollTask = Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(70)) } catch { return }
            guard followLive, !Task.isCancelled else { return }
            proxy.scrollTo("liveBottom", anchor: .bottom)
        }
    }
}

/// One recognizable return-to-bottom affordance for original and bilingual readers.
struct ReturnToLiveButton: View {
    @Environment(AppSettings.self) private var settings
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 32)).symbolRenderingMode(.palette)
                    .foregroundStyle(Color.accentColor, Color(uiColor: .systemBackground))
                    .frame(width: 44, height: 44).background(.regularMaterial, in: Circle())
                if settings.showButtonNames {
                    Text("Back to live text").font(.caption).padding(4)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }.buttonStyle(.plain)
            .accessibilityLabel("Back to live text").help("Back to live text")
    }
}

private struct CapturePreferenceLabel: View {
    let title: String
    let enabled: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(LocalizedStringKey(title)).fixedSize(horizontal: false, vertical: true)
            Label(uiKey(enabled ? "On" : "Off"), systemImage: enabled ? "checkmark.circle.fill" : "circle")
                .font(.caption)
        }.frame(minHeight: 44)
    }
}

/// Compact completion action. Keep a spoken name and a full-size touch target.
struct DoneButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label("Done", systemImage: "checkmark").font(.body.weight(.semibold))
                .labelStyle(AccessibleControlLabelStyle()).frame(minWidth: 44, minHeight: 44)
        }.accessibilityLabel("Done").help("Done")
    }
}

/// Every dismiss-only sheet uses the same trailing check. Editors keep explicit Cancel and Save.
struct DoneToolbar: ToolbarContent {
    let action: () -> Void
    var body: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) { DoneButton(action: action) }
    }
}
