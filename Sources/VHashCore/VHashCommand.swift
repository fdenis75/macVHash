import ArgumentParser
import Foundation

public struct ScanOptions: ParsableArguments {
    @Flag(name: [.short, .long], help: "Descend into subdirectories when an input is a directory.")
    public var recursive = false

    public init() {}
}

public struct HashOptions: ParsableArguments {
    @Option(
        name: [.customShort("H"), .long],
        help: ArgumentHelp(
            "Hash to compute: phash, oshash or all. Repeatable or comma-separated.",
            valueName: "algorithm"
        ),
        completion: .list(["phash", "oshash", "all"])
    )
    public var hash: [HashSelection] = []

    @Option(
        name: [.customShort("j"), .long],
        help: ArgumentHelp("Number of files hashed at the same time.", valueName: "n")
    )
    public var concurrency = 2

    @Option(
        name: .long,
        help: ArgumentHelp("Path to the ffmpeg executable (default: search PATH).", valueName: "path"),
        completion: .file()
    )
    public var ffmpegPath: String?

    public init() {}

    /// Requested algorithms; all of them when `--hash` is not given.
    public var algorithms: Set<HashAlgorithm> {
        hash.isEmpty ? Set(HashAlgorithm.allCases) : hash.reduce(into: []) { $0.formUnion($1.algorithms) }
    }
}

public struct OutputOptions: ParsableArguments {
    @Option(name: [.short, .long], help: "Output format: table, csv or json. Inferred from the -o extension when omitted.")
    public var format: OutputFormat?

    @Option(
        name: [.short, .long],
        help: ArgumentHelp("Write results to this file instead of stdout.", valueName: "file"),
        completion: .file()
    )
    public var output: String?

    @Flag(name: .long, help: "Overwrite the output file if it exists.")
    public var force = false

    public init() {}
}

public struct LoggingOptions: ParsableArguments {
    @Flag(name: [.short, .long], help: "Suppress progress and warnings (errors are still printed).")
    public var quiet = false

    @Flag(name: [.short, .long], help: "Print one line per file on stderr as it completes.")
    public var verbose = false

    public init() {}
}

