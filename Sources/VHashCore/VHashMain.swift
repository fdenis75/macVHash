import ArgumentParser
import Foundation
import Logging

/// Entry point used by the executable. Maps ArgumentParser's usage-error exit code (64) to 2.
public enum VHashMain {
    public static func run(arguments: [String]? = nil) async -> Int32 {
        _ = silenceLibraryLogging
        do {
            var command = try VHashCommand.parseAsRoot(arguments)
            if var asyncCommand = command as? any AsyncParsableCommand {
                try await asyncCommand.run()
            } else {
                try command.run()
            }
            return 0
        } catch {
            let code = VHashCommand.exitCode(for: error)
            let message = VHashCommand.fullMessage(for: error)
            if !message.isEmpty {
                if code == .success { Console.writeStdout(message + "\n") } else { Console.writeStderr(message + "\n") }
            }
            return code == .validationFailure ? 2 : code.rawValue
        }
    }

    /// VideoHash logs every file at info level to stderr via swift-log; keep stderr for vhash's own
    /// messages unless `VHASH_DEBUG` is set. Must run before the library creates its loggers,
    /// and swift-log allows bootstrapping only once per process.
    private static let silenceLibraryLogging: Void = {
        if ProcessInfo.processInfo.environment["VHASH_DEBUG"] != nil { return }
        LoggingSystem.bootstrap { _ in SwiftLogNoOpLogHandler() }
    }()
}
