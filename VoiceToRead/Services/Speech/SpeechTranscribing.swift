import Foundation

enum SpeechReadiness: Equatable, Sendable {
    case checking, unsupportedDevice, unsupportedLanguage, missingAssets, downloading, ready
    case authorizationRequired, authorizationDenied, authorizationRestricted, systemModelUnavailable
    case problem(String)

    var canPrepareSpeechAssets: Bool {
        switch self {
        case .missingAssets, .downloading, .authorizationRequired, .problem: return true
        default: return false
        }
    }
    var description: String {
        switch self {
        case .checking: "Checking selected speech model"
        case .unsupportedDevice: "This device does not support the on-device speech engine."
        case .unsupportedLanguage: "The selected language has no compatible on-device speech model on this device. Choose another spoken language or check for an iOS update."
        case .missingAssets: "Install the selected language model before using offline captions."
        case .downloading: "Installing the selected speech model"
        case .ready: "On-device recognition for the selected language available; verify with an offline test"
        case .authorizationRequired: "Allow speech recognition to check on-device support for the selected language."
        case .authorizationDenied: "Speech recognition access is denied. Enable it in Settings > Privacy & Security > Speech Recognition."
        case .authorizationRestricted: "Speech recognition is restricted on this device."
        case .systemModelUnavailable: "On-device recognition for the selected language is unavailable. While online, enable the selected language Dictation in device Settings, then refresh and test offline. This app cannot install the system model."
        case .problem(let message): message
        }
    }
}

enum TranscriptionFailure: LocalizedError, Sendable {
    case notReady, format, overflow, failed, interrupted(String), finalizationTimeout, assetReservationUnavailable
    var errorDescription: String? {
        switch self {
        case .assetReservationUnavailable: "No speech model slot is available while another model is in use. Stop other listening or model preparation, then try installing again."
        case .notReady: "Offline transcription is not ready. Check the selected language model."
        case .format: "The microphone audio could not be converted for recognition."
        case .overflow: "Audio processing could not keep up. Listening stopped to prevent an incomplete transcript."
        case .failed: "Speech analysis failed. Saved final captions remain available."
        case .interrupted(let message): message
        case .finalizationTimeout: "Speech finalization took too long. Current unfinished captions may be incomplete."
        }
    }
}

/// Contrato compartido por los motores reales y los dobles de prueba.
/// start entrega un flujo de revisiones; finish intenta finalizar y cancel puede perder lo provisional.
/// La interfaz no ofrece un fallback de reconocimiento remoto.
@MainActor
protocol SpeechTranscribing: AnyObject {
    func configure(language: CaptureLanguage)
    func readiness() async -> SpeechReadiness
    func requestAuthorization() async
    func installAssets() async throws
    func start() async throws -> AsyncThrowingStream<TranscriptionUpdate, Error>
    func finish() async throws
    func cancel() async
}

extension SpeechTranscribing {
    func configure(language: CaptureLanguage) {}
    func requestAuthorization() async {}
}

/// Choose once per language, before capture. A missing modern model keeps its installation
/// flow; only unsupported languages/devices use the existing offline-only Apple engine.
/// Errors and interruptions never trigger a recognizer switch in the middle of a session.
@MainActor
final class LanguageSpeechTranscriber: SpeechTranscribing {
    private let preferred: any SpeechTranscribing
    private let compatibility: any SpeechTranscribing
    private var selected: (any SpeechTranscribing)?
    private var language: CaptureLanguage = .english
    private var generation = UUID()

