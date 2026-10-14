import Foundation

struct SubtitleCue: Identifiable, Equatable, Sendable {
    let id: Int
    let paragraphID: UUID
    let start: Double
    let end: Double
    let text: String
}

enum SubtitleFormat: String, CaseIterable { case srt, vtt }

/// Funciones puras: transforman párrafos revisados y tiempos en cues/archivos sin acceder al disco.
/// No inventan sincronización para sesiones antiguas que no tienen tiempos guardados.
enum SubtitleExport {
    /// Corrected text keeps its paragraph audio range. Word timing is retained
    /// when words match; inserted/replaced words are distributed over that range.
    static func cues(paragraphs: [ReviewParagraph], timings: [String: CaptionTiming]) -> [SubtitleCue] {
        var result: [SubtitleCue] = []
        for paragraph in paragraphs {
            guard let timing = timings[paragraph.id.uuidString], timing.start.isFinite, timing.end.isFinite,
                  timing.start >= 0, timing.end > timing.start else { continue }
            let tokens = paragraph.text.split(whereSeparator: \.isWhitespace).map(String.init)
            guard !tokens.isEmpty else { continue }
            let native = timing.words.filter {
                $0.start.isFinite && $0.end.isFinite && $0.end > $0.start &&
                $0.start >= timing.start && $0.end <= timing.end + 0.05
            }.flatMap { word -> [TimedWord] in
                let pieces = word.text.split(whereSeparator: \.isWhitespace).map(String.init)
                return pieces.enumerated().map { index, text in
                    let step = (word.end - word.start) / Double(pieces.count)
                    return TimedWord(text: text, start: word.start + Double(index) * step,
                                     end: word.start + Double(index + 1) * step)
                }
            }
            let matches = tokens.count == native.count && zip(tokens, native).allSatisfy {
                normalized($0.0) == normalized($0.1.text)
            }
            let start = native.first?.start ?? timing.start
            let end = native.last?.end ?? timing.end
            let words = tokens.enumerated().map { index, token -> TimedWord in
                if matches { return TimedWord(text: token, start: native[index].start, end: native[index].end) }
                let step = (end - start) / Double(tokens.count)
                return TimedWord(text: token, start: start + Double(index) * step,
                                 end: start + Double(index + 1) * step)
            }
            var group: [TimedWord] = []
            func emit() {
                guard let first = group.first, let last = group.last else { return }
                let text = wrapped(group.map(\.text).joined(separator: " "))
                result.append(SubtitleCue(id: result.count, paragraphID: paragraph.id,
                    start: first.start, end: max(first.start + 0.001, last.end), text: text))
                group = []
            }
            for word in words {
                if let first = group.first, let last = group.last,
                   group.map(\.text).joined(separator: " ").count + word.text.count + 1 > 76 ||
                   word.end - first.start > 5 || word.start - last.end > 0.8 { emit() }
                group.append(word)
            }
            emit()
        }
        // Rounding to milliseconds must never produce overlapping or zero-length cues.
        let ordered = result.sorted { $0.start < $1.start }
        return ordered.enumerated().compactMap { index, cue in
            let next = index + 1 < ordered.count ? ordered[index + 1].start : cue.end
            let start = (cue.start * 1000).rounded() / 1000
            let end = (min(cue.end, next) * 1000).rounded() / 1000
            guard end > start else { return nil }
            return SubtitleCue(id: index, paragraphID: cue.paragraphID, start: start, end: end, text: cue.text)
        }
    }

    /// SRT usa coma en milisegundos; WebVTT usa punto y cabecera. Se escapa el texto como contenido.
    static func render(_ cues: [SubtitleCue], format: SubtitleFormat) -> String {
        let body = cues.enumerated().map { index, cue in
            "\(index + 1)\n\(timestamp(cue.start, format: format)) --> \(timestamp(cue.end, format: format))\n\(escaped(cue.text))\n"
        }.joined(separator: "\n")
        return (format == .vtt ? "WEBVTT\n\n" : "") + body
    }

    static func timestamp(_ seconds: Double, format: SubtitleFormat) -> String {
        let ms = Int64((max(0, seconds.isFinite ? min(seconds, 315360000) : 0) * 1000).rounded())
        return String(format: "%02lld:%02lld:%02lld%@%03lld", ms / 3600000,
                      (ms / 60000) % 60, (ms / 1000) % 60, format == .srt ? "," : ".", ms % 1000)
    }

    private static func normalized(_ text: String) -> String {
        String(text.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }
    private static func escaped(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
    }
    private static func wrapped(_ text: String) -> String {
        let words = text.split(separator: " ")
        var lines = [""]
        for word in words {
            let last = lines.count - 1
            if !lines[last].isEmpty && lines[last].count + word.count + 1 > 40 && lines.count < 2 {
                lines.append(String(word))
            } else {
                lines[last] += (lines[last].isEmpty ? "" : " ") + word
            }
        }
        return lines.joined(separator: "\n")
    }
}
