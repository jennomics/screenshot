import SwiftUI
import SwiftData
import ScreenshotKit

/// The main app entry point. Opens the shared App Group store so it sees
/// everything the Share Extension and Photos scanner have written.
@main
struct ScreenshotApp: App {
    let container: ModelContainer

    init() {
        // Prefers the shared App Group store; falls back to a local persistent
        // store while the paid Developer account / App Groups is pending, so
        // development isn't blocked and data still persists across launches.
        container = DataStore.resolvedContainer().container
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
