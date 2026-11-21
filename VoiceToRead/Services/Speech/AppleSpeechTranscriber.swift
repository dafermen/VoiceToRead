#if compiler(>=6.2)
import Foundation
import AVFoundation
import CoreMedia
import Speech

/// Adaptador moderno: gestiona activos, entradas y resultados de SpeechAnalyzer.
/// Suma el desplazamiento de la sesión a los tiempos del motor para alinear audio y subtítulos.
@available(iOS 26.0, *)
@MainActor
final class AppleSpeechTranscriber: SpeechTranscribing {
    enum Kind: Equatable { case speech, dictation }
    private let kind: Kind
    private var captureAssetOwner: UUID?
    private let reservations = AppleSpeechAssetInventory.shared
    private var language: CaptureLanguage = .english
    func configure(language: CaptureLanguage) { self.language = language }
    private let audio: any SpeechAudioCapturing
    private var analyzer: SpeechAnalyzer?
    private var inputTask: Task<Void, Never>?
    private var resultTask: Task<Void, Never>?
    private var levelsTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var rawInput: AsyncThrowingStream<CapturedAudio, Error>.Continuation?
    private var output: AsyncThrowingStream<TranscriptionUpdate, Error>.Continuation?
    private var generation = UUID()
    private var terminalError: (any Error)?
    private var lastAudioAt = ContinuousClock.now

    init(audio: any SpeechAudioCapturing, kind: Kind = .speech) { self.audio = audio; self.kind = kind }

    private func supportedLocale() async -> Locale? {
        let requested = Locale(identifier: language.rawValue)
        switch kind {
        case .speech: return await SpeechTranscriber.supportedLocale(equivalentTo: requested)
        case .dictation: return await DictationTranscriber.supportedLocale(equivalentTo: requested)
        }
    }
    private func module(locale: Locale) -> AppleLiveSpeechModule {
        switch kind {
        case .speech:
            return .speech(SpeechTranscriber(locale: locale, transcriptionOptions: [],
                reportingOptions: [.volatileResults, .fastResults], attributeOptions: [.audioTimeRange]))
        case .dictation:
            return .dictation(DictationTranscriber(locale: locale, contentHints: [],
                transcriptionOptions: [.punctuation], reportingOptions: [.volatileResults], attributeOptions: [.audioTimeRange]))
        }
    }

    func readiness() async -> SpeechReadiness {
        guard kind == .dictation || SpeechTranscriber.isAvailable else { return .unsupportedDevice }
        guard let locale = await supportedLocale() else {
            return .unsupportedLanguage
        }
        switch await AssetInventory.status(forModules: [module(locale: locale).value]) {
        case .installed: return .ready
        case .downloading: return .downloading
        case .supported: return .missingAssets
        case .unsupported: return .unsupportedLanguage
        @unknown default: return .problem("Speech model availability is unknown.")
        }
    }

