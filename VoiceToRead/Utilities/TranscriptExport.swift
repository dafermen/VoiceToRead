import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum TranscriptExport {
    static func render(title: String, date: Date, duration: TimeInterval, language: String,
                       transcript: String, unfinished: Bool, includeDetails: Bool = true) -> String {
        guard includeDetails else { return transcript }
        return """
        \(title)
        Date: \(date.ISO8601Format())
        Listening duration: \(SessionClock.format(duration))
        Language: \(language)
        Status: \(unfinished ? "Unfinished or interrupted session" : "Ended session")
        Speech recognition may contain errors.

        \(transcript)
        """
    }

    static func filename(title: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|\n\r")
        let cleaned = title.components(separatedBy: invalid).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String((cleaned.isEmpty ? "VoiceToRead-transcript" : cleaned).prefix(80))
    }
}

struct TextTranscriptDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    let text: String
    init(text: String) { self.text = text }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let decoded = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = decoded
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

struct TranscriptFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText, .pdf] }
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
