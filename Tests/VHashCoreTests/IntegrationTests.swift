import Foundation
import Testing
@testable import VHashCore

@Suite("Integration (real VideoHash, oshash only)")
struct IntegrationTests {
    @Test("oshash of a zero-filled 256 KiB file equals its size")
    func oshash() async throws {
        let dir = try TempDir(); defer { dir.cleanup() }
        let file = try dir.file("zeros.mp4", bytes: 262_144)
        let values = try await VideoHashProvider().hash(url: file, algorithms: [.oshash])
        #expect(values.oshash == "0000000000040000")
        #expect(values.phash == nil)
    }

    @Test("files below 128 KiB fail per-file without aborting the batch")
    func tooSmall() async throws {
        let dir = try TempDir(); defer { dir.cleanup() }
        let big = try dir.file("big.mp4", bytes: 200_000)
        let small = try dir.file("small.mp4", bytes: 100)
        let runner = BatchRunner(provider: VideoHashProvider(), algorithms: [.oshash], concurrency: 2)
        let results = await runner.run(urls: [big, small])
        #expect(results.map(\.isSuccess) == [true, false])
        #expect(results[1].error?.contains("too small") == true)
    }

    @Test("end to end: scan, hash, render json to a file")
    func endToEnd() async throws {
        let dir = try TempDir(); defer { dir.cleanup() }
        try dir.file("one.mp4", bytes: 200_000)
        let out = dir.url.appendingPathComponent("res.json").path
        let code = await VHashMain.run(arguments: [dir.url.path, "-H", "oshash", "-o", out, "-q"])
        #expect(code == 0)
        let data = try Data(contentsOf: URL(fileURLWithPath: out))
        let array = try #require(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        #expect(array.count == 1)
        #expect(array[0]["oshash"] is String)
        #expect(await VHashMain.run(arguments: [dir.url.path, "-H", "oshash", "-o", out, "-q"]) == 2)  // exists, no --force
    }
}

@Suite("Symlinks")
struct SymlinkTests {
    @Test("oshash follows symlinks to the real file")
    func symlink() async throws {
        let dir = try TempDir(); defer { dir.cleanup() }
        let real = try dir.file("real.mp4", bytes: 262_144)
        let link = dir.url.appendingPathComponent("link.mp4")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
        let values = try await VideoHashProvider().hash(url: link, algorithms: [.oshash])
        #expect(values.oshash == "0000000000040000")
    }
}