    init(preferred: any SpeechTranscribing, compatibility: any SpeechTranscribing) {
        self.preferred = preferred; self.compatibility = compatibility
    }
    func configure(language: CaptureLanguage) {
        guard language != self.language else { return }
        self.language = language; generation = UUID(); selected = nil
        preferred.configure(language: language); compatibility.configure(language: language)
    }
    private func resolve() async throws -> any SpeechTranscribing {
        try Task.checkCancellation()
        if let selected { return selected }
        let identifier = generation
        let status = await preferred.readiness()
        guard generation == identifier else { throw CancellationError() }
        try Task.checkCancellation()
        let engine = (status == .unsupportedLanguage || status == .unsupportedDevice) ? compatibility : preferred
        selected = engine
        return engine
    }
    func readiness() async -> SpeechReadiness {
        let identifier = generation
        do {
            let engine = try await resolve()
            let status = await engine.readiness()
            guard identifier == generation, !Task.isCancelled else { return .checking }
            return status
        } catch { return .checking }
    }
    func requestAuthorization() async {
        guard let engine = try? await resolve() else { return }
        await engine.requestAuthorization()
    }
    func installAssets() async throws {
        let engine = try await resolve()
        try await engine.installAssets()
    }
    func start() async throws -> AsyncThrowingStream<TranscriptionUpdate, Error> {
        let identifier = generation
        let engine = try await resolve()
        guard identifier == generation else { throw CancellationError() }
        let stream = try await engine.start()
        guard identifier == generation else { throw CancellationError() }
        try Task.checkCancellation()
        return stream
    }
    func finish() async throws { try await selected?.finish() }
    func cancel() async {
        generation = UUID()
        await selected?.cancel()
    }
}


/// Framework-independent reservation policy, shared by every modern speech adapter.
/// Owners protect active recognition and downloads; inactive reservations remain cached
/// until another language actually needs their slot. No transcript/audio is involved.
@MainActor
protocol SpeechAssetInventoryAccess: AnyObject {
    var maximumReservations: Int { get }
    func reservations() async -> [Locale]
    func key(for locale: Locale) async -> String
    func reserve(_ locale: Locale) async throws
    func release(_ locale: Locale) async -> Bool
}

@MainActor
final class SpeechAssetReservationManager {
    private let inventory: any SpeechAssetInventoryAccess
    private var owners: [UUID: String] = [:]
    private var lastUse: [String: UInt64] = [:]
    private var sequence: UInt64 = 0
    private var tail: Task<Void, Never>?

    init(inventory: any SpeechAssetInventoryAccess) { self.inventory = inventory }

    func acquire(_ locale: Locale, owner: UUID) async throws {
        let previous = tail
        let work = Task { @MainActor [self] in
            await previous?.value
            try Task.checkCancellation()
            let requested = await inventory.key(for: locale)
            var reserved = await snapshot()
            try Task.checkCancellation()
            if !reserved.contains(where: { $0.key == requested }) {
                let maximum = inventory.maximumReservations
                guard maximum > 0 else { throw TranscriptionFailure.assetReservationUnavailable }
                while reserved.count >= maximum {
                    let protected = Set(owners.values)
                    let unused = reserved.filter { $0.key != requested && !protected.contains($0.key) }
                        .sorted {
                            let a = lastUse[$0.key] ?? 0, b = lastUse[$1.key] ?? 0
                            return a == b ? $0.key < $1.key : a < b
                        }
                    guard let oldest = unused.first else { throw TranscriptionFailure.assetReservationUnavailable }
                    try Task.checkCancellation()
                    _ = await inventory.release(oldest.locale)
                    let updated = await snapshot()
                    guard updated.count < reserved.count else { throw TranscriptionFailure.assetReservationUnavailable }
                    reserved = updated
                }
                try Task.checkCancellation()
                try await inventory.reserve(locale)
            }
            try Task.checkCancellation()
            sequence &+= 1; lastUse[requested] = sequence
            owners[owner] = requested
        }
        tail = Task { _ = try? await work.value }
        do {
            try await withTaskCancellationHandler {
                try await work.value
                try Task.checkCancellation()
            } onCancel: { work.cancel() }
        } catch {
            owners.removeValue(forKey: owner)
            throw error
        }
    }

    /// Unpin only this operation. Keep installed assets reserved until a slot is needed.
    func release(owner: UUID) { owners.removeValue(forKey: owner) }

    private func snapshot() async -> [(locale: Locale, key: String)] {
        var result: [(locale: Locale, key: String)] = []
        for locale in await inventory.reservations() {
            result.append((locale, await inventory.key(for: locale)))
        }
        return result
    }
}
