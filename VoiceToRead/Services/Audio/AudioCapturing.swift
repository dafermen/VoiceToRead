import Foundation

/// Testable boundary for microphone capture. Audio capture always requires an explicit start; saving follows the session preference.
@MainActor
protocol AudioCapturing: AnyObject {
    var onLevel: (@MainActor @Sendable (Float) -> Void)? { get set }
    var permission: MicrophonePermission { get }
    var onFailure: (@MainActor @Sendable (CaptureFailure) -> Void)? { get set }
    func configureNoiseReduction(_ enabled: Bool) throws
    func requestPermission() async -> Bool
    func start() throws -> AsyncStream<Float>
    func stop() throws
}

// Non-metered test doubles and readiness tools can omit the optional display callback.
extension AudioCapturing {
    // Unsupported inputs must never silently claim to provide filtered audio.
    func configureNoiseReduction(_ enabled: Bool) throws {
        if enabled { throw CaptureFailure.noiseReductionUnavailable }
    }

    var onLevel: (@MainActor @Sendable (Float) -> Void)? {
        get { nil }
        set { }
    }
}
