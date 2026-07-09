import SwiftUI

@main
struct NautiHuskyTempApp: App {
    @State private var prefs = Preferences()
    @State private var model: SpotsModel

    init() {
        let prefs = Preferences()
        _prefs = State(initialValue: prefs)
        _model = State(initialValue: SpotsModel(prefs: prefs))
    }

    var body: some Scene {
        WindowGroup {
            #if os(watchOS)
            WatchContentView(model: model, prefs: prefs)
            #else
            ContentView(model: model, prefs: prefs)
            #endif
        }
        #if os(macOS)
        .defaultSize(width: 380, height: 620)
        #endif
    }
}
