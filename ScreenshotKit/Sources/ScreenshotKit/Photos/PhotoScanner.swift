#if canImport(Photos) && canImport(UIKit)
import Foundation
import Photos
import UIKit
import SwiftData

/// The second capture path: scans the photo library for screenshots the user
/// didn't explicitly share, runs each new one through the on-device analysis
/// pipeline, and files them as `.info` SavedItems (extracting the useful text,
/// not keeping the image) so they resurface later.
///
/// Everything is local. Dedupe is by `PHAsset.localIdentifier` stored on
/// `SavedItem.sourceAssetID`.
public enum PhotoScanner {

    public struct Progress: Sendable {
        public var scanned: Int
        public var imported: Int
        public var total: Int
    }

    public enum ScanError: Error, CustomStringConvertible {
        case notAuthorized
        public var description: String { "Photo library access was not granted." }
    }

    /// Request read access to the photo library (limited access is fine).
    @discardableResult
    public static func requestAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { cont in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { cont.resume(returning: $0) }
        }
    }

    /// Scan recent screenshots and import any not already saved.
    ///
    /// Runs entirely on the `@MainActor` so the `ModelContext` and the
    /// `SavedItem`s it creates never cross an actor boundary (SwiftData models
    /// aren't `Sendable`). The `await`s for image loading and OCR simply
    /// suspend; they don't move the context off the main actor.
    /// - Parameters:
    ///   - limit: max number of most-recent screenshots to consider.
    ///   - context: the shared model context to write into.
    ///   - onProgress: optional progress callback.
    /// - Returns: number of newly imported items.
    @MainActor
    @discardableResult
    public static func scan(
        limit: Int = 100,
        context: ModelContext,
        onProgress: ((Progress) -> Void)? = nil
    ) async throws -> Int {
        let status = await requestAuthorization()
        guard status == .authorized || status == .limited else { throw ScanError.notAuthorized }

        // Already-imported asset ids, for dedupe.
        let existing = (try? context.fetch(FetchDescriptor<SavedItem>()))?
            .compactMap(\.sourceAssetID) ?? []
        let existingSet = Set(existing)

        // Fetch screenshots, newest first.
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(
            format: "(mediaSubtype & %d) != 0",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        options.fetchLimit = limit
        let assets = PHAsset.fetchAssets(with: .image, options: options)

        var imported = 0
        let total = assets.count

        for i in 0..<assets.count {
            let asset = assets.object(at: i)
            if existingSet.contains(asset.localIdentifier) { continue }

            guard let image = await requestImage(for: asset) else { continue }
            guard let cg = image.cgImage else { continue }

            let analysis = await ScreenshotAnalyzer.analyze(image: cg,
                                                            now: asset.creationDate ?? .now)

            let item = SavedItem(
                createdAt: asset.creationDate ?? .now,
                mode: .info, // Photos-scanned items keep the info, not the image.
                extractedText: analysis.extractedText,
                sourceApp: "Photos",
                sourceAssetID: asset.localIdentifier,
                categories: [analysis.suggestion.top],
                dueDate: analysis.due?.date,
                dueSourcePhrase: analysis.due?.phrase
            )
            context.insert(item)
            imported += 1

            if let onProgress {
                onProgress(Progress(scanned: i + 1, imported: imported, total: total))
            }
        }

        try? context.save()
        return imported
    }

    /// Load a reasonably-sized image for OCR.
    private static func requestImage(for asset: PHAsset) async -> UIImage? {
        // PHImageManager can invoke the handler more than once (thumbnail then
        // full quality). A continuation must resume exactly once, so gate it.
        final class Once { var done = false }
        let once = Once()
        return await withCheckedContinuation { cont in
            let opts = PHImageRequestOptions()
            opts.isNetworkAccessAllowed = true
            opts.deliveryMode = .highQualityFormat
            opts.isSynchronous = false
            let target = CGSize(width: 1400, height: 1400)
            PHImageManager.default().requestImage(
                for: asset, targetSize: target, contentMode: .aspectFit, options: opts
            ) { image, info in
                let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard !degraded, !once.done else { return }
                once.done = true
                cont.resume(returning: image)
            }
        }
    }
}
#endif
