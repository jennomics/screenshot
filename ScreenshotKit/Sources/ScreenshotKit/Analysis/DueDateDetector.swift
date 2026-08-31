import Foundation

/// A detected due date plus the source phrase it came from, so the capture
/// modal can show *why* a date was proposed.
public struct DetectedDueDate: Sendable, Equatable {
    public var date: Date
    public var phrase: String
    public init(date: Date, phrase: String) {
        self.date = date
        self.phrase = phrase
    }
}

/// On-device due-date detection over OCR'd text. Combines:
///  1. `NSDataDetector(.date)` for absolute/explicit dates ("Sep 15", "Friday").
///  2. A small set of relative-deadline phrase patterns common in screenshots
///     ("within 30 days", "ends soon", "closes Fri", "by tomorrow").
///
/// Fully local — no network. Returns the most relevant (soonest future, else
/// most recent) detection, or nil.
public enum DueDateDetector {

    public static func detect(in text: String, now: Date = .now) -> DetectedDueDate? {
        var candidates: [DetectedDueDate] = []
        candidates.append(contentsOf: dataDetectorMatches(text, now: now))
        candidates.append(contentsOf: relativePhraseMatches(text, now: now))

        guard !candidates.isEmpty else { return nil }

        // Prefer the soonest date in the future; if none are in the future,
        // take the closest to now.
        let future = candidates.filter { $0.date >= now }.sorted { $0.date < $1.date }
        if let f = future.first { return f }
        return candidates.sorted { abs($0.date.timeIntervalSince(now)) < abs($1.date.timeIntervalSince(now)) }.first
    }

    // MARK: NSDataDetector (absolute/explicit)

    private static func dataDetectorMatches(_ text: String, now: Date) -> [DetectedDueDate] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return []
        }
        let range = NSRange(text.startIndex..., in: text)
        return detector.matches(in: text, options: [], range: range).compactMap { match in
            guard let date = match.date else { return nil }
            let phrase = (text as NSString).substring(with: match.range).trimmingCharacters(in: .whitespaces)
            // NSDataDetector resolves bare times/weekdays relative to now, which
            // is what we want for "Friday", "tomorrow 5pm", etc.
            return DetectedDueDate(date: date, phrase: phrase)
        }
    }

    // MARK: Relative-deadline phrases

    /// Patterns → how to resolve them to a date. Kept small and explicit so the
    /// behavior is predictable; expand as real screenshots reveal more phrasings.
    private static func relativePhraseMatches(_ text: String, now: Date) -> [DetectedDueDate] {
        let lower = text.lowercased()
        var out: [DetectedDueDate] = []
        let cal = Calendar.current

        func add(_ days: Int, _ phrase: String) {
            if let d = cal.date(byAdding: .day, value: days, to: cal.startOfDay(for: now)) {
                out.append(DetectedDueDate(date: d, phrase: phrase))
            }
        }

        // "within N days" / "in N days" / "N-day"
        if let m = firstMatch(#"(?:within|in)\s+(\d{1,3})\s+days?"#, lower) {
            add(Int(m.1) ?? 0, m.0)
        }
        // "by tomorrow" / "tomorrow"
        if lower.contains("tomorrow") { add(1, phraseAround("tomorrow", text)) }
        // "today" / "by today" / "tonight"
        if lower.contains("tonight") || rangeContainsWord(lower, "today") { add(0, phraseAround(lower.contains("tonight") ? "tonight" : "today", text)) }
        // urgency phrases with no explicit number → soon (~3 days)
        for cue in ["ends soon", "closing soon", "closes soon", "last day", "expires soon", "sale ends"] {
            if lower.contains(cue) { add(3, phraseAround(cue, text)) }
        }
        // "closes/ends/due <weekday>" — let NSDataDetector already catch the
        // weekday, but capture the phrase for display when present.
        return out
    }

    // MARK: helpers

    /// First regex capture: returns (fullMatch, group1) if present.
    private static func firstMatch(_ pattern: String, _ text: String) -> (String, String)? {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        guard let m = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let full = ns.substring(with: m.range)
        let g1 = m.numberOfRanges > 1 ? ns.substring(with: m.range(at: 1)) : ""
        return (full, g1)
    }

    private static func rangeContainsWord(_ text: String, _ word: String) -> Bool {
        firstMatch("\\b\(NSRegularExpression.escapedPattern(for: word))\\b", text) != nil
    }

    /// Grab a short human-readable phrase around a cue from the ORIGINAL text
    /// (preserving case) for display in the modal.
    private static func phraseAround(_ cue: String, _ original: String) -> String {
        let lower = original.lowercased()
        guard let r = lower.range(of: cue) else { return cue }
        // Expand to include a couple of surrounding words for context.
        let start = original.index(r.lowerBound, offsetBy: 0)
        let end = r.upperBound
        // Widen left to the previous whitespace boundary (up to ~2 words).
        var lo = start
        var words = 0
        while lo > original.startIndex && words < 2 {
            let prev = original.index(before: lo)
            if original[prev] == " " { words += 1; if words == 2 { break } }
            lo = prev
        }
        return String(original[lo..<end]).trimmingCharacters(in: .whitespaces)
    }
}
