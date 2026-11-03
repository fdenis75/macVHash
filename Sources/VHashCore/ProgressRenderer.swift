import Foundation

/// Formats the single-line progress indicator written to stderr.
public struct ProgressRenderer: Sendable {
    public static let clearLine = "\r\u{1B}[2K"

    public var useColor: Bool
    public var width: Int

    public init(useColor: Bool, width: Int) {
        self.useColor = useColor
        self.width = max(20, width)
    }

    public func line(for update: ProgressUpdate) -> String {
        let percent = update.total == 0 ? 100 : update.done * 100 / update.total
        var head = "[\(update.done)/\(update.total) \(percent)%]"
        if update.failed > 0 {
            let text = "\(update.failed) failed"
            head += " " + (useColor ? "\u{1B}[31m\(text)\u{1B}[0m" : text)
        }
        let plainHeadCount = head.replacingOccurrences(of: "\u{1B}\\[[0-9;]*m", with: "", options: .regularExpression).count
        var used = plainHeadCount
        if let eta = eta(for: update) {
            let text = " ETA \(eta)"
            head += text
            used += text.count
        }
        let room = width - used - 2
        guard room > 8 else { return head }
        return head + " " + Self.truncate((update.result.path as NSString).lastPathComponent, to: room)
    }

    func eta(for update: ProgressUpdate) -> String? {
        guard update.done > 0, update.done < update.total else { return nil }
        let seconds = Double(update.elapsed.components.seconds)
            + Double(update.elapsed.components.attoseconds) / 1e18
        let remaining = Int((seconds / Double(update.done) * Double(update.total - update.done)).rounded())
        return String(format: "%d:%02d", remaining / 60, remaining % 60)
    }

    static func truncate(_ text: String, to limit: Int) -> String {
        guard text.count > limit else { return text }
        return "…" + text.suffix(max(1, limit - 1))
    }
}
