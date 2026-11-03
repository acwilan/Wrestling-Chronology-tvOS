import Foundation

enum CompanyID: String, Codable, CaseIterable, Identifiable, Sendable {
    case aew, ecw, njpw, nxt, roh, tna, wcw, wwe

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .aew: return "AEW"
        case .ecw: return "ECW"
        case .njpw: return "NJPW"
        case .nxt: return "NXT"
        case .roh: return "Ring of Honor"
        case .tna: return "TNA / Impact"
        case .wcw: return "WCW"
        case .wwe: return "WWF / WWE"
        }
    }

    var years: String {
        switch self {
        case .aew: return "2018–present"
        case .ecw: return "1992–2006"
        case .njpw: return "2002–present"
        case .nxt: return "2010–present"
        case .roh: return "2002–present"
        case .tna: return "2002–present"
        case .wcw: return "1983–2001"
        case .wwe: return "1985–present"
        }
    }
}

struct ManifestDocument: Codable, Sendable {
    let schemaVersion: Int
    let companies: [String: ManifestEntry]
}

struct ManifestEntry: Codable, Sendable, Equatable {
    let url: String
    let sha256: String
    let bytes: Int
    let revision: Int64
}

struct CataloguePack: Codable, Sendable {
    let schemaVersion: Int
    let company: String
    let revision: Int64
    let sources: SourceConfiguration
    let retiredSources: [String]?
    let catalogue: CatalogueData
}

struct CatalogueData: Codable, Sendable {
    let schemaVersion: Int?
    var episodes: [Episode]
    let eventCalendar: [EventMetadata]?
    let archiveItems: [String]?
    let playlists: [Playlist]?
    let showArtwork: [String: String]?
    let sourceAssignments: [String: String]?
    let historyMigrations: [String: String]?
}

struct EventMetadata: Codable, Sendable, Hashable {
    let name: String
    let date: String
    let category: String?
    let poster: String?
    let description: String?
}

struct Playlist: Codable, Sendable, Hashable {
    let id: String
    let name: String
    let enabled: Bool?
    let show: String?
}

struct Episode: Codable, Sendable, Hashable, Identifiable {
    let id: String
    let date: String
    let year: Int
    let show: String
    let title: String
    let description: String?
    let category: String?
    let duration: Double?
    let thumbnail: String?
    let poster: String?
    let part: Int?
    let listedParts: Int?
    let eventOrder: Int?
    let discoveredAt: Int64?
    let aliases: [String]?
    let sources: [EpisodeSource]

    var displayDate: String {
        guard let value = ISO8601DateFormatter.catalogueDate.date(from: date) else { return date }
        return value.formatted(date: .abbreviated, time: .omitted)
    }