public struct VHashCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "vhash",
        abstract: "Compute perceptual (phash) and OpenSubtitles (oshash) hashes for video files.",
        usage: """
            vhash [<options>] <path> ...
            vhash [<options>] -
            """,
        discussion: """
            Each <path> is a video file or a directory. Directories are scanned for common \
            video extensions (non-recursively unless -r is given). Explicitly named files are \
            always hashed. Use '-' to read newline-separated paths from stdin, and '--' to \
            stop option parsing (for paths starting with a dash).

            phash needs ffmpeg (brew install ffmpeg). oshash does not, and needs files of at \
            least 128 KiB.

            Results go to stdout (or -o FILE); progress, warnings and errors go to stderr.

            EXAMPLES:
              vhash movie.mp4
              vhash -r ~/Movies --hash oshash -j 4
              vhash -r ~/Movies -f csv -o hashes.csv
              find . -name '*.mkv' | vhash - -f json

            EXIT CODES:
              0    every file hashed
              1    some files failed (results for the others are still printed)
              2    usage or fatal error
              130  interrupted (partial results are printed)
            """,
        version: VHashInfo.version
    )

    @Argument(
        help: ArgumentHelp("Video files or directories ('-' reads paths from stdin).", valueName: "path"),
        completion: .file()
    )
    public var inputs: [String] = []

    @OptionGroup(title: "Input")
    public var scan: ScanOptions

    @OptionGroup(title: "Hashing")
    public var hashing: HashOptions

    @OptionGroup(title: "Output")
    public var output: OutputOptions

    @OptionGroup(title: "Logging")
    public var logging: LoggingOptions

    public init() {}

    public mutating func validate() throws {
        guard !inputs.isEmpty else {
            throw ValidationError("Provide at least one video file or directory (or '-' to read paths from stdin).")
        }
        guard hashing.concurrency >= 1 else {
            throw ValidationError("--concurrency must be at least 1 (got \(hashing.concurrency)).")
        }
        guard !(logging.quiet && logging.verbose) else {
            throw ValidationError("--quiet and --verbose cannot be used together.")
        }
        if output.force && output.output == nil {
            throw ValidationError("--force only makes sense together with -o/--output.")
        }
    }

    public mutating func run() async throws {
        do {
            let code = try await execute()
            if code != 0 { throw ExitCode(code) }
        } catch let error as VHashError {
            Console.writeStderr("vhash: error: \(error.message)\n")
            throw ExitCode(2)
        }
    }

    // MARK: Execution

    private func execute() async throws -> Int32 {
        let algorithms = hashing.algorithms
        let quiet = logging.quiet
        let format = OutputFormat.infer(explicit: output.format, outputPath: output.output)

        // Fail fast, before any expensive work.
        if let outputPath = output.output {
            try OutputWriter.preflight(path: outputPath, force: output.force)
        }
        var ffmpegPath: String?
        if algorithms.contains(.phash) {
            ffmpegPath = try FFmpegLocator().locate(override: hashing.ffmpegPath)
        }

        var paths = inputs
        if paths.contains("-") {
            let fromStdin = await Self.readStdinPaths()
            paths = paths.filter { $0 != "-" } + fromStdin
        }
        let scanned = try FileScanner(recursive: scan.recursive).scan(inputs: paths)
        if !quiet { scanned.warnings.forEach { Console.writeStderr("vhash: warning: \($0)\n") } }

        let progressEnabled = !quiet && Console.stderrIsTTY
        let renderer = ProgressRenderer(
            useColor: Console.colorEnabled(), width: Console.terminalWidth()
        )
        let verbose = logging.verbose
        let runner = BatchRunner(
            provider: VideoHashProvider(ffmpegPath: ffmpegPath),
            algorithms: algorithms,
            concurrency: hashing.concurrency
        )
        let urls = scanned.files

        let work = Task {
            await runner.run(urls: urls) { update in
                var text = ""
                if progressEnabled { text += ProgressRenderer.clearLine }
                if verbose { text += Self.verboseLine(for: update) }
                if progressEnabled { text += renderer.line(for: update) }
                if !text.isEmpty { Console.writeStderr(text) }
            }
        }
        let interrupt = InterruptWatcher { work.cancel() }
        let results = await work.value
        let interrupted = interrupt.finish()
        if progressEnabled { Console.writeStderr(ProgressRenderer.clearLine) }

        for failure in results where !failure.isSuccess {
            Console.writeStderr("vhash: error: \(failure.path): \(failure.error ?? "unknown error")\n")
        }

        if !(interrupted && results.isEmpty) {
            let text = try format.render(results, algorithms: algorithms)
            if let outputPath = output.output {
                try OutputWriter.write(text, to: outputPath, force: output.force)
                if !quiet { Console.writeStderr("vhash: wrote \(results.count) result(s) to \(outputPath)\n") }
            } else {
                Console.writeStdout(text)
            }
        }

        let failed = results.filter { !$0.isSuccess }.count
        if interrupted {
            Console.writeStderr("vhash: interrupted after \(results.count) of \(urls.count) file(s)\n")
            return 130
        }
        if !quiet { Console.writeStderr("vhash: \(results.count - failed) of \(urls.count) file(s) hashed, \(failed) failed\n") }
        return failed > 0 ? 1 : 0
    }

    private static func verboseLine(for update: ProgressUpdate) -> String {
        let result = update.result
        if let error = result.error { return "FAIL \(result.path): \(error)\n" }
        let parts = [result.phash.map { "phash=\($0)" }, result.oshash.map { "oshash=\($0)" }].compactMap { $0 }
        return "ok   \(result.path) \(parts.joined(separator: " "))\n"
    }

    private static func readStdinPaths() async -> [String] {
        await Task.detached {
            var lines: [String] = []
            while let line = readLine() {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { lines.append(trimmed) }
            }
            return lines
        }.value
    }
}
