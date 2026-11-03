import Foundation

/// Expands user-supplied paths into a sorted, de-duplicated list of video files.
public struct FileScanner: Sendable {
    public static let videoExtensions: Set<String> = [
        "mp4", "m4v", "mov", "mkv", "avi", "wmv", "flv", "webm", "mpg", "mpeg",
        "ts", "m2ts", "mts", "3gp", "ogv", "vob"
    ]

    public struct Output: Sendable, Equatable {
        public var files: [URL]
        /// Non-fatal notes, e.g. a directory that contained no videos.
        public var warnings: [String]
    }

    public var recursive: Bool

    public init(recursive: Bool = false) {
        self.recursive = recursive
    }

    /// - Throws: `VHashError.pathsNotFound` when any input does not exist,
    ///   `VHashError.noVideosFound` when nothing remains after filtering.
    public func scan(inputs: [String]) throws -> Output {
        let fileManager = FileManager.default
        var missing: [String] = []
        var seen = Set<String>()
        var files: [URL] = []
        var warnings: [String] = []

        func add(_ url: URL) {
            let normalized = url.standardizedFileURL
            if seen.insert(normalized.path).inserted { files.append(normalized) }
        }

        for input in inputs {
            let expanded = (input as NSString).expandingTildeInPath
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: expanded, isDirectory: &isDirectory) else {
                missing.append(input)
                continue
            }
            let url = URL(fileURLWithPath: expanded)
            if isDirectory.boolValue {
                let found = try videos(in: url)
                if found.isEmpty { warnings.append("No video files found in \(input)") }
                found.forEach(add)
            } else {
                add(url)  // Explicitly named files are always accepted.
            }
        }

        if !missing.isEmpty { throw VHashError.pathsNotFound(missing) }
        guard !files.isEmpty else { throw VHashError.noVideosFound }
        files.sort { $0.path < $1.path }
        return Output(files: files, warnings: warnings)
    }

    private func videos(in directory: URL) throws -> [URL] {
        let fileManager = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey]
        var result: [URL] = []

        func consider(_ url: URL) {
            guard Self.videoExtensions.contains(url.pathExtension.lowercased()) else { return }
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if !isDirectory { result.append(url) }
        }

        if recursive {
            guard let enumerator = fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { return [] }
            for case let url as URL in enumerator { consider(url) }
        } else {
            let entries = try fileManager.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]
            )
            entries.forEach(consider)
        }
        return result
    }
}
