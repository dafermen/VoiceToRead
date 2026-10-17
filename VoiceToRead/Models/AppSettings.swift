import Foundation
import Observation
import SwiftUI
import UIKit

enum InterfaceLanguage: String, CaseIterable {
    case english = "en", spanish = "es"
    var name: String { self == .english ? "English" : "Español" }
    var locale: Locale { Locale(identifier: rawValue) }
}

enum AppAppearance: String, CaseIterable, Equatable, Hashable, Sendable {
    case system, light, dark
}

/// Persist a stable locale; unknown/older preferences retain English as the default.
enum CaptureLanguage: String, CaseIterable, Sendable, Codable {
    case english = "en-US", spanish = "es-ES", french = "fr-FR", korean = "ko-KR"
    var name: String {
        switch self { case .english: "English"; case .spanish: "Español"; case .french: "Français"; case .korean: "한국어" }
    }
    var pickerLabel: LocalizedStringKey {
        switch self { case .english: "English"; case .spanish: "Español"; case .french: "French · Français"; case .korean: "Korean · 한국어" }
    }
    var code: String { String(rawValue.prefix(2)) }
    /// Used only to interpret old English/Spanish data and provide a safe first choice.
    var defaultTarget: Self { self == .english ? .spanish : .english }
    var mode: TranscriptLanguage {
        switch self { case .english: .english; case .spanish: .spanish; case .french: .french; case .korean: .korean }
    }
    var greeting: String {
        switch self { case .english: "Hello"; case .spanish: "Hola"; case .french: "Bonjour"; case .korean: "안녕하세요" }
    }
}

/// Stable palette IDs are saved instead of platform color objects. Every language owns
/// one color, regardless of whether it is currently the original or the translation.
enum LanguageColor: String, CaseIterable, Sendable {
    case blue, green, purple, orange
    var label: String { rawValue.capitalized }
    var accent: Color {
        switch self { case .blue: .blue; case .green: .green; case .purple: .purple; case .orange: .orange }
    }
    func background(_ scheme: ColorScheme, highContrast: Bool = false) -> Color {
        if highContrast { return scheme == .dark ? .black : .white }
        switch (self, scheme) {
        case (.blue, .dark): return Color(red: 0.08, green: 0.16, blue: 0.24)
        case (.green, .dark): return Color(red: 0.08, green: 0.20, blue: 0.15)
        case (.purple, .dark): return Color(red: 0.20, green: 0.12, blue: 0.26)
        case (.orange, .dark): return Color(red: 0.25, green: 0.15, blue: 0.07)
        case (.blue, _): return Color(red: 0.89, green: 0.95, blue: 1)
        case (.green, _): return Color(red: 0.90, green: 0.97, blue: 0.91)
        case (.purple, _): return Color(red: 0.95, green: 0.90, blue: 0.99)
        case (.orange, _): return Color(red: 1, green: 0.94, blue: 0.85)
        }
    }
}

/// Same pale surface as the language card, with a persistent language label.
/// Disabled controls retain the language color; accessibility still exposes disabled state.
struct LanguageButtonStyle: ButtonStyle {
    let color: LanguageColor
    let highContrast: Bool
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        let strong = highContrast || contrast == .increased
        configuration.label.padding(.horizontal, 10).padding(.vertical, 8)
            .foregroundStyle(Color.primary)
            .background(color.background(scheme, highContrast: strong), in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(strong ? Color.primary : color.accent.opacity(enabled ? 0.8 : 0.4), lineWidth: strong ? 2 : 1)
                    .accessibilityHidden(true)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(configuration.isPressed ? 0.08 : 0))
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
    }
}

enum ReaderPaper: String, CaseIterable {
    case system, yellow, blue, green, purple
    var label: String {
        switch self { case .system: "System"; case .yellow: "Amarillo claro"; case .blue: "Azul claro"
        case .green: "Verde claro"; case .purple: "Morado claro" }
    }
    var color: Color {
        switch self {
        case .system: Color(uiColor: .systemBackground)
        case .yellow: Color(red: 1, green: 0.97, blue: 0.82)
        case .blue: Color(red: 0.87, green: 0.95, blue: 1)
        case .green: Color(red: 0.89, green: 0.97, blue: 0.87)
        case .purple: Color(red: 0.95, green: 0.89, blue: 0.99)
        }
    }
}

/// One base-size range for sliders, pinch gestures and VoiceOver actions.
/// Dynamic Type still scales this base size to respect the system preference.
enum CaptionTextSize {
    static let range: ClosedRange<Double> = 14...60
    static let defaultValue: Double = 28
    static func clamped(_ value: Double) -> Double {
        guard value.isFinite else { return defaultValue }
        return min(max(value, range.lowerBound), range.upperBound)
    }
}

