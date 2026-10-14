#if compiler(>=6.2)
import AVFoundation
import Speech

/// Converter state and buffers stay on this actor, away from presentation.
@available(iOS 26.0, *)
actor AudioConversion {
    private var converter: AVAudioConverter?
    private let target: AVAudioFormat

    init(target: AVAudioFormat) { self.target = target }

    /// Convierte muestras al formato elegido por Speech; no realiza reconocimiento de palabras.
    /// El converter conserva estado entre bloques y entrega cada buffer fuente una sola vez.
    func convert(_ audio: CapturedAudio) throws -> AnalyzerInput? {
        let source = audio.buffer
        if source.format == target { return AnalyzerInput(buffer: source) }
        if converter == nil {
            converter = AVAudioConverter(from: source.format, to: target)
        }
        guard let converter else { throw TranscriptionFailure.format }
        let capacity = AVAudioFrameCount(ceil(Double(source.frameLength) * target.sampleRate / source.format.sampleRate) + 32)
        guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else {
            throw TranscriptionFailure.format
        }
        var supplied = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            if supplied {
                inputStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            inputStatus.pointee = .haveData
            return source
        }
        guard status != .error, error == nil else { throw TranscriptionFailure.format }
        return output.frameLength > 0 ? AnalyzerInput(buffer: output) : nil
    }

    /// Drena muestras retenidas por el conversor al cerrar; limita iteraciones para no esperar sin fin.
    func flush() throws -> [AnalyzerInput] {
        guard let converter else { return [] }
        var inputs: [AnalyzerInput] = []
        for _ in 0..<16 {
            guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: 1024) else {
                throw TranscriptionFailure.format
            }
            var error: NSError?
            let status = converter.convert(to: output, error: &error) { _, inputStatus in
                inputStatus.pointee = .endOfStream
                return nil
            }
            guard status != .error, error == nil else { throw TranscriptionFailure.format }
            if output.frameLength > 0 { inputs.append(AnalyzerInput(buffer: output)) }
            if status == .endOfStream { return inputs }
        }
        throw TranscriptionFailure.format
    }
}
#endif
