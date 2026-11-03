import Foundation
import Testing
@testable import VHashCore

@Suite("BatchRunner")
struct BatchRunnerTests {
    func urls(_ names: [String]) -> [URL] { names.map { URL(fileURLWithPath: "/v/\($0)") } }

    @Test("never exceeds the concurrency bound but does use it")
    func bound() async {
        let hasher = FakeHasher()
        let runner = BatchRunner(provider: hasher, algorithms: [.oshash], concurrency: 3)
        let results = await runner.run(urls: urls((0..<12).map { "f\($0).mp4" }))
        #expect(results.count == 12)
        #expect(await hasher.peak == 3)
    }

    @Test("concurrency 1 is strictly serial")
    func serial() async {
        let hasher = FakeHasher(delay: .milliseconds(5))
        _ = await BatchRunner(provider: hasher, algorithms: [.phash], concurrency: 1)
            .run(urls: urls((0..<5).map { "f\($0).mp4" }))
        #expect(await hasher.peak == 1)
    }

    @Test("failures are isolated and results keep input order")
    func failures() async {
        let names = ["a.mp4", "bad1.mp4", "c.mp4", "bad2.mp4", "e.mp4"]
        let runner = BatchRunner(provider: FakeHasher(), algorithms: [.phash, .oshash], concurrency: 4)
        let results = await runner.run(urls: urls(names))
        #expect(results.map(\.path) == names.map { "/v/\($0)" })
        #expect(results.map(\.isSuccess) == [true, false, true, false, true])
        #expect(results[1].error == "could not read video: boom")
        #expect(results[0].phash == "p-a.mp4" && results[0].oshash == "o-a.mp4")
    }

    @Test("only requested hashes are passed to the provider")
    func requested() async {
        let results = await BatchRunner(provider: FakeHasher(), algorithms: [.oshash], concurrency: 2)
            .run(urls: urls(["a.mp4"]))
        #expect(results[0].phash == nil)
        #expect(results[0].oshash == "o-a.mp4")
    }

    @Test("progress reports every file with a running failure count")
    func progress() async {
        let box = ProgressBox()
        let names = ["a.mp4", "bad.mp4", "c.mp4"]
        _ = await BatchRunner(provider: FakeHasher(), algorithms: [.oshash], concurrency: 1)
            .run(urls: urls(names)) { box.add($0) }
        let updates = box.updates
        #expect(updates.map(\.done) == [1, 2, 3])
        #expect(updates.allSatisfy { $0.total == 3 })
        #expect(updates.last?.failed == 1)
    }

    @Test("cancellation stops launching new work and returns only completed results")
    func cancellation() async {
        let hasher = FakeHasher(delay: .milliseconds(100))
        let runner = BatchRunner(provider: hasher, algorithms: [.oshash], concurrency: 1)
        let list = urls((0..<20).map { "f\($0).mp4" })
        let task = Task { await runner.run(urls: list) }
        try? await Task.sleep(for: .milliseconds(150))
        task.cancel()
        let results = await task.value
        #expect(results.count < 20)
        #expect(await hasher.calls.count < 20)
    }

    @Test("progress renderer fits width, shows failures and omits colour without a TTY")
    func renderer() {
        let update = ProgressUpdate(
            done: 2, total: 10, failed: 1,
            result: FileResult(path: "/very/long/dir/some-long-file-name.mp4"), elapsed: .seconds(4)
        )
        let plain = ProgressRenderer(useColor: false, width: 60).line(for: update)
        #expect(plain.hasPrefix("[2/10 20%] 1 failed ETA 0:16"))
        #expect(plain.count <= 60)
        #expect(!plain.contains("\u{1B}"))
        #expect(ProgressRenderer(useColor: true, width: 60).line(for: update).contains("\u{1B}[31m"))
        #expect(!Console.colorEnabled(isTTY: false, environment: [:]))
        #expect(!Console.colorEnabled(isTTY: true, environment: ["NO_COLOR": "1"]))
        #expect(Console.colorEnabled(isTTY: true, environment: ["TERM": "xterm"]))
    }
}

final class ProgressBox: @unchecked Sendable {  // Guarded by `lock`; test-only collector.
    private let lock = NSLock()
    private var storage: [ProgressUpdate] = []
    func add(_ update: ProgressUpdate) { lock.withLock { storage.append(update) } }
    var updates: [ProgressUpdate] { lock.withLock { storage } }
}