/// Shared controls keep live captions and saved-session playback in sync.
struct CaptionSizeControl: View {
    @Binding var size: Double
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Text size")
                Spacer()
                Text("\(Int(size)) points").monospacedDigit()
            }
            Slider(value: $size, in: CaptionTextSize.range, step: 2)
                .accessibilityLabel("Caption size")
                .accessibilityValue(Text("\(Int(size)) points"))
        }
    }
}

@MainActor
@Observable
final class AppSettings {
    @ObservationIgnored private let defaults: UserDefaults
    var captionSize: Double { didSet { defaults.set(captionSize, forKey: "captionSize") } }
    var lineSpacing: Double { didSet { defaults.set(lineSpacing, forKey: "lineSpacing") } }
    var boldCaptions: Bool { didSet { defaults.set(boldCaptions, forKey: "boldCaptions") } }
    var highContrast: Bool { didSet { defaults.set(highContrast, forKey: "highContrast") } }
    var keepAwake: Bool { didSet { defaults.set(keepAwake, forKey: "keepAwake") } }
    // Remember choices; audio defaults on only for a fresh installation, never auto-starts.
    var saveAudio: Bool { didSet { defaults.set(saveAudio, forKey: "saveAudio") } }
    /// Opt-in: processing may suppress distant speakers and loudspeaker playback.
    var reduceBackgroundNoise: Bool { didSet { defaults.set(reduceBackgroundNoise, forKey: "reduceBackgroundNoise") } }
    var continueInBackground: Bool { didSet { defaults.set(continueInBackground, forKey: "continueInBackground") } }
    var appearance: AppAppearance { didSet { defaults.set(appearance.rawValue, forKey: "appearance") } }
    var interfaceLanguage: InterfaceLanguage { didSet { defaults.set(interfaceLanguage.rawValue, forKey: "interfaceLanguage") } }
    var captureLanguage: CaptureLanguage {
        didSet {
            defaults.set(captureLanguage.rawValue, forKey: "captureLanguage")
            if translationLanguage == captureLanguage { translationLanguage = captureLanguage.defaultTarget }
        }
    }
    var translationLanguage: CaptureLanguage { didSet { defaults.set(translationLanguage.rawValue, forKey: "translationLanguage") } }
    var readerPaper: ReaderPaper { didSet { defaults.set(readerPaper.rawValue, forKey: "readerPaper") } }
    var ruledPaper: Bool { didSet { defaults.set(ruledPaper, forKey: "ruledPaper") } }
    var simpleMode: Bool { didSet { defaults.set(simpleMode, forKey: "simpleMode") } }
    var showButtonNames: Bool { didSet { defaults.set(showButtonNames, forKey: "showButtonNames") } }
    var pauseHaptics: Bool { didSet { defaults.set(pauseHaptics, forKey: "pauseHaptics") } }
    var focusedReading: Bool { didSet { defaults.set(focusedReading, forKey: "focusedReading") } }
    var preparationSeen: Bool { didSet { defaults.set(preparationSeen, forKey: "preparationSeen") } }
    var englishColor: LanguageColor { didSet { defaults.set(englishColor.rawValue, forKey: "englishLanguageColor") } }
    var spanishColor: LanguageColor { didSet { defaults.set(spanishColor.rawValue, forKey: "spanishLanguageColor") } }
    var frenchColor: LanguageColor { didSet { defaults.set(frenchColor.rawValue, forKey: "frenchLanguageColor") } }
    var koreanColor: LanguageColor { didSet { defaults.set(koreanColor.rawValue, forKey: "koreanLanguageColor") } }
    func color(for language: CaptureLanguage) -> LanguageColor {
        switch language { case .english: englishColor; case .spanish: spanishColor; case .french: frenchColor; case .korean: koreanColor }
    }
    func restoreLanguageColors() { englishColor = .blue; spanishColor = .green; frenchColor = .purple; koreanColor = .orange }
    var transcriptionLanguage: String { captureLanguage.rawValue }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        frenchColor = LanguageColor(rawValue: defaults.string(forKey: "frenchLanguageColor") ?? "") ?? .purple
        koreanColor = LanguageColor(rawValue: defaults.string(forKey: "koreanLanguageColor") ?? "") ?? .orange
        englishColor = LanguageColor(rawValue: defaults.string(forKey: "englishLanguageColor") ?? "") ?? .blue
        spanishColor = LanguageColor(rawValue: defaults.string(forKey: "spanishLanguageColor") ?? "") ?? .green
        simpleMode = defaults.bool(forKey: "simpleMode")
        showButtonNames = defaults.bool(forKey: "showButtonNames")
        pauseHaptics = defaults.object(forKey: "pauseHaptics") as? Bool ?? true
        focusedReading = defaults.bool(forKey: "focusedReading")
        preparationSeen = defaults.bool(forKey: "preparationSeen")
        interfaceLanguage = InterfaceLanguage(rawValue: defaults.string(forKey: "interfaceLanguage") ?? "") ?? .english
        let initialCapture = CaptureLanguage(rawValue: defaults.string(forKey: "captureLanguage") ?? "") ?? .english
        captureLanguage = initialCapture
        let savedTarget = CaptureLanguage(rawValue: defaults.string(forKey: "translationLanguage") ?? "")
        translationLanguage = savedTarget != initialCapture ? (savedTarget ?? initialCapture.defaultTarget) : initialCapture.defaultTarget
        readerPaper = ReaderPaper(rawValue: defaults.string(forKey: "readerPaper") ?? "") ?? .system
        ruledPaper = defaults.bool(forKey: "ruledPaper")
        let storedSize = defaults.object(forKey: "captionSize") as? Double ?? CaptionTextSize.defaultValue
        captionSize = CaptionTextSize.clamped(storedSize)
        let storedSpacing = defaults.object(forKey: "lineSpacing") as? Double ?? 4
        lineSpacing = min(max(storedSpacing.isFinite ? storedSpacing : 4, 0), 16)
        boldCaptions = defaults.bool(forKey: "boldCaptions")
        highContrast = defaults.bool(forKey: "highContrast")
        keepAwake = defaults.object(forKey: "keepAwake") as? Bool ?? true
        saveAudio = defaults.object(forKey: "saveAudio") as? Bool ?? true
        reduceBackgroundNoise = defaults.bool(forKey: "reduceBackgroundNoise")
        continueInBackground = defaults.bool(forKey: "continueInBackground")
        appearance = AppAppearance(rawValue: defaults.string(forKey: "appearance") ?? "") ?? .system
    }

    /// Call before opening/creating the persistent store. Preserve legacy installations
    /// whose old default was false but which never wrote an explicit preference.
    static func registerAudioDefault(existingInstallation: Bool, defaults: UserDefaults = .standard) {
        if defaults.object(forKey: "saveAudio") == nil {
            defaults.set(!existingInstallation, forKey: "saveAudio")
        }
    }

    var colorScheme: ColorScheme? {
        switch appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}


