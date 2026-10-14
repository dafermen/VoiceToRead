import SwiftUI

func uiKey(_ key: LocalizedStringKey) -> LocalizedStringKey { key }

/// For UIKit announcements only. SwiftUI uses the selected locale environment.
enum InterfaceLocalization {
    static func string(_ key: String, language: InterfaceLanguage? = nil) -> String {
        let language = language ?? InterfaceLanguage(rawValue: UserDefaults.standard.string(forKey: "interfaceLanguage") ?? "") ?? .english
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
}

/// Some diagnostics append a system error. Localize the app prefix and any known
/// app error separately; iOS-supplied diagnostic text may retain its system language.
func interfaceMessage(_ message: String) -> Text {
    let prefix = "Audio recording was interrupted. The saved portion is available in Sessions. "
    if message.hasPrefix(prefix) {
        return Text(LocalizedStringKey(prefix)) + Text(LocalizedStringKey(String(message.dropFirst(prefix.count))))
    }
    return Text(LocalizedStringKey(message))
}
