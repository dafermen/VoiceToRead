import SwiftUI

@MainActor
struct HomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = CaptionViewModel()
    @State private var settings = AppSettings()

    var body: some View {
        NavigationStack { CaptionScreen(model: model, settings: settings) }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { Task { await model.background() } }
                if phase == .active { model.foregrounded() }
            }
    }
}