/// The background provides only paper color. Rules belong to each text layout.
struct ReaderSurface: View {
    let settings: AppSettings
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Group {
            if settings.highContrast { scheme == .dark ? Color.black : Color.white }
            else { settings.readerPaper.color }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct ReaderPaperOptions: View {
    @Bindable var settings: AppSettings
    var body: some View {
        Section("Fondo de lectura") {
            Picker("Color del fondo", selection: $settings.readerPaper) {
                ForEach(ReaderPaper.allCases, id: \.self) { Text(LocalizedStringKey($0.label)).tag($0) }
            }.accessibilityIdentifier("readerPaperPicker")
            Toggle("Renglones de cuaderno", isOn: $settings.ruledPaper)
                .accessibilityIdentifier("ruledPaperToggle")
            Text("Los colores claros usan texto oscuro. Alto contraste tiene prioridad y oculta los renglones.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// Visible names are optional; accessible names remain present even in the compact interface.
struct NamedCircleControl: View {
    let title: String
    let symbol: String
    let prominent: Bool
    let names: Bool
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 20, weight: .semibold))
                .frame(width: 44, height: 44)
                .foregroundStyle(prominent ? Color.white : Color.primary)
                .background(prominent ? Color.accentColor : Color.secondary.opacity(0.15), in: Circle())
            if names { Text(LocalizedStringKey(title)).font(.caption).fixedSize(horizontal: false, vertical: true) }
        }.accessibilityElement(children: .ignore).accessibilityLabel(LocalizedStringKey(title))
    }
}
struct AccessibleControlLabelStyle: LabelStyle {
    @AppStorage("showButtonNames") private var names = false
    @AppStorage("simpleMode") private var simple = false
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 4) {
            configuration.icon
            if names || simple { configuration.title.font(.caption).fixedSize(horizontal: false, vertical: true) }
        }
    }
}

/// At accessibility text sizes, allow the whole screen to scroll instead of compressing controls.
struct AccessibilityScrollingContent<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var size
    @ViewBuilder let content: () -> Content
    var body: some View {
        if size.isAccessibilitySize { ScrollView { content() } }
        else { content() }
    }
}