    var runtimeText: String? {
        guard let duration, duration > 0 else { return nil }
        let totalMinutes = Int(duration.rounded()) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    var searchText: String {
        [title, show, date, description ?? "", aliases?.joined(separator: " ") ?? ""]
            .joined(separator: " ")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}

struct EpisodeSource: Codable, Sendable, Hashable, Identifiable {
    let type: String
    let url: String?
    let urls: [String]?
    let videoId: String?
    let videoIds: [String]?
    let channelId: String?
    let owner: String?
    let title: String?
    let label: String?
    let filename: String?
    let programme: String?
    let duration: Double?
    let bytes: Int64?
    let height: Int?
    let language: String?
    let audioLanguage: String?
    let creator: String?

    var id: String { sourceKey }

    var kind: SourceKind { SourceKind(rawValue: type) ?? .unknown }

    var sourceKey: String {
        switch kind {
        case .archive:
            return "archive:" + (urls ?? [url ?? ""]).joined(separator: "|")
        case .youtube:
            return "youtube:\(videoId ?? ""):\(channelId ?? "")"
        case .okru:
            return "okru:\(videoId ?? ""):\(owner ?? "")"
        case .dailymotion:
            let ids = videoIds ?? [videoId ?? ""]
            return "dailymotion:" + ids.joined(separator: "|") + ":\(owner ?? "")"
        case .unknown:
            return "unknown:\(type):\(url ?? videoId ?? "")"
        }
    }

    var displayLabel: String {
        if let label, !label.isEmpty { return label }
        switch kind {
        case .archive: return "Internet Archive"
        case .youtube: return "YouTube"
        case .okru: return "OK.ru"
        case .dailymotion: return "Dailymotion"
        case .unknown: return type
        }
    }

    var archiveURLs: [URL] {
        (urls ?? [url].compactMap { $0 }).compactMap(URL.init(string:))
    }

    /// A normal provider page that can be handed to the matching Apple TV app
    /// or another installed URL handler. This is intentionally not a stream
    /// resolver: unsupported providers stay outside the tvOS playback path.
    var externalURL: URL? {
        switch kind {
        case .youtube:
            guard let videoId, !videoId.isEmpty else { return nil }
            return URL(string: "https://www.youtube.com/watch?v=\(videoId)")
        case .dailymotion:
            guard let videoId = (videoIds ?? [videoId ?? ""]).first, !videoId.isEmpty else { return nil }
            return URL(string: "https://www.dailymotion.com/video/\(videoId)")
        case .okru:
            if let url, let parsed = URL(string: url), parsed.scheme == "https" { return parsed }
            guard let videoId, !videoId.isEmpty else { return nil }
            return URL(string: "https://ok.ru/video/\(videoId)")
        case .archive:
            return archiveURLs.first
        case .unknown:
            guard let url, let parsed = URL(string: url), parsed.scheme == "https" else { return nil }
            return parsed
        }
    }

    var externalActionTitle: String {
        switch kind {
        case .youtube: return "Open YouTube"
        case .dailymotion: return "Open Dailymotion"
        case .okru: return "Open OK.ru"
        case .archive: return "Open Internet Archive"
        case .unknown: return "Open Provider"
        }
    }
}

enum SourceKind: String, Codable, Sendable, CaseIterable {
    case archive, youtube, okru, dailymotion, unknown
}

struct SourceConfiguration: Codable, Sendable {
    let schemaVersion: Int
    let youtube: YouTubeConfiguration?
    let archive: ArchiveConfiguration?
    let dailymotion: DailymotionConfiguration?
    let okru: OKRUConfiguration?
}

struct YouTubeConfiguration: Codable, Sendable {
    let enabled: Bool?
    let channelId: String
    let playlists: [Playlist]?
    let videos: [ConfiguredVideo]?
}

struct ArchiveConfiguration: Codable, Sendable {
    let enabled: Bool?
    let collectionsPerScan: Int?
    let collections: [ArchiveCollection]
}

struct ArchiveCollection: Codable, Sendable, Hashable {
    let id: String
    let name: String?
    let enabled: Bool?
}

struct DailymotionConfiguration: Codable, Sendable {
    let enabled: Bool?
    let videos: [DailymotionVideo]?
}

struct DailymotionVideo: Codable, Sendable, Hashable {
    let id: String
    let owner: String
    let enabled: Bool?
}

struct OKRUConfiguration: Codable, Sendable {
    let enabled: Bool?
    let videos: [OKRUVideo]?
}

struct OKRUVideo: Codable, Sendable, Hashable {
    let id: String
    let owner: String
    let episodeId: String?
    let date: String?
    let show: String?
    let enabled: Bool?
}

struct ConfiguredVideo: Codable, Sendable, Hashable {
    let id: String
    let name: String?
    let enabled: Bool?
    let channelId: String
    let authorUrl: String?
    let date: String?
    let show: String?
    let title: String?
    let duration: Int?
    let description: String?
}

enum CatalogValidationError: LocalizedError, Equatable {
    case unsupportedManifestSchema(Int)
    case unsupportedPackSchema(Int)
    case wrongCompany(expected: String, actual: String)
    case invalidManifestEntry(String)
    case byteCount(expected: Int, actual: Int)
    case checksum(expected: String, actual: String)
    case staleRevision(Int64)
    case malformed(String)
    case duplicateEpisodeID(String)
    case invalidEpisode(String)
    case invalidSource(String)
    case noUsableCatalogue

    var errorDescription: String? {
        switch self {
        case .unsupportedManifestSchema(let value): return "Unsupported catalogue manifest schema \(value)."
        case .unsupportedPackSchema(let value): return "Unsupported catalogue pack schema \(value)."
        case .wrongCompany(let expected, let actual): return "Expected company \(expected), received \(actual)."
        case .invalidManifestEntry(let value): return "Invalid manifest entry: \(value)."
        case .byteCount(let expected, let actual): return "Catalogue size mismatch (expected \(expected), received \(actual))."
        case .checksum: return "Catalogue checksum mismatch; the working catalogue was kept."
        case .staleRevision(let value): return "Catalogue revision \(value) is not newer than the cached revision."
        case .malformed(let value): return "Malformed catalogue: \(value)."
        case .duplicateEpisodeID(let value): return "Duplicate episode ID: \(value)."
        case .invalidEpisode(let value): return "Invalid episode: \(value)."
        case .invalidSource(let value): return "Invalid source: \(value)."
        case .noUsableCatalogue: return "No usable catalogue is available offline."
        }
    }
}

extension ISO8601DateFormatter {
    static let catalogueDate: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()
}

extension String {
    var isValidCatalogueDate: Bool {
        guard self.count == 10 else { return false }
        return ISO8601DateFormatter.catalogueDate.date(from: self) != nil
    }
}
