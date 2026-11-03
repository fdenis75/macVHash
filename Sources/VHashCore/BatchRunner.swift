import Foundation
import VideoHash

/// Progress snapshot delivered after each completed file.
public struct ProgressUpdate: Sendable, Equatable {
    public let done: Int
    public let total: Int
    public let failed: Int
    public let result: FileResult
    public let elapsed: Duration
}

/// Runs a provider over many files with a hard concurrency bound.
///
/// Per-file failures are captured in `FileResult.error` and never abort the batch.
/// On cancellation no new files are started and only completed results are returned.
public struct BatchRunner: Sendable {
    public let provider: any HashProviding
    public let algorithms: Set<HashAlgorithm>
    public let concurrency: Int

    public init(provider: any HashProviding, algorithms: Set<HashAlgorithm>, concurrency: Int) {
        self.provider = provider
        self.algorithms = algorithms
        self.concurrency = max(1, concurrency)
    }

    /// - Returns: Completed results in input order (not completion order).
    public func run(
        urls: [URL],
        onProgress: @escaping @Sendable (ProgressUpdate) -> Void = { _ in }
    ) async -> [FileResult] {
        let provider = provider
        let algorithms = algorithms
        let limit = min(concurrency, max(urls.count, 1))
        let clock = ContinuousClock()
        let start = clock.now
        var slots = [FileResult?](repeating: nil, count: urls.count)
        var done = 0
        var failed = 0

        await withTaskGroup(of: (Int, FileResult?).self) { group in
            var next = 0

            func launchNext() {
                guard next < urls.count, !Task.isCancelled else { return }
                let index = next
                let url = urls[index]
                next += 1
                group.addTask {
                    (index, await Self.process(url, provider: provider, algorithms: algorithms))
                }
            }

            for _ in 0..<limit { launchNext() }

            while let (index, result) = await group.next() {
                if let result {
                    slots[index] = result
                    done += 1
                    if !result.isSuccess { failed += 1 }
                    onProgress(ProgressUpdate(
                        done: done, total: urls.count, failed: failed,
                        result: result, elapsed: clock.now - start
                    ))
                }
                launchNext()
            }
        }
        return slots.compactMap { $0 }
    }

    private static func process(
        _ url: URL, provider: any HashProviding, algorithms: Set<HashAlgorithm>
    ) async -> FileResult? {
        do {
            let values = try await provider.hash(url: url, algorithms: algorithms)
            return FileResult(path: url.path, phash: values.phash, oshash: values.oshash, duration: values.duration)
        } catch is CancellationError {
            return nil
        } catch {
            if Task.isCancelled { return nil }
            return FileResult(path: url.path, error: describe(error))
        }
    }

    /// Short, actionable text without the repeated path (the path is its own output column).
    static func describe(_ error: any Error) -> String {
        guard let hashError = error as? HashError else {
            return "could not read video: \(error.localizedDescription)"
        }
        switch hashError {
        case .fileNotFound:
            return "file not found"
        case .invalidVideoFile(_, let reason):
            return "\(reason.prefix(1).lowercased())\(reason.dropFirst()) (not a readable video?)"
        case .frameExtractionFailed(let reason):
            return "frame extraction failed: \(reason)"
        case .processingFailed(let reason):
            return reason
        case .insufficientFrames(let expected, let actual):
            return "insufficient frames (expected \(expected), got \(actual)); video may be too short or corrupt"
        }
    }
}
