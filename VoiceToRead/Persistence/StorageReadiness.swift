import Foundation

struct StorageReadiness {
    static let minimumBytes: Int64 = 64 * 1024 * 1024
    let availableBytes: Int64?

    var ready: Bool { availableBytes.map { $0 >= Self.minimumBytes } ?? false }
    var description: String {
        guard availableBytes != nil else { return "Storage capacity could not be checked." }
        return ready ? "Storage available" : "Less than 64 MB free. Free space before starting a session."
    }

    static func check(at url: URL?) -> Self {
        guard let url else { return Self(availableBytes: nil) }
        let folder = url.deletingLastPathComponent()
        let capacity = try? folder.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage
        return Self(availableBytes: capacity)
    }
}

enum StorageFailure: LocalizedError {
    case lowCapacity
    var errorDescription: String? { "Free at least 64 MB before saving a conference session." }
}
