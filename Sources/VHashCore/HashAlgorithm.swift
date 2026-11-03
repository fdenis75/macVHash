import ArgumentParser
import Foundation

/// A hash that `vhash` can compute.
public enum HashAlgorithm: String, CaseIterable, Sendable, Hashable {
    case phash
    case oshash
}

/// One `--hash` value: `phash`, `oshash`, `all`, or a comma-separated list of those.
public struct HashSelection: ExpressibleByArgument, Sendable, Equatable {
    public let algorithms: Set<HashAlgorithm>

    public init(algorithms: Set<HashAlgorithm>) {
        self.algorithms = algorithms
    }

    public init?(argument: String) {
        var result: Set<HashAlgorithm> = []
        let parts = argument.split(separator: ",", omittingEmptySubsequences: true)
        guard !parts.isEmpty else { return nil }
        for part in parts {
            switch part.trimmingCharacters(in: .whitespaces).lowercased() {
            case "all": result.formUnion(HashAlgorithm.allCases)
            case let name:
                guard let algorithm = HashAlgorithm(rawValue: name) else { return nil }
                result.insert(algorithm)
            }
        }
        self.algorithms = result
    }

    public static var allValueStrings: [String] { ["phash", "oshash", "all"] }
}
