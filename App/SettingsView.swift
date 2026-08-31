import SwiftUI
import SwiftData
import ScreenshotKit

/// Tools + settings sheet: the Photos-scan entry point, plus (in DEBUG) a dev
/// menu with seed / reset / wipe controls.
struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var scanState: ScanState = .idle
    @State private var scanMessage = ""

    enum ScanState: Equatable { case idle, scanning, done }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.s3) {

                    // ---- Photos scanner ----
                    section("Scan your screenshots") {
                        Text("Pull in screenshots you didn't share, and keep the useful info from each. Nothing leaves your device.")
                            .font(Theme.Text.body())
                            .foregroundStyle(Theme.Palette.ink(0.72))

                        Button {
                            Task { await runScan() }
                        } label: {
                            Text(scanState == .scanning ? "Scanning…" : "Scan screenshots now")
                                .font(Theme.Text.list())
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .foregroundStyle(.white)
                                .background(scanState == .scanning ? Theme.Palette.ink(0.35) : Theme.Palette.live)
                        }
                        .disabled(scanState == .scanning)

                        if !scanMessage.isEmpty {
                            Text(scanMessage)
                                .font(Theme.Text.meta())
                                .foregroundStyle(Theme.Palette.ink(0.5))
                        }
                    }

                    #if DEBUG
                    devMenu
                    #endif

                    Spacer(minLength: Theme.Space.s4)
                }
                .padding(Theme.Space.s3)
            }
            .background(Theme.Palette.paper.ignoresSafeArea())
            .navigationTitle("Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(Theme.Palette.live)
                }
            }
        }
    }

    #if DEBUG
    private var devMenu: some View {
        section("Developer") {
            devButton("Seed sample data") { SampleData.seed(context) }
            devButton("Reset (wipe + reseed)") { SampleData.reset(context) }
            devButton("Wipe all data") { SampleData.wipe(context) }
        }
    }

    private func devButton(_ title: String, _ action: @escaping @MainActor () -> Void) -> some View {
        Button {
            action()
            scanMessage = "\(title) — done."
        } label: {
            Text(title).font(Theme.Text.list())
                .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 12)
                .foregroundStyle(Theme.Palette.ink)
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.Palette.rule).frame(height: 1) }
    }
    #endif

    // MARK: pieces

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s2) {
            Text(title.uppercased())
                .font(Theme.Text.meta()).foregroundStyle(Theme.Palette.ink(0.5))
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @MainActor
    private func runScan() async {
        scanState = .scanning
        scanMessage = ""
        do {
            let imported = try await PhotoScanner.scan(context: context) { p in
                scanMessage = "Scanned \(p.scanned) of \(p.total)…"
            }
            scanState = .done
            scanMessage = imported == 0
                ? "No new screenshots found."
                : "Imported \(imported) new screenshot\(imported == 1 ? "" : "s")."
        } catch {
            scanState = .idle
            scanMessage = "\(error)"
        }
    }
}
