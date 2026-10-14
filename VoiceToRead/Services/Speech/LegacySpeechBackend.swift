import AVFoundation
import Speech

struct LegacySpeechResult: Sendable {
    let text: String
    let end: Double
    let isFinal: Bool
    var words: [TimedWord] = []
}

/// The system recognizer is isolated here so lifecycle/offline policy can be tested without a microphone.
@MainActor
protocol LegacySpeechRecognizing: AnyObject {
    var authorization: SFSpeechRecognizerAuthorizationStatus { get }
    var supportsLocale: Bool { get }
    var supportsOnDeviceRecognition: Bool { get }
    var isAvailable: Bool { get }
    func configure(language: CaptureLanguage)
    func requestAuthorization() async
    func start(receive: @escaping @MainActor (Result<LegacySpeechResult, Error>) -> Void) throws
    func append(_ audio: CapturedAudio)
    func endAudio()
    func cancel()
}

@MainActor
final class LegacySpeechBackend: LegacySpeechRecognizing {
    private var language: CaptureLanguage = .english
    private var recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    func configure(language: CaptureLanguage) {
        guard language != self.language else { return }
        cancel(); self.language = language
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: language.rawValue))
    }
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    var authorization: SFSpeechRecognizerAuthorizationStatus { SFSpeechRecognizer.authorizationStatus() }
    var supportsLocale: Bool { recognizer != nil }
    var supportsOnDeviceRecognition: Bool { recognizer?.supportsOnDeviceRecognition == true }
    var isAvailable: Bool { recognizer?.isAvailable == true }

    func requestAuthorization() async {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { _ in continuation.resume() }
        }
    }

    static func offlineRequest(language: CaptureLanguage = .english) -> SFSpeechAudioBufferRecognitionRequest {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.taskHint = .dictation
        request.contextualStrings = PersonalVocabulary.saved(for: language).map(\.source)
        return request
    }

    func start(receive: @escaping @MainActor (Result<LegacySpeechResult, Error>) -> Void) throws {
        cancel()
        // Check again for every request, including automatic rotations. Never fall back to a server.
        guard authorization == .authorized, let recognizer,
              recognizer.supportsOnDeviceRecognition, recognizer.isAvailable else {
            throw TranscriptionFailure.notReady
        }
        let request = Self.offlineRequest(language: language)
        self.request = request
        task = recognizer.recognitionTask(with: request) { result, error in
            // Copy framework results before crossing to the presentation executor.
            let snapshot = result.map { result in
                LegacySpeechResult(text: result.bestTranscription.formattedString,
                    end: result.bestTranscription.segments.map { $0.timestamp + $0.duration }.max() ?? 0,
                    isFinal: result.isFinal, words: result.bestTranscription.segments.map {
                        TimedWord(text: $0.substring, start: $0.timestamp, end: $0.timestamp + $0.duration)
                    })
            }
            Task { @MainActor in
                if let snapshot { receive(.success(snapshot)) }
                if let error, snapshot?.isFinal != true { receive(.failure(error)) }
            }
        }
    }

    func append(_ audio: CapturedAudio) { request?.append(audio.buffer) }
    func endAudio() { request?.endAudio() }
    func cancel() {
        task?.cancel()
        task = nil
        request = nil
    }
}

extension LegacySpeechRecognizing { func configure(language: CaptureLanguage) {} }
