import ArgumentParser
import Foundation

public enum OutputFormat: String, CaseIterable, ExpressibleByArgument, Sendable {
    case table
    case csv
    case json

    /// Renders results in this format. Output always ends with a newline.
    public func render(_ results: [FileResult], algorithms: Set<HashAlgorithm>) throws -> String {
        switch self {
        case .table: return Formatters.table(results, algorithms: algorithms)
        case .csv: return Formatters.csv(results)
        case .json: return try Formatters.json(results)
        }
    }

    /// Chooses the format: explicit `--format` wins, then the output file extension, then table.
    public static func infer(explicit: OutputFormat?, outputPath: String?) -> OutputFormat {
        if let explicit { return explicit }
        switch (outputPath.map { ($0 as NSString).pathExtension.lowercased() }) {
        case "csv": return .csv
        case "json": return .json
        default: return .table
        }
    }
}

public enum Formatters {
    public static func formatDuration(_ seconds: Double?) -> String {
        guard let seconds, seconds.isFinite, seconds >= 0 else { return "-" }
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    // MARK: CSV (RFC 4180)

    public static func csvField(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    public static func csv(_ results: [FileResult]) -> String {
        var lines = ["path,phash,oshash,duration,status,error"]
        for result in results {
            let fields = [
                result.path,
                result.phash ?? "",
                result.oshash ?? "",
                result.duration.map { String(format: "%.3f", $0) } ?? "",
                result.isSuccess ? "ok" : "error",
                result.error ?? ""
            ]
            lines.append(fields.map(csvField).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: JSON

    public static func json(_ results: [FileResult]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try encoder.encode(results), as: UTF8.self) + "\n"
    }

    // MARK: Table

    public static func table(_ results: [FileResult], algorithms: Set<HashAlgorithm>) -> String {
        var header = ["PATH"]
        if algorithms.contains(.phash) { header.append("PHASH") }
        if algorithms.contains(.oshash) { header.append("OSHASH") }
        header.append("DURATION")
        let hasErrors = results.contains { !$0.isSuccess }
        if hasErrors { header.append("ERROR") }

        var rows = [header]
        for result in results {
            var row = [result.path]
            if algorithms.contains(.phash) { row.append(result.phash ?? "-") }
            if algorithms.contains(.oshash) { row.append(result.oshash ?? "-") }
            row.append(formatDuration(result.duration))
            if hasErrors { row.append(result.error.map(singleLine) ?? "") }
            rows.append(row)
        }

        let columnCount = header.count
        var widths = [Int](repeating: 0, count: columnCount)
        for row in rows { for (i, cell) in row.enumerated() { widths[i] = max(widths[i], cell.count) } }

        return rows.map { row in
            row.enumerated().map { i, cell in
                i == columnCount - 1 ? cell : cell.padding(toLength: widths[i], withPad: " ", startingAt: 0)
            }.joined(separator: "  ")
        }.map { $0.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression) }
        .joined(separator: "\n") + "\n"
    }

    private static func singleLine(_ text: String) -> String {
        text.split(whereSeparator: \.isNewline).joined(separator: " ")
    }
}
