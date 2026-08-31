import Foundation
#if canImport(Vision)
import Vision
#endif
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// The full on-device analysis of a screenshot: OCR → extracted text, then
/// category suggestion + due-date detection derived from that text.
///
/// Everything runs locally on the device (Vision for OCR; NSDataDetector +
/// heuristics for the rest). Nothing is uploaded.
public struct ScreenshotAnalysis: Sendable {
    /// The extracted text (may be empty if OCR found nothing).
    public var extractedText: String
    /// Suggested categories (top + alternates).
    public var suggestion: CategorySuggester.Suggestion
    /// Detected due date, if any.
    public var due: DetectedDueDate?

    public init(extractedText: String,
                suggestion: CategorySuggester.Suggestion,
                due: DetectedDueDate?) {
        self.extractedText = extractedText
        self.suggestion = suggestion
        self.due = due
    }
}

public enum ScreenshotAnalyzer {

    /// Analyze already-extracted text (no image needed). Useful for testing and
    /// for the Photos-scan path when text is obtained elsewhere.
    public static func analyze(text: String, now: Date = .now) -> ScreenshotAnalysis {
        ScreenshotAnalysis(
            extractedText: text,
            suggestion: CategorySuggester.suggest(for: text),
            due: DueDateDetector.detect(in: text, now: now)
        )
    }

    #if canImport(Vision) && canImport(CoreGraphics)
    /// Full pipeline: OCR the image with Vision, then analyze the text.
    /// Runs off the main actor; call from a background task.
    public static func analyze(image: CGImage, now: Date = .now) async -> ScreenshotAnalysis {
        let text = await recognizeText(in: image)
        return analyze(text: text, now: now)
    }

    /// On-device OCR via Vision. Accurate recognition, language correction on.
    public static func recognizeText(in image: CGImage) async -> String {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { req, _ in
                let lines = (req.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: "")
            }
        }
    }
    #endif
}
