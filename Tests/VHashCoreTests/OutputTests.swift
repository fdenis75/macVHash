import Foundation
import Testing
@testable import VHashCore

@Suite("Output format and writing")
struct OutputTests {
    @Test("format inference: explicit wins, then extension, then table")
    func inference() {
        #expect(OutputFormat.infer(explicit: nil, outputPath: nil) == .table)
        #expect(OutputFormat.infer(explicit: nil, outputPath: "x.CSV") == .csv)
        #expect(OutputFormat.infer(explicit: nil, outputPath: "dir/x.json") == .json)
        #expect(OutputFormat.infer(explicit: nil, outputPath: "x.txt") == .table)
        #expect(OutputFormat.infer(explicit: .json, outputPath: "x.csv") == .json)
    }

    @Test("writes a new file and refuses to overwrite without force")
    func overwriteProtection() throws {
        let dir = try TempDir(); defer { dir.cleanup() }
        let path = dir.url.appendingPathComponent("out.csv").path
        try OutputWriter.write("one\n", to: path, force: false)
        #expect(try String(contentsOfFile: path, encoding: .utf8) == "one\n")

        #expect(throws: VHashError.outputExists(path)) { try OutputWriter.write("two\n", to: path, force: false) }
        #expect(try String(contentsOfFile: path, encoding: .utf8) == "one\n")

        try OutputWriter.write("two\n", to: path, force: true)
        #expect(try String(contentsOfFile: path, encoding: .utf8) == "two\n")
        // Atomic write leaves no stray temp files behind.
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.url.path) == ["out.csv"])
    }

    @Test("missing directory and directory targets give clear errors")
    func badTargets() throws {
        let dir = try TempDir(); defer { dir.cleanup() }
        let missing = dir.url.appendingPathComponent("nope/out.json").path
        #expect(throws: VHashError.outputDirectoryMissing(dir.url.appendingPathComponent("nope").path)) {
            try OutputWriter.preflight(path: missing, force: false)
        }
        #expect(throws: VHashError.outputIsDirectory(dir.url.path)) {
            try OutputWriter.preflight(path: dir.url.path, force: true)
        }
    }

    @Test("error messages are actionable")
    func messages() {
        #expect(VHashError.ffmpegNotFound(requested: nil).message.contains("brew install ffmpeg"))
        #expect(VHashError.ffmpegNotFound(requested: nil).message.contains("--hash oshash"))
        #expect(VHashError.outputExists("x").message.contains("--force"))
        #expect(VHashError.noVideosFound.message.contains("--recursive"))
    }

    @Test("ffmpeg locator honours override, PATH and common paths")
    func ffmpeg() throws {
        let present: Set<String> = ["/a/bin/ffmpeg", "/opt/homebrew/bin/ffmpeg"]
        let isExec: @Sendable (String) -> Bool = { present.contains($0) }
        let onPath = FFmpegLocator(environment: ["PATH": "/x:/a/bin"], isExecutable: isExec)
        #expect(try onPath.locate() == "/a/bin/ffmpeg")
        #expect(try onPath.locate(override: "/opt/homebrew/bin/ffmpeg") == "/opt/homebrew/bin/ffmpeg")
        #expect(throws: VHashError.ffmpegNotFound(requested: "/nope/ffmpeg")) { try onPath.locate(override: "/nope/ffmpeg") }

        let fallback = FFmpegLocator(environment: ["PATH": ""], isExecutable: isExec)
        #expect(try fallback.locate() == "/opt/homebrew/bin/ffmpeg")
        let none = FFmpegLocator(environment: [:], isExecutable: { _ in false })
        #expect(throws: VHashError.ffmpegNotFound(requested: nil)) { try none.locate() }
    }
}
