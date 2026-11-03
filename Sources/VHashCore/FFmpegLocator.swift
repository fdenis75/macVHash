import Foundation

/// Finds an ffmpeg executable the same way the VideoHash library will.
public struct FFmpegLocator: Sendable {
    public var environment: [String: String]
    public var isExecutable: @Sendable (String) -> Bool
    public var commonPaths: [String]

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        isExecutable: @escaping @Sendable (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) },
        commonPaths: [String] = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/opt/bin/ffmpeg"]
    ) {
        self.environment = environment
        self.isExecutable = isExecutable
        self.commonPaths = commonPaths
    }

    /// - Parameter override: value of `--ffmpeg-path` (a path, or a command name looked up on PATH).
    public func locate(override: String? = nil) throws -> String {
        if let override {
            if override.contains("/") {
                if isExecutable(override) { return override }
            } else if let found = searchPath(named: override) {
                return found
            }
            throw VHashError.ffmpegNotFound(requested: override)
        }
        if let found = searchPath(named: "ffmpeg") ?? commonPaths.first(where: isExecutable) {
            return found
        }
        throw VHashError.ffmpegNotFound(requested: nil)
    }

    private func searchPath(named name: String) -> String? {
        let path = environment["PATH"] ?? ""
        for directory in path.split(separator: ":") {
            let candidate = "\(directory)/\(name)"
            if isExecutable(candidate) { return candidate }
        }
        return nil
    }
}
