import Foundation

/// Fatal, user-facing errors. Each message says what happened and what to do next.
public enum VHashError: Error, Equatable, LocalizedError {
    case pathsNotFound([String])
    case noVideosFound
    case ffmpegNotFound(requested: String?)
    case outputExists(String)
    case outputIsDirectory(String)
    case outputDirectoryMissing(String)
    case outputNotWritable(String)
    case outputWriteFailed(path: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .pathsNotFound(let paths):
            let list = paths.map { "  \($0)" }.joined(separator: "\n")
            return "Path not found:\n\(list)\nCheck the spelling, or pass an existing file or directory."
        case .noVideosFound:
            return "No video files found. Directories are scanned non-recursively by default "
                + "(use -r/--recursive) and only these extensions are matched: "
                + FileScanner.videoExtensions.sorted().joined(separator: ", ") + "."
        case .ffmpegNotFound(let requested):
            let head = requested.map { "ffmpeg not found or not executable at '\($0)'." } ?? "ffmpeg was not found on PATH."
            return "\(head) It is required to compute phash. Install it with `brew install ffmpeg`, "
                + "pass --ffmpeg-path, or run with `--hash oshash` which does not need ffmpeg."
        case .outputExists(let path):
            return "Output file already exists: \(path). Use --force to overwrite it, or choose another path."
        case .outputIsDirectory(let path):
            return "Output path is a directory: \(path). Provide a file path for -o/--output."
        case .outputDirectoryMissing(let path):
            return "Output directory does not exist: \(path). Create it first (mkdir -p) or choose another path."
        case .outputNotWritable(let path):
            return "Cannot write to \(path): permission denied. Check the directory permissions or choose another path."
        case .outputWriteFailed(let path, let reason):
            return "Failed to write \(path): \(reason)"
        }
    }

    /// Message text printed after `error:`.
    public var message: String { errorDescription ?? String(describing: self) }
}
