import Foundation

/// Hash values produced for one file. Values that were not requested are `nil`.
public struct HashValues: Sendable, Equatable {
    public var phash: String?
    public var oshash: String?
    public var duration: Double?

    public init(phash: String? = nil, oshash: String? = nil, duration: Double? = nil) {
        self.phash = phash
        self.oshash = oshash
        self.duration = duration
    }
}

/// Outcome for one input file; `error == nil` means success.
public struct FileResult: Sendable, Equatable, Encodable {
    public let path: String
    public let phash: String?
    public let oshash: String?
    public let duration: Double?
    public let error: String?

    public var isSuccess: Bool { error == nil }

    public init(path: String, phash: String? = nil, oshash: String? = nil, duration: Double? = nil, error: String? = nil) {
        self.path = path
        self.phash = phash
        self.oshash = oshash
        self.duration = duration
        self.error = error
    }

    private enum CodingKeys: String, CodingKey {
        case path, phash, oshash, duration, error
    }

    /// Encodes every key, writing explicit `null` for absent values so the schema is stable.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(path, forKey: .path)
        try container.encode(phash, forKey: .phash)
        try container.encode(oshash, forKey: .oshash)
        try container.encode(duration, forKey: .duration)
        try container.encode(error, forKey: .error)
    }
}
