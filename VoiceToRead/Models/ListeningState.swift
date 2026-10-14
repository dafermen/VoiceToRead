import Foundation

enum MicrophonePermission: Equatable, Sendable {
    case undetermined, granted, denied, unavailable
}

enum CaptureFailure: LocalizedError, Equatable, Sendable {
    case permissionDenied
    case permissionUnavailable
    case noInput
    case noiseReductionUnavailable
    case invalidFormat
    case engineFailure
    case recordingFailure
    case sessionFailure
    case interruption
    case routeChanged
    case configurationChanged
    case mediaServicesChanged
    case stalled

    var errorDescription: String? { message }

    var message: String {
        switch self {
        case .permissionDenied:
            "Microphone access is denied or restricted. Check Settings > Privacy & Security > Microphone. Device restrictions may prevent changes."
        case .permissionUnavailable:
            "Microphone permission is unavailable on this device."
        case .noInput:
            "No microphone input is available. Check your device and try again."
        case .noiseReductionUnavailable:
            "Noise reduction could not start. Turn it off in Capture preferences, then stop and create a new session if needed. Existing audio and text are kept."
        case .invalidFormat:
            "The microphone audio format is unavailable. Reconnect your audio device and try again."
        case .engineFailure:
            "Microphone capture could not start. Close other audio apps and try again."
        case .recordingFailure:
            "Audio could not be saved. Stop this session and check storage. The recorded portion and final text are kept."
        case .sessionFailure:
            "The audio session could not be configured or released. Try again."
        case .interruption:
            "Listening stopped because another activity interrupted the microphone. Start again when it finishes."
        case .routeChanged:
            "Listening stopped because the audio input changed. Check your microphone and start again."
        case .configurationChanged:
            "Listening stopped because the audio engine configuration changed. Start again."
        case .mediaServicesChanged:
            "System audio services changed. Start again after audio becomes available."
        case .stalled:
            "The microphone stopped delivering audio. Check your input and try again."
        }
    }
}

enum ListeningState: Equatable {
    case idle
    case requestingPermission
    case ready
    case starting
    case listening
    case stopping
    case error(CaptureFailure)

    var title: String {
        switch self {
        case .idle: "Idle"
        case .requestingPermission: "Requesting microphone permission"
        case .ready: "Ready"
        case .starting: "Starting"
        case .listening: "Listening"
        case .stopping: "Stopping"
        case .error: "Microphone problem"
        }
    }

    var canStart: Bool {
        switch self {
        case .idle, .ready, .error: true
        default: false
        }
    }

    var canStop: Bool {
        switch self {
        case .requestingPermission, .starting, .listening: true
        default: false
        }
    }
}
