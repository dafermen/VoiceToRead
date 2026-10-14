import AVFoundation
import Foundation

/// Serial file writer. The tap never performs disk I/O and the queue is bounded.
/// PCM storage avoids encoder padding at each pause. M4A is produced only for export.
final class SessionAudioRecorder: @unchecked Sendable {
    private let queue = DispatchQueue(label: "VoiceToRead.recording", qos: .userInitiated)
    private let slots = DispatchSemaphore(value: 128)
    private var file: AVAudioFile?
    private var failure: Error?
    private var closed = false
    let url: URL

    init(url: URL) { self.url = url }

    /// Reserva un cupo sin bloquear el tap. Si la cola está llena, comunica el fallo explícitamente.
    /// El estado mutable del archivo se usa solo en la cola serial; cada bloque libera su cupo.
    func append(_ audio: CapturedAudio, onError: @escaping @Sendable () -> Void) {
        guard slots.wait(timeout: .now()) == .success else {
            queue.async { [self] in failure = RecordingFailure.unavailable }
            onError(); return
        }
        queue.async { [self] in
            defer { slots.signal() }
            guard !closed, failure == nil else { return }
            do {
                if file == nil {
                    let settings: [String: Any] = [AVFormatIDKey: kAudioFormatLinearPCM,
                        AVSampleRateKey: audio.buffer.format.sampleRate,
                        AVNumberOfChannelsKey: audio.buffer.format.channelCount,
                        AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false,
                        AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false]
                    file = try AVAudioFile(forWriting: url, settings: settings,
                                           commonFormat: .pcmFormatFloat32, interleaved: false)
                    try FileManager.default.setAttributes([
                        .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
                    ], ofItemAtPath: url.path)
                }
                guard let file, file.processingFormat == audio.buffer.format else {
                    throw RecordingFailure.formatChanged
                }
                try file.write(from: audio.buffer)
            } catch {
                failure = error
                onError()
            }
        }
    }

    /// Espera las escrituras anteriores y comunica un fallo; no debe llamarse desde la cola del writer.
    func flush() throws { try queue.sync { if let failure { throw failure } } }
    /// Cierra después de lo ya encolado. Mantiene el audio escrito incluso si hubo un fallo posterior.
    func finish() throws {
        try queue.sync {
            file = nil
            closed = true
            if let failure { throw failure }
        }
    }
}

enum RecordingFailure: LocalizedError {
    case formatChanged, unavailable
    var errorDescription: String? {
        switch self {
        case .formatChanged: return "The microphone format changed. Stop and start a new session. The audio already recorded is kept."
        case .unavailable: return "Audio could not be saved. Stop this session and check your available storage."
        }
    }
}

/// Sample clock shared by recording and recognition. Pauses are omitted from both.
final class CaptureTimeline: @unchecked Sendable {
    private let lock = NSLock()
    private var seconds = 0.0
    var duration: Double { lock.lock(); defer { lock.unlock() }; return seconds }
    /// Devuelve el inicio del bloque y avanza frames/sampleRate segundos bajo el mismo candado.
    /// Sin bloques durante Pause, ni la grabación ni sus subtítulos acumulan el tiempo de espera.
    func stamp(frames: AVAudioFrameCount, sampleRate: Double) -> Double {
        lock.lock(); defer { lock.unlock() }
        let start = seconds
        if sampleRate > 0 { seconds += Double(frames) / sampleRate }
        return start
    }
    func reset() { lock.lock(); seconds = 0; lock.unlock() }
}
