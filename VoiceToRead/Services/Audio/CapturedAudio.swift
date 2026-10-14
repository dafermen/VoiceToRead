import AVFoundation

/// Owns a copy of a tap buffer. Consumers must only read it; ownership never returns to the tap.
/// Contrato para estudiantes: unchecked no añade sincronización. La copia pertenece a este valor
/// y sus consumidores deben tratar el buffer de referencia como inmutable después de entregarlo.
struct CapturedAudio: @unchecked Sendable {
    let buffer: AVAudioPCMBuffer
    /// Segundos del reloj de muestras, no hora de calendario; nil indica que no hay marca disponible.
    var sessionStart: Double? = nil
}

@MainActor
protocol SpeechAudioCapturing: AudioCapturing {
    var audioSink: (@Sendable (CapturedAudio) -> Void)? { get set }
}
