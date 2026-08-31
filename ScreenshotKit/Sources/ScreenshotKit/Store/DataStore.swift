import Foundation
import SwiftData

/// Central configuration + factory for the shared on-device store.
///
/// Preferred mode: the store file lives inside the App Group container so BOTH
/// the main app and the Share Extension open the exact same database. That
/// requires a paid Apple Developer account (App Groups can't be provisioned on
/// a free Personal Team).
///
/// While the paid account is pending, `resolvedContainer()` falls back
/// gracefully so development isn't blocked:
///   1. App Group container   (shared app <-> extension)   — preferred
///   2. Local persistent store (this target's sandbox)     — dev fallback, persists
///   3. In-memory store        (last resort)               — never blocks launch
///
/// Nothing leaves the device in any mode.
public enum DataStore {

    /// The App Group identifier. Must match the entitlement enabled on BOTH the
    /// app target and the Share Extension target. Change this to your real
    /// group id when configuring signing.
    public static let appGroupID = "group.com.jennomics.screenshot"

    /// Which storage mode ended up being used (for logging/diagnostics/UI).
    public enum Mode: String, Sendable {
        case appGroup      // shared, real
        case localPersistent // dev fallback: persists but not shared
        case inMemory      // last resort
    }

    /// The models that make up the schema.
    public static let schema = Schema([
        SavedItem.self,
        Collection.self,
    ])

    // MARK: Preferred (shared) store

    /// The on-disk URL of the store, inside the shared App Group container.
    public static func appGroupStoreURL() throws -> URL {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
        else {
            throw StoreError.appGroupUnavailable(appGroupID)
        }
        return container.appending(path: "Screenshot.store")
    }

    /// Build the shared ModelContainer (App Group). Throws if the group isn't
    /// provisioned — use `resolvedContainer()` if you want the graceful fallback.
    public static func makeSharedContainer() throws -> ModelContainer {
        let config = ModelConfiguration(url: try appGroupStoreURL())
        return try ModelContainer(for: schema, configurations: config)
    }

    // MARK: Fallbacks

    /// A persistent store in the current target's own sandbox (Application
    /// Support). Persists across launches but is NOT shared with the extension.
    public static func makeLocalContainer() throws -> ModelContainer {
        let dir = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        let config = ModelConfiguration(url: dir.appending(path: "Screenshot.local.store"))
        return try ModelContainer(for: schema, configurations: config)
    }

    /// An in-memory container for previews/tests, or a last-resort fallback.
    public static func makeInMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    // MARK: Resolution

    /// Try App Group → local persistent → in-memory, returning the container
    /// and which mode was used. Never throws; always returns a usable store.
    ///
    /// When your paid account activates and you enable the App Groups
    /// capability, this automatically upgrades to the shared store — no code
    /// change needed.
    public static func resolvedContainer() -> (container: ModelContainer, mode: Mode) {
        if let shared = try? makeSharedContainer() {
            return (shared, .appGroup)
        }
        if let local = try? makeLocalContainer() {
            #if DEBUG
            print("ℹ️ App Group unavailable — using LOCAL persistent store (dev mode). " +
                  "Enable App Groups once your paid Developer account is active to share app <-> extension.")
            #endif
            return (local, .localPersistent)
        }
        // Should essentially never happen; keeps the app launchable regardless.
        let mem = try! makeInMemoryContainer()
        return (mem, .inMemory)
    }

    public enum StoreError: Error, CustomStringConvertible {
        case appGroupUnavailable(String)
        public var description: String {
            switch self {
            case .appGroupUnavailable(let id):
                return "App Group container unavailable for '\(id)'. Enable the App Groups capability with this identifier on both the app and the Share Extension targets (requires a paid Apple Developer account)."
            }
        }
    }
}
