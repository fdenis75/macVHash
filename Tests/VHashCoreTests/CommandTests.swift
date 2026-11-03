import ArgumentParser
import Foundation
import Testing
@testable import VHashCore

@Suite("Argument parsing and validation")
struct CommandTests {
    func parse(_ args: [String]) throws -> VHashCommand {
        try #require(try VHashCommand.parseAsRoot(args) as? VHashCommand)
    }

    func message(_ args: [String]) -> String {
        do { _ = try VHashCommand.parseAsRoot(args); return "" } catch { return VHashCommand.message(for: error) }
    }

    @Test("defaults")
    func defaults() throws {
        let command = try parse(["a.mp4"])
        #expect(command.hashing.algorithms == [.phash, .oshash])
        #expect(command.hashing.concurrency == 2)
        #expect(!command.scan.recursive && !command.output.force)
        #expect(command.output.format == nil)
    }

    @Test("hash selection: repeated and comma-separated values are unioned")
    func hashSelection() throws {
        #expect(try parse(["-H", "oshash", "a"]).hashing.algorithms == [.oshash])
        #expect(try parse(["--hash", "phash", "--hash", "oshash", "a"]).hashing.algorithms == [.phash, .oshash])
        #expect(try parse(["-H", "phash,oshash", "a"]).hashing.algorithms == [.phash, .oshash])
        #expect(try parse(["-H", "all", "a"]).hashing.algorithms == [.phash, .oshash])
        #expect(message(["-H", "md5", "a"]).contains("md5"))
    }

    @Test("concurrency must be at least 1")
    func concurrency() throws {
        #expect(try parse(["-j", "8", "a"]).hashing.concurrency == 8)
        #expect(message(["-j", "0", "a"]).contains("--concurrency must be at least 1"))
        #expect(message(["--concurrency=-3", "a"]).contains("at least 1"))
        #expect(!message(["-j", "abc", "a"]).isEmpty)
    }

    @Test("inputs, conflicting flags and --force without -o are rejected")
    func validation() {
        #expect(message([]).contains("at least one"))
        #expect(message(["-q", "-v", "a"]).contains("cannot be used together"))
        #expect(message(["--force", "a"]).contains("-o/--output"))
        #expect(message(["-f", "xml", "a"]).contains("xml"))
    }

    @Test("'-' and '--' are treated as positional paths")
    func positional() throws {
        #expect(try parse(["-"]).inputs == ["-"])
        #expect(try parse(["-r", "--", "-weird.mp4", "b"]).inputs == ["-weird.mp4", "b"])
    }

    @Test("usage errors map to exit code 2; help and version succeed")
    func exitCodes() async {
        #expect(await VHashMain.run(arguments: ["-j", "0", "x"]) == 2)
        #expect(await VHashMain.run(arguments: []) == 2)
        #expect(await VHashMain.run(arguments: ["--version"]) == 0)
        #expect(await VHashMain.run(arguments: ["--help"]) == 0)
        #expect(await VHashMain.run(arguments: ["/definitely/not/here.mp4", "-H", "oshash"]) == 2)
    }
}
