import SwiftUI
import ScreenshotKit

/// App shell: two tabs (Home / Collections), each with its own navigation stack
/// so both can push into a collection's detail. Matches the prototype's bottom
/// tab bar and editorial styling.
struct RootView: View {
    @State private var tab: Tab = .home

    enum Tab: Hashable { case home, collections }

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                HomeView()
                    .navigationDestination(for: Collection.self) { CollectionDetailView(collection: $0) }
            }
            .tabItem { Label("Home", systemImage: "square.stack.3d.up") }
            .tag(Tab.home)

            NavigationStack {
                CollectionsView()
                    .navigationDestination(for: Collection.self) { CollectionDetailView(collection: $0) }
            }
            .tabItem { Label("Collections", systemImage: "square.grid.2x2") }
            .tag(Tab.collections)
        }
        .tint(Theme.Palette.live)
    }
}
