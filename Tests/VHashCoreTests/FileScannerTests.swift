import Foundation
import Testing
@testable import VHashCore

@Suite("FileScanner")
struct FileScannerTests {
    @Test("non-recursive scan lists only top-level videos, sorted, case-insensitive, skipping hidden")
    func nonRecursive() throws {
        let dir = try TempDir(); defer { dir.cleanup() }
        try dir.file("b.mp4"); try dir.file("a.MKV"); try dir.file("notes.txt")
        try dir.file(".hidden.mp4"); try dir.file("sub/c.mp4")

        let out = try FileScanner().scan(inputs: [dir.url.path])
        #expect(out.files.map(\.lastPathComponent) == ["a.MKV", "b.mp4"])
    }

    @Test("recursive scan descends but skips hidden directories")
    func recursive() throws {
        let dir = try TempDir(); defer { dir.cleanup() }
        try dir.file("a.mp4"); try dir.file("sub/deep/c.webm"); try dir.file(".secret/d.mp4")

        let out = try FileScanner(recursive: true).scan(inputs: [dir.url.path])
        #expect(out.files.map(\.lastPathComponent) == ["a.mp4", "c.webm"])
    }

    @Test("every supported extension is recognised")
    func extensions() throws {
        let dir = try TempDir(); defer { dir.cleanup() }
        for ext in FileScanner.videoExtensions { try dir.file("v.\(ext)") }
        #expect(try FileScanner().scan(inputs: [dir.url.path]).files.count == FileScanner.videoExtensions.count)
    }

    @Test("explicitly named files are accepted regardless of extension")
    func explicitFile() throws {
        let dir = try TempDir(); defer { dir.cleanup() }
        let odd = try dir.file("movie.bin")
        #expect(try FileScanner().scan(inputs: [odd.path]).files.count == 1)
    }

    @Test("duplicates across inputs collapse and order is deterministic")
    func dedupe() throws {
        let dir = try TempDir(); defer { dir.cleanup() }
        let b = try dir.file("b.mp4"); try dir.file("a.mp4")
        let out = try FileScanner().scan(inputs: [b.path, dir.url.path, b.path])
        #expect(out.files.map(\.lastPathComponent) == ["a.mp4", "b.mp4"])
    }

    @Test("missing paths are reported together")
    func missing() throws {
        let dir = try TempDir(); defer { dir.cleanup() }
        let ok = try dir.file("a.mp4")
        #expect(throws: VHashError.pathsNotFound(["/nope/1", "/nope/2"])) {
            try FileScanner().scan(inputs: ["/nope/1", ok.path, "/nope/2"])
        }
    }

    @Test("an input yielding no videos is an error; a partial miss is a warning")
    func noVideos() throws {
        let dir = try TempDir(); defer { dir.cleanup() }
        try dir.file("readme.txt")
        #expect(throws: VHashError.noVideosFound) { try FileScanner().scan(inputs: [dir.url.path]) }

        let empty = try TempDir(); defer { empty.cleanup() }
        let video = try dir.file("a.mp4")
        let out = try FileScanner().scan(inputs: [empty.url.path, video.path])
        #expect(out.files.count == 1)
        #expect(out.warnings.count == 1)
    }
}
