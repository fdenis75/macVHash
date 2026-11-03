import Darwin
import Foundation

/// Terminal capabilities and stderr/stdout helpers. Stdout is reserved for results.
public enum Console {
    public static var stderrIsTTY: Bool { isatty(STDERR_FILENO) != 0 }
    public static var stdoutIsTTY: Bool { isatty(STDOUT_FILENO) != 0 }

    /// ANSI colour is used only on a TTY, when NO_COLOR is unset/empty and TERM is not "dumb".
    public static func colorEnabled(
        isTTY: Bool = stderrIsTTY,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        guard isTTY else { return false }
        if let noColor = environment["NO_COLOR"], !noColor.isEmpty { return false }
        return environment["TERM"] != "dumb"
    }

    public static func terminalWidth() -> Int {
        var size = winsize()
        if ioctl(STDERR_FILENO, TIOCGWINSZ, &size) == 0, size.ws_col > 0 { return Int(size.ws_col) }
        return 80
    }

    public static func writeStderr(_ text: String) {
        FileHandle.standardError.write(Data(text.utf8))
    }

    public static func writeStdout(_ text: String) {
        FileHandle.standardOutput.write(Data(text.utf8))
    }
}