    func installAssets() async throws {
        guard (kind == .dictation || SpeechTranscriber.isAvailable),
              let locale = await supportedLocale() else {
            throw TranscriptionFailure.notReady
        }
        let owner = UUID()
        try await reservations.acquire(locale, owner: owner)
        defer { reservations.release(owner: owner) }
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [module(locale: locale).value]) {
            try await request.downloadAndInstall()
        }
        guard await readiness() == .ready else { throw TranscriptionFailure.notReady }
    }

    func start() async throws -> AsyncThrowingStream<TranscriptionUpdate, Error> {
        await cancel()
        let startIdentifier = UUID()
        generation = startIdentifier
        guard await readiness() == .ready,
              let locale = await supportedLocale() else {
            throw TranscriptionFailure.notReady
        }
        guard generation == startIdentifier, !Task.isCancelled else { throw CancellationError() }
        // Reserve installed assets without downloading; protect this model until cleanup.
        let owner = UUID()
        try await reservations.acquire(locale, owner: owner)
        guard generation == startIdentifier, !Task.isCancelled else {
            reservations.release(owner: owner); throw CancellationError()
        }
        let transcriber = module(locale: locale)
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber.value]) else {
            reservations.release(owner: owner); throw TranscriptionFailure.format
        }
        guard generation == startIdentifier, !Task.isCancelled else {
            reservations.release(owner: owner); throw CancellationError()
        }
        let identifier = startIdentifier
        let sessionOffset = (audio as? AudioCaptureService)?.timeline.duration
        terminalError = nil
        let newAnalyzer = SpeechAnalyzer(modules: [transcriber.value])
        if kind == .dictation {
            let words = PersonalVocabulary.saved(for: language).map(\.source)
            if !words.isEmpty {
                let context = AnalysisContext()
                context.contextualStrings[.general] = words
                do { try await newAnalyzer.setContext(context) }
                catch {
                    await newAnalyzer.cancelAndFinishNow()
                    reservations.release(owner: owner)
                    throw error
                }
            }
        }
        guard generation == startIdentifier, !Task.isCancelled else {
            await newAnalyzer.cancelAndFinishNow()
            reservations.release(owner: owner); throw CancellationError()
        }
        captureAssetOwner = owner
        analyzer = newAnalyzer
        let raw = AsyncThrowingStream<CapturedAudio, Error>.makeStream(bufferingPolicy: .bufferingOldest(64))
        let inputs = AsyncThrowingStream<AnalyzerInput, Error>.makeStream(bufferingPolicy: .bufferingOldest(128))
        let results = AsyncThrowingStream<TranscriptionUpdate, Error>.makeStream(bufferingPolicy: .bufferingOldest(256))
        rawInput = raw.continuation
        output = results.continuation
        let conversion = AudioConversion(target: format)
        audio.audioSink = { frame in
            if case .dropped = raw.continuation.yield(frame) {
                raw.continuation.finish(throwing: TranscriptionFailure.overflow)
            }
        }
        audio.onFailure = { [weak self] failure in
            self?.rawInput?.finish(throwing: TranscriptionFailure.interrupted(failure.message))
        }
        resultTask = Task { @MainActor [weak self] in
            do {
                try await transcriber.forEachResult { text, range, isFinal in
                    guard !Task.isCancelled, self?.generation == identifier else { throw CancellationError() }
                    let update = TranscriptionUpdate(
                        runID: identifier, start: (sessionOffset ?? 0) + CMTimeGetSeconds(range.start),
                        end: (sessionOffset ?? 0) + CMTimeGetSeconds(CMTimeRangeGetEnd(range)),
                        text: String(text.characters), isFinal: isFinal,
                        words: text.runs.compactMap { run in
                            guard let range = run.audioTimeRange else { return nil }
                            return TimedWord(text: String(text[run.range].characters),
                                start: (sessionOffset ?? 0) + CMTimeGetSeconds(range.start),
                                end: (sessionOffset ?? 0) + CMTimeGetSeconds(CMTimeRangeGetEnd(range)))
                        }, sessionTime: sessionOffset != nil)
                    if case .dropped = results.continuation.yield(update) {
                        throw TranscriptionFailure.overflow
                    }
                }
                results.continuation.finish()
            } catch {
                if self?.generation == identifier { self?.terminalError = error }
                results.continuation.finish(throwing: error)
            }
        }
        inputTask = Task { @MainActor [weak self] in
            do {
                for try await frame in raw.stream {
                    try Task.checkCancellation()
                    if let input = try await conversion.convert(frame),
                       case .dropped = inputs.continuation.yield(input) {
                        throw TranscriptionFailure.overflow
                    }
                }
                for input in try await conversion.flush() {
                    if case .dropped = inputs.continuation.yield(input) { throw TranscriptionFailure.overflow }
                }
                inputs.continuation.finish()
            } catch {
                if self?.generation == identifier { self?.terminalError = error }
                inputs.continuation.finish(throwing: error)
                results.continuation.finish(throwing: error)
                await newAnalyzer.cancelAndFinishNow()
            }
        }
        do {
            let vocabulary = PersonalVocabulary.saved(for: language).map(\.source)
            if !vocabulary.isEmpty {
                let context = AnalysisContext()
                context.contextualStrings[.general] = vocabulary
                try await newAnalyzer.setContext(context)
            }
            try await newAnalyzer.prepareToAnalyze(in: format)
            guard generation == identifier, !Task.isCancelled else { throw CancellationError() }
            try await newAnalyzer.start(inputSequence: inputs.stream)
            guard generation == identifier, !Task.isCancelled else { throw CancellationError() }
            let levels = try audio.start()
            lastAudioAt = .now
            levelsTask = Task { @MainActor [weak self] in
                let watch = Task { @MainActor [weak self] in
                    while !Task.isCancelled {
                        do { try await Task.sleep(for: .seconds(1)) } catch { return }
                        guard let self, self.generation == identifier else { return }
                        if self.lastAudioAt.duration(to: .now) > .seconds(5) {
                            self.rawInput?.finish(throwing: TranscriptionFailure.interrupted(CaptureFailure.stalled.message))
                            return
                        }
                    }
                }
                defer { watch.cancel() }
                for await level in levels {
                    guard !Task.isCancelled, self?.generation == identifier else { return }
                    self?.lastAudioAt = .now
                    self?.audio.onLevel?(level)
                }
            }
            return results.stream
        } catch {
            if generation == identifier { await cancel() }
            throw error
        }
    }

    func finish() async throws {
        guard let analyzer else { return }
        var stopError: (any Error)?
        do { try audio.stop() } catch { stopError = error }
        audio.audioSink = nil
        rawInput?.finish()
        levelsTask?.cancel()
        let identifier = generation
        timeoutTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(10)) } catch { return }
            guard self?.generation == identifier else { return }
            self?.terminalError = TranscriptionFailure.finalizationTimeout
            self?.output?.finish(throwing: TranscriptionFailure.finalizationTimeout)
            await analyzer.cancelAndFinishNow()
        }
        await inputTask?.value
        guard generation == identifier else { throw CancellationError() }
        do {
            try await analyzer.finalizeAndFinishThroughEndOfInput()
            await resultTask?.value
            guard generation == identifier else { throw CancellationError() }
        } catch {
            if generation == identifier {
                timeoutTask?.cancel()
                await cancel()
            }
            throw error
        }
        timeoutTask?.cancel()
        let failure = terminalError ?? stopError
        cleanup()
        if let failure { throw failure }
    }

    func cancel() async {
        let cancellationID = UUID()
        generation = cancellationID
        let previousAnalyzer = analyzer
        do { try audio.stop() } catch { terminalError = error }
        audio.audioSink = nil
        rawInput?.finish()
        inputTask?.cancel()
        resultTask?.cancel()
        levelsTask?.cancel()
        timeoutTask?.cancel()
        output?.finish()
        await previousAnalyzer?.cancelAndFinishNow()
        guard generation == cancellationID else { return }
        cleanup()
    }

    private func cleanup() {
        if let owner = captureAssetOwner { reservations.release(owner: owner); captureAssetOwner = nil }
        generation = UUID()
        analyzer = nil
        inputTask = nil
        resultTask = nil
        levelsTask = nil
        timeoutTask = nil
        rawInput = nil
        output = nil
    }
}

