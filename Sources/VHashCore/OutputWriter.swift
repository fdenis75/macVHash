import Foundation

/// Validates and writes the results file.
public enum OutputWriter {
    /// Checks everything that can be checked before doing expensive work.
    public static func preflight(path: String, force: Bool) throws {
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        var isDirectory: ObjCBool = false

        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue { throw VHashError.outputIsDirectory(path) }
            if !force { throw VHashError.outputExists(path) }
            guard fileManager.isWritableFile(atPath: url.path) else { throw VHashError.outputNotWritable(path) }
            return
        }

        let directory = url.deletingLastPathComponent().path
        var directoryIsDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directory, isDirectory: &directoryIsDirectory),
              directoryIsDirectory.boolValue
        else { throw VHashError.outputDirectoryMissing(directory) }
        guard fileManager.isWritableFile(atPath: directory) else { throw VHashError.outputNotWritable(path) }
    }

    /// Atomically writes `text` (temp file + rename).
    public static func write(_ text: String, to path: String, force: Bool) throws {
        try preflight(path: path, force: force)
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        do {
            try Data(text.utf8).write(to: url, options: .atomic)
        } catch {
            throw VHashError.outputWriteFailed(path: path, reason: error.localizedDescription)
        }
    }
}
