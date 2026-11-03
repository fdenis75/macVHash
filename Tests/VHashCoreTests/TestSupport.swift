import Foundation
@testable import VHashCore

/// A throwaway directory removed when the value is released via `cleanup()`.
struct TempDir {
    let url: URL

    init() throws {
        url = try FileManager.default.url(
            for: .itemReplacementDirectory, in: .userDomainMask,
            appropriateFor: URL(fileURLWithPath: NSTemporaryDirectory()), create: true
        ).resolvingSymlinksInPath()
    }

    @discardableResult
    func file(_ relative: String, bytes: Int = 4) throws -> URL {
        let target = url.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(count: bytes).write(to: target)
        return target
    }

    func cleanup() { try? FileManager.default.removeItem(at: url) }
}

/// Fake hasher: records peak concurrency, fails for paths containing "bad".
actor FakeHasher: HashProviding {
    private var inFlight = 0
    private(set) var peak = 0
    private(set) var calls: [String] = []
    private let delay: Duration

    init(delay: Duration = .milliseconds(20)) { self.delay = delay }

    func hash(url: URL, algorithms: Set<HashAlgorithm>) async throws -> HashValues {
        inFlight += 1
        peak = max(peak, inFlight)
        calls.append(url.lastPathComponent)
        defer { inFlight -= 1 }
        try await Task.sleep(for: delay)
        if url.lastPathComponent.contains("bad") { throw FakeError.boom }
        return HashValues(
            phash: algorithms.contains(.phash) ? "p-" + url.lastPathComponent : nil,
            oshash: algorithms.contains(.oshash) ? "o-" + url.lastPathComponent : nil,
            duration: 1.5
        )
    }
}

enum FakeError: Error, LocalizedError {
    case boom
    var errorDescription: String? { "boom" }
}
