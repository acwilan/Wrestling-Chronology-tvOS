import Foundation
import AVFoundation

enum ProviderCapability: Sendable {
    case archive
    case dailymotion
    case okru
    case youtube
}

struct PlaybackPlan: Sendable {
    let source: EpisodeSource
    let urls: [URL]
    let provider: SourceKind
    let mimeType: String?
}

enum PlaybackError: LocalizedError, Equatable {
    case unsupportedProvider(SourceKind)
    case invalidSource(String)
    case noEligibleSource
    case unavailable(String)
    case assetNotPlayable

    var errorDescription: String? {
        switch self {
        case .unsupportedProvider(let provider): return "\(provider.rawValue.capitalized) playback is not supported on tvOS in this build."
        case .invalidSource(let value): return "The selected source is invalid: \(value)."
        case .noEligibleSource: return "No compatible source is available for this episode."
        case .unavailable(let value): return value
        case .assetNotPlayable: return "This recording uses a video format that AVPlayer cannot play on this Apple TV."
        }
    }
}

protocol SourceResolverProtocol: Sendable {
    func resolve(_ source: EpisodeSource) async throws -> PlaybackPlan
}

struct SourceResolver: SourceResolverProtocol, Sendable {
    let enabled: Set<ProviderCapability>

    init(enabled: Set<ProviderCapability> = [.archive]) {
        self.enabled = enabled
    }

    func resolve(_ source: EpisodeSource) async throws -> PlaybackPlan {
        switch source.kind {
        case .archive:
            guard enabled.contains(.archive), !source.archiveURLs.isEmpty,
                  source.archiveURLs.allSatisfy(Self.isArchiveURL) else {
                throw PlaybackError.invalidSource(source.sourceKey)
            }
            return PlaybackPlan(source: source, urls: source.archiveURLs, provider: .archive, mimeType: "video/mp4")
        case .dailymotion:
            guard enabled.contains(.dailymotion) else { throw PlaybackError.unsupportedProvider(.dailymotion) }
            throw PlaybackError.unavailable("Dailymotion metadata resolution is not enabled in this MVP build.")
        case .okru:
            guard enabled.contains(.okru) else { throw PlaybackError.unsupportedProvider(.okru) }
            throw PlaybackError.unavailable("OK.ru metadata resolution is not enabled in this MVP build.")
        case .youtube:
            throw PlaybackError.unsupportedProvider(.youtube)
        case .unknown:
            throw PlaybackError.unsupportedProvider(.unknown)
        }
    }

    static func isArchiveURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https" && url.host?.lowercased() == "archive.org" && url.path.hasPrefix("/download/") && url.user == nil && url.fragment == nil
    }
}

struct DailymotionMetadataParser: Sendable {
    struct Result: Sendable, Equatable {
        let owner: String
        let hlsURL: URL
    }

    func parse(data: Data, expectedOwner: String) throws -> Result {
        struct Metadata: Decodable {
            struct Owner: Decodable { let username: String }
            struct Quality: Decodable { let type: String?; let url: String? }
            let owner: Owner
            let qualities: [String: [Quality]]
        }
        do {
            let decoded = try JSONDecoder().decode(Metadata.self, from: data)
            guard decoded.owner.username == expectedOwner else { throw PlaybackError.unavailable("Dailymotion uploader identity changed.") }
            let candidates = decoded.qualities.values.flatMap { $0 }.compactMap { quality -> URL? in
                guard quality.type?.localizedCaseInsensitiveContains("mpegurl") == true,
                      let value = quality.url, let url = URL(string: value), url.scheme == "https" else { return nil }
                return url
            }
            guard let selected = candidates.first else { throw PlaybackError.unavailable("No public Dailymotion HLS stream is available.") }
            return Result(owner: decoded.owner.username, hlsURL: selected)
        } catch let error as PlaybackError { throw error }
        catch { throw PlaybackError.unavailable("Dailymotion metadata was malformed.") }
    }
}

enum OKRUHostValidator {
    static func isMediaURL(_ value: String) -> Bool {
        guard let url = URL(string: value), url.scheme == "https", url.user == nil,
              let host = url.host?.lowercased() else { return false }
        return host == "okcdn.ru" || host.hasSuffix(".okcdn.ru") || host.hasSuffix(".vkuser.net") || host.hasSuffix(".mycdn.me")
    }
}
