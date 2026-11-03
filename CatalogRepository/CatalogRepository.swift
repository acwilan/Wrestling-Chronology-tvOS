import Foundation
import CryptoKit

protocol CatalogHTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionCatalogHTTPClient: CatalogHTTPClient, @unchecked Sendable {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, http)
    }
}

struct RefreshStatus: Sendable, Equatable {
    enum Kind: String, Sendable {
        case bundled, cached, refreshed, unchanged, failed
    }

    let company: CompanyID
    let kind: Kind
    let revision: Int64?
    let message: String
}

struct CatalogLibrary: Sendable {
    let company: CompanyID
    let revision: Int64
    let episodes: [Episode]
    let loadedFromCache: Bool
}

actor CatalogRepository {
    static let manifestURL = URL(string: "https://raw.githubusercontent.com/deklol/Wrestling-Chronology/main/catalogue/manifest.json")!
    static let supportedSchemaVersion = 1
    static let maximumPackBytes = 64 * 1024 * 1024

    private let client: CatalogHTTPClient
    private let fileManager: FileManager
    private let cacheDirectory: URL
    private let bundle: Bundle
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private var loaded: [CompanyID: CataloguePack] = [:]
    private var lastStatus: RefreshStatus?

    init(
        client: CatalogHTTPClient = URLSessionCatalogHTTPClient(),
        fileManager: FileManager = .default,
        cacheDirectory: URL? = nil,
        bundle: Bundle = .main
    ) {
        self.client = client
        self.fileManager = fileManager
        self.bundle = bundle
        // Catalogue packs are re-downloadable and belong in Caches. This is
        // writable on tvOS and avoids treating a refresh as durable user data.
        // Watch history remains in Application Support via HistoryStore.
        self.cacheDirectory = cacheDirectory ?? fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WrestlingChronology", isDirectory: true)
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.sortedKeys]
    }

    func library(for company: CompanyID) async throws -> CatalogLibrary {
        if let pack = loaded[company] {
            return makeLibrary(pack, loadedFromCache: true)
        }

        if let cached = try readCachedPack(company) {
            try validate(cached, company: company)
            loaded[company] = cached
            return makeLibrary(cached, loadedFromCache: true)
        }

        if let fixture = try readFixture(company) {
            try validate(fixture, company: company)
            loaded[company] = fixture
            lastStatus = RefreshStatus(company: company, kind: .bundled, revision: fixture.revision, message: "Bundled fixture loaded")
            return makeLibrary(fixture, loadedFromCache: false)
        }

        throw CatalogValidationError.noUsableCatalogue
    }

    func refresh(company: CompanyID, force: Bool = false) async -> RefreshStatus {
        do {
            let manifest = try await fetchManifest()
            guard let entry = manifest.companies[company.rawValue] else {
                throw CatalogValidationError.invalidManifestEntry(company.rawValue)
            }
            guard let packURL = URL(string: entry.url), isSafeHTTPS(packURL) else {
                throw CatalogValidationError.invalidManifestEntry(entry.url)
            }

            let current = loaded[company] ?? (try? readCachedPack(company))
            if !force, let current, current.revision >= entry.revision {
                loaded[company] = current
                let result = RefreshStatus(company: company, kind: .unchanged, revision: current.revision, message: "Catalogue is already current")
                lastStatus = result
                return result
            }

            var request = URLRequest(url: packURL)
            request.timeoutInterval = 30
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, response) = try await client.data(for: request)
            guard (200..<300).contains(response.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let actualBytes = data.count
            guard actualBytes <= Self.maximumPackBytes else {
                throw CatalogValidationError.byteCount(expected: Self.maximumPackBytes, actual: actualBytes)
            }
            let actualHash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            guard actualBytes == entry.bytes else {
                throw CatalogValidationError.byteCount(expected: entry.bytes, actual: actualBytes)
            }
            guard actualHash.caseInsensitiveCompare(entry.sha256) == .orderedSame else {
                throw CatalogValidationError.checksum(expected: entry.sha256, actual: actualHash)
            }

            let incoming = try decoder.decode(CataloguePack.self, from: data)
            try validate(incoming, company: company)
            if let current, incoming.revision < current.revision {
                throw CatalogValidationError.staleRevision(incoming.revision)
            }
            if let current, incoming.revision == current.revision {
                loaded[company] = current
                let result = RefreshStatus(company: company, kind: .unchanged, revision: current.revision, message: "Catalogue is already current")
                lastStatus = result
                return result
            }
            let merged = merge(previous: current, incoming: incoming)
            try validate(merged, company: company)
            try writeAtomically(encoder.encode(merged), to: cacheURL(company))
            loaded[company] = merged
            let result = RefreshStatus(company: company, kind: .refreshed, revision: merged.revision, message: "Catalogue refreshed")
            lastStatus = result
            return result
        } catch {
            let revision = loaded[company]?.revision ?? (try? readCachedPack(company))?.revision
            let result = RefreshStatus(company: company, kind: .failed, revision: revision, message: refreshErrorMessage(error))
            lastStatus = result
            return result
        }
    }

    func status() -> RefreshStatus? { lastStatus }

    func clearCache() throws {
        loaded.removeAll()
        if fileManager.fileExists(atPath: cacheDirectory.path) {
            try fileManager.removeItem(at: cacheDirectory)
        }
    }

    private func fetchManifest() async throws -> ManifestDocument {
        var request = URLRequest(url: Self.manifestURL)
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let metadataURL = cacheDirectory.appendingPathComponent("manifest.meta.json")
        if let metadata = try? Data(contentsOf: metadataURL),
           let saved = try? decoder.decode(ManifestMetadata.self, from: metadata),
           let etag = saved.etag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        let (data, response) = try await client.data(for: request)
        if response.statusCode == 304,
           let cached = try? Data(contentsOf: cacheDirectory.appendingPathComponent("manifest.json")) {
            return try decodeManifest(cached)
        }
        guard response.statusCode == 200 else { throw URLError(.badServerResponse) }
        let manifest = try decodeManifest(data)
        let etag = response.value(forHTTPHeaderField: "ETag")
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try writeAtomically(data, to: cacheDirectory.appendingPathComponent("manifest.json"))
        try writeAtomically(encoder.encode(ManifestMetadata(etag: etag)), to: metadataURL)
        return manifest
    }

    private func decodeManifest(_ data: Data) throws -> ManifestDocument {
        do {
            let manifest = try decoder.decode(ManifestDocument.self, from: data)
            guard manifest.schemaVersion == Self.supportedSchemaVersion else {
                throw CatalogValidationError.unsupportedManifestSchema(manifest.schemaVersion)
            }
            for entry in manifest.companies.values {
                guard entry.bytes > 0, entry.bytes <= Self.maximumPackBytes,
                      entry.sha256.count == 64,
                      let url = URL(string: entry.url), isSafeHTTPS(url), entry.revision > 0 else {
                    throw CatalogValidationError.invalidManifestEntry(entry.url)
                }
            }
            return manifest
        } catch let error as CatalogValidationError {
            throw error
        } catch {
            throw CatalogValidationError.malformed(error.localizedDescription)
        }
    }

    private func readCachedPack(_ company: CompanyID) throws -> CataloguePack? {
        let url = cacheURL(company)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        do { return try decoder.decode(CataloguePack.self, from: Data(contentsOf: url)) }
        catch {
            let backup = url.appendingPathExtension("last-good")
            guard fileManager.fileExists(atPath: backup.path) else { throw error }
            return try decoder.decode(CataloguePack.self, from: Data(contentsOf: backup))
        }
    }

    private func readFixture(_ company: CompanyID) throws -> CataloguePack? {
        guard let url = bundle.url(forResource: "\(company.rawValue)-fixture", withExtension: "json") else { return nil }
        return try decoder.decode(CataloguePack.self, from: Data(contentsOf: url))
    }

    private func cacheURL(_ company: CompanyID) -> URL {
        cacheDirectory.appendingPathComponent("\(company.rawValue).json")
    }

    private func writeAtomically(_ data: Data, to destination: URL) throws {
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        let temporary = destination.appendingPathExtension("tmp-\(UUID().uuidString)")
        do {
            try data.write(to: temporary, options: .atomic)
            if fileManager.fileExists(atPath: destination.path) {
                let backup = destination.appendingPathExtension("last-good")
                try? fileManager.removeItem(at: backup)
                try fileManager.copyItem(at: destination, to: backup)

                // FileManager.replaceItemAt can fail in the tvOS app sandbox
                // with NSFileWriteNoPermission even when the directory is
                // writable. A copy-backed remove/move keeps the last-good
                // file and works with the sandbox's normal file operations.
                do {
                    try fileManager.removeItem(at: destination)
                    try fileManager.moveItem(at: temporary, to: destination)
                } catch {
                    if !fileManager.fileExists(atPath: destination.path), fileManager.fileExists(atPath: backup.path) {
                        try? fileManager.copyItem(at: backup, to: destination)
                    }
                    throw error
                }
            } else {
                try fileManager.moveItem(at: temporary, to: destination)
            }
        } catch {
            try? fileManager.removeItem(at: temporary)
            throw error
        }
    }

    private func refreshErrorMessage(_ error: Error) -> String {
        let nsError = error as NSError
        let saveCodes = [CocoaError.Code.fileWriteNoPermission.rawValue,
                         CocoaError.Code.fileWriteVolumeReadOnly.rawValue,
                         CocoaError.Code.fileWriteOutOfSpace.rawValue]
        if nsError.domain == NSCocoaErrorDomain, saveCodes.contains(nsError.code) {
            return "Online catalogue refresh could not be saved; the offline catalogue was kept."
        }
        return error.localizedDescription
    }

    private func makeLibrary(_ pack: CataloguePack, loadedFromCache: Bool) -> CatalogLibrary {
        CatalogLibrary(company: CompanyID(rawValue: pack.company) ?? .wwe,
                       revision: pack.revision,
                       episodes: CatalogOrdering.sorted(pack.catalogue.episodes),
                       loadedFromCache: loadedFromCache)
    }

    private func validate(_ pack: CataloguePack, company: CompanyID) throws {
        guard pack.schemaVersion == Self.supportedSchemaVersion else {
            throw CatalogValidationError.unsupportedPackSchema(pack.schemaVersion)
        }
        guard pack.company == company.rawValue else {
            throw CatalogValidationError.wrongCompany(expected: company.rawValue, actual: pack.company)
        }
        guard pack.revision > 0, !pack.catalogue.episodes.isEmpty,
              pack.catalogue.episodes.count <= 20_000 else {
            throw CatalogValidationError.noUsableCatalogue
        }
        var IDs = Set<String>()
        for episode in pack.catalogue.episodes {
            guard !episode.id.isEmpty, IDs.insert(episode.id).inserted else {
                throw CatalogValidationError.duplicateEpisodeID(episode.id)
            }
            guard episode.date.isValidCatalogueDate,
                  episode.year == Int(episode.date.prefix(4)),
                  !episode.title.isEmpty, !episode.show.isEmpty,
                  !episode.sources.isEmpty, episode.sources.count <= 100 else {
                throw CatalogValidationError.invalidEpisode(episode.id)
            }
            for source in episode.sources { try validate(source, configuration: pack.sources) }
        }
    }

    private func validate(_ source: EpisodeSource, configuration: SourceConfiguration) throws {
        switch source.kind {
        case .archive:
            let URLs = source.archiveURLs
            guard !URLs.isEmpty, URLs.count <= 30,
                  URLs.allSatisfy({ isArchiveURL($0) }) else {
                throw CatalogValidationError.invalidSource(source.sourceKey)
            }
        case .youtube:
            guard let videoID = source.videoId, videoID.range(of: "^[A-Za-z0-9_-]{11}$", options: .regularExpression) != nil else {
                throw CatalogValidationError.invalidSource(source.sourceKey)
            }
            guard configuration.youtube?.channelId != nil else {
                throw CatalogValidationError.invalidSource(source.sourceKey)
            }
        case .okru:
            guard let videoID = source.videoId, let owner = source.owner,
                  videoID.range(of: "^[0-9]{5,20}$", options: .regularExpression) != nil,
                  owner.range(of: "^[0-9]{5,20}$", options: .regularExpression) != nil else {
                throw CatalogValidationError.invalidSource(source.sourceKey)
            }
        case .dailymotion:
            let ids = source.videoIds ?? [source.videoId].compactMap { $0 }
            guard !ids.isEmpty, ids.count <= 30,
                  ids.allSatisfy({ $0.range(of: "^[A-Za-z0-9]{5,15}$", options: .regularExpression) != nil }),
                  source.owner?.range(of: "^[A-Za-z0-9_-]{1,80}$", options: .regularExpression) != nil else {
                throw CatalogValidationError.invalidSource(source.sourceKey)
            }
        case .unknown:
            throw CatalogValidationError.invalidSource(source.sourceKey)
        }
    }

    private func merge(previous: CataloguePack?, incoming: CataloguePack) -> CataloguePack {
        guard let previous else { return incoming }
        var rows = Dictionary(uniqueKeysWithValues: previous.catalogue.episodes.map { (identity($0), $0) })
        for fresh in incoming.catalogue.episodes {
            let key = identity(fresh)
            if let old = rows[key] {
                let oldSources = Dictionary(uniqueKeysWithValues: old.sources.map { ($0.sourceKey, $0) })
                let freshSources = Dictionary(uniqueKeysWithValues: fresh.sources.map { ($0.sourceKey, $0) })
                var combined = oldSources
                freshSources.forEach { combined[$0.key] = $0.value }
                let retired = Set(incoming.retiredSources ?? [])
                let sources = combined.values.filter { !retired.contains($0.sourceKey) }
                rows[key] = Episode(id: old.id, date: fresh.date, year: fresh.year, show: fresh.show,
                                    title: fresh.title, description: fresh.description, category: fresh.category,
                                    duration: fresh.duration, thumbnail: fresh.thumbnail, poster: fresh.poster,
                                    part: fresh.part, listedParts: fresh.listedParts, eventOrder: fresh.eventOrder,
                                    discoveredAt: old.discoveredAt ?? fresh.discoveredAt, aliases: fresh.aliases,
                                    sources: Array(sources))
            } else {
                rows[key] = fresh
            }
        }
        let retired = Set(incoming.retiredSources ?? [])
        let episodes = rows.values.compactMap { episode -> Episode? in
            let sources = episode.sources.filter { !retired.contains($0.sourceKey) }
            guard !sources.isEmpty else { return nil }
            return Episode(id: episode.id, date: episode.date, year: episode.year, show: episode.show,
                           title: episode.title, description: episode.description, category: episode.category,
                           duration: episode.duration, thumbnail: episode.thumbnail, poster: episode.poster,
                           part: episode.part, listedParts: episode.listedParts, eventOrder: episode.eventOrder,
                           discoveredAt: episode.discoveredAt, aliases: episode.aliases, sources: sources)
        }
        return CataloguePack(schemaVersion: incoming.schemaVersion, company: incoming.company, revision: incoming.revision,
                             sources: mergeConfiguration(previous.sources, incoming.sources),
                             retiredSources: incoming.retiredSources, catalogue: CatalogueData(
                                schemaVersion: incoming.catalogue.schemaVersion,
                                episodes: Array(episodes), eventCalendar: incoming.catalogue.eventCalendar,
                                archiveItems: incoming.catalogue.archiveItems, playlists: incoming.catalogue.playlists,
                                showArtwork: incoming.catalogue.showArtwork, sourceAssignments: incoming.catalogue.sourceAssignments,
                                historyMigrations: incoming.catalogue.historyMigrations))
    }

    private func identity(_ episode: Episode) -> String {
        if ["PPV", "Live event", "One Night Only"].contains(episode.show) { return "id:\(episode.id)" }
        return "date:\(episode.date):show:\(episode.show):order:\(episode.eventOrder ?? 0)"
    }

    private func mergeConfiguration(_ old: SourceConfiguration, _ fresh: SourceConfiguration) -> SourceConfiguration {
        let oldArchive = old.archive
        let newArchive = fresh.archive
        let archive = ArchiveConfiguration(enabled: newArchive?.enabled ?? oldArchive?.enabled,
                                           collectionsPerScan: newArchive?.collectionsPerScan ?? oldArchive?.collectionsPerScan,
                                           collections: mergeByID(oldArchive?.collections ?? [], newArchive?.collections ?? []))
        let youtube = YouTubeConfiguration(enabled: fresh.youtube?.enabled ?? old.youtube?.enabled,
                                           channelId: fresh.youtube?.channelId ?? old.youtube?.channelId ?? "",
                                           playlists: mergeByID(old.youtube?.playlists ?? [], fresh.youtube?.playlists ?? []),
                                           videos: mergeByID(old.youtube?.videos ?? [], fresh.youtube?.videos ?? []))
        let dailymotion = DailymotionConfiguration(enabled: fresh.dailymotion?.enabled ?? old.dailymotion?.enabled,
                                                    videos: mergeByID(old.dailymotion?.videos ?? [], fresh.dailymotion?.videos ?? []))
        let okru = OKRUConfiguration(enabled: fresh.okru?.enabled ?? old.okru?.enabled,
                                     videos: mergeByID(old.okru?.videos ?? [], fresh.okru?.videos ?? []))
        return SourceConfiguration(schemaVersion: fresh.schemaVersion, youtube: youtube, archive: archive,
                                   dailymotion: dailymotion, okru: okru)
    }

    private func mergeByID<T: Codable & Sendable>(_ old: [T], _ fresh: [T]) -> [T] {
        // A pack is a correction, not a deletion signal. Preserve the last-known
        // configuration when a newer pack omits a section, while replacing it
        // when upstream supplies a non-empty section.
        fresh.isEmpty ? old : fresh
    }

    private func isSafeHTTPS(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https" && url.host != nil && url.user == nil && url.fragment == nil
    }

    private func isArchiveURL(_ url: URL) -> Bool {
        isSafeHTTPS(url) && url.host?.lowercased() == "archive.org" && url.path.hasPrefix("/download/")
    }
}

private struct ManifestMetadata: Codable, Sendable {
    let etag: String?
}