/// Both Apple modules feed exactly the same session timeline, buffering and finalization.
@available(iOS 26.0, *)
private enum AppleLiveSpeechModule: Sendable {
    case speech(SpeechTranscriber)
    case dictation(DictationTranscriber)
    var value: any SpeechModule {
        switch self { case .speech(let module): return module; case .dictation(let module): return module }
    }
    @MainActor
    func forEachResult(_ consume: @MainActor (AttributedString, CMTimeRange, Bool) throws -> Void) async throws {
        switch self {
        case .speech(let module):
            for try await result in module.results { try consume(result.text, result.range, result.isFinal) }
        case .dictation(let module):
            for try await result in module.results { try consume(result.text, result.range, result.isFinal) }
        }
    }
}

/// Apple reports the current per-app limit; never assume that all nine languages can
/// hold a reservation simultaneously. Normalize variants using the same SDK resolver.
@available(iOS 26.0, *)
@MainActor
private final class AppleSpeechAssetInventory: SpeechAssetInventoryAccess {
    static let shared = SpeechAssetReservationManager(inventory: AppleSpeechAssetInventory())
    var maximumReservations: Int { AssetInventory.maximumReservedLocales }
    func reservations() async -> [Locale] { await AssetInventory.reservedLocales }
    func key(for locale: Locale) async -> String {
        let modern = await SpeechTranscriber.supportedLocale(equivalentTo: locale)
        let supported: Locale
        if let modern { supported = modern }
        else { supported = await DictationTranscriber.supportedLocale(equivalentTo: locale) ?? locale }
        return supported.identifier.replacingOccurrences(of: "_", with: "-").lowercased()
    }
    func reserve(_ locale: Locale) async throws { _ = try await AssetInventory.reserve(locale: locale) }
    func release(_ locale: Locale) async -> Bool { await AssetInventory.release(reservedLocale: locale) }
}
#endif
