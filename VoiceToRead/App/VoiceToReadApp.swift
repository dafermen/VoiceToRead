import SwiftUI

/// Entrada de la app: crea la escena; AppRootView conecta vistas, servicios y almacenamiento.
@main
@MainActor
struct VoiceToReadApp: App {
    init() { PracticeFiles.removeAbandonedAttempts() }

    var body: some Scene {
        WindowGroup { AppRootView() }
    }
}
