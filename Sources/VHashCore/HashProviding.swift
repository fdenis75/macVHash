import AVFoundation
import Foundation
import VideoHash

/// Computes hashes for a single file. Tests inject fakes; production uses ``VideoHashProvider``.
public protocol HashProviding: Sendable {
    func hash(url: URL, algorithms: Set<HashAlgorithm>) async throws -> HashValues
}

/// Production provider backed by the VideoHash library.
///
/// Hashes are requested one by one so `oshash`-only runs never touch ffmpeg.
public struct VideoHashProvider: HashProviding {
    private let generator: VideoHashGenerator

    public init(ffmpegPath: String? = nil) {
        generator = VideoHashGenerator(configuration: HashConfiguration(ffmpegPath: ffmpegPath))
    }

    public func hash(url original: URL, algorithms: Set<HashAlgorithm>) async throws -> HashValues {
        // VideoHash sizes files with lstat-style attributes, which reports the link size for symlinks.
        let url = original.resolvingSymlinksInPath()
        var values = HashValues()
        if algorithms.contains(.oshash) {
            values.oshash = try await generator.generateOSHash(for: url)
        }
        if algorithms.contains(.phash) {
            values.phash = try await generator.generatePHash(for: url)
        }
        values.duration = await Self.duration(of: url)
        return values
    }

    /// Best-effort duration; `nil` when AVFoundation cannot read it.
    private static func duration(of url: URL) async -> Double? {
        guard let time = try? await AVURLAsset(url: url).load(.duration) else { return nil }
        let seconds = time.seconds
        return seconds.isFinite ? seconds : nil
    }
}
