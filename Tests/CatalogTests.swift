import XCTest
import Foundation
import CryptoKit
@testable import WrestlingChronology_tvOS

final class CatalogTests: XCTestCase {
    func testSameDayOrderingUsesShowRankThenEventOrderAndID() {
        let sources = [EpisodeSource(type: "archive", url: "https://archive.org/download/test/a.mp4", urls: nil, videoId: nil, videoIds: nil, channelId: nil, owner: nil, title: nil, label: nil, filename: nil, programme: nil, duration: nil, bytes: nil, height: nil, language: nil, audioLanguage: nil, creator: nil)]
        let episodes = [
            episode(id: "b", date: "1997-01-12", show: "PPV", order: 2, sources: sources),
            episode(id: "a", date: "1997-01-12", show: "Nitro", order: nil, sources: sources),
            episode(id: "c", date: "1997-01-12", show: "PPV", order: 1, sources: sources)
        ]
        XCTAssertEqual(CatalogOrdering.sorted(episodes).map(\.id), ["a", "c", "b"])
    }

    func testManifestRefreshRejectsWrongByteCountAndKeepsNoWorkingCatalogue() async throws {
        let pack = fixturePack(company: "wcw", revision: 2)
        let packData = try JSONEncoder().encode(pack)
        let entry = ManifestEntry(url: "https://example.com/wcw.json", sha256: sha256(packData), bytes: packData.count + 1, revision: 2)
        let manifest = ManifestDocument(schemaVersion: 1, companies: ["wcw": entry])
        let client = FakeHTTPClient(manifest: try JSONEncoder().encode(manifest), pack: packData)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let repository = CatalogRepository(client: client, cacheDirectory: directory, bundle: Bundle(for: Self.self))

        let status = await repository.refresh(company: .wcw, force: true)
        XCTAssertEqual(status.kind, .failed)
        let library = try? await repository.library(for: .wcw)
        XCTAssertNil(library)
    }

    func testHistoryResumeThresholdAndCompletion() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("history-\(UUID().uuidString).json")
        let store = HistoryStore(fileURL: file)
        let key = HistoryKey(company: .wcw, episodeID: "episode")
        try await store.saveProgress(for: key, position: 10, duration: 100)
        let initialResume = try await store.resumePosition(for: key)
        XCTAssertEqual(initialResume, 0)
        try await store.saveProgress(for: key, position: 45, duration: 100)
        let resumedPosition = try await store.resumePosition(for: key)
        XCTAssertEqual(resumedPosition, 45)
        try await store.markCompleted(for: key, duration: 100)
        let completedResume = try await store.resumePosition(for: key)
        let completedProgress = try await store.progress(for: key)
        XCTAssertEqual(completedResume, 0)
        XCTAssertEqual(completedProgress, 1)
    }

    private func episode(id: String, date: String, show: String, order: Int?, sources: [EpisodeSource]) -> Episode {
        Episode(id: id, date: date, year: Int(date.prefix(4))!, show: show, title: id, description: nil, category: nil, duration: nil, thumbnail: nil, poster: nil, part: nil, listedParts: nil, eventOrder: order, discoveredAt: nil, aliases: nil, sources: sources)
    }

    private func fixturePack(company: String, revision: Int64) -> CataloguePack {
        let source = EpisodeSource(type: "archive", url: "https://archive.org/download/test/example.mp4", urls: nil, videoId: nil, videoIds: nil, channelId: nil, owner: nil, title: nil, label: "Internet Archive", filename: nil, programme: nil, duration: nil, bytes: nil, height: nil, language: nil, audioLanguage: nil, creator: nil)
        let row = episode(id: "1997-01-01:raw", date: "1997-01-01", show: "Raw", order: nil, sources: [source])
        let config = SourceConfiguration(schemaVersion: 1, youtube: YouTubeConfiguration(enabled: true, channelId: "UCbGG2hv4cWmIrBAIhGiCdSg", playlists: [], videos: []), archive: ArchiveConfiguration(enabled: true, collectionsPerScan: nil, collections: [ArchiveCollection(id: "test", name: "Test", enabled: true)]), dailymotion: nil, okru: nil)
        let catalogue = CatalogueData(schemaVersion: 1, episodes: [row], eventCalendar: [], archiveItems: ["test"], playlists: [], showArtwork: [:], sourceAssignments: nil, historyMigrations: nil)
        return CataloguePack(schemaVersion: 1, company: company, revision: revision, sources: config, retiredSources: [], catalogue: catalogue)
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private final class FakeHTTPClient: CatalogHTTPClient, @unchecked Sendable {
    private let manifest: Data
    private let pack: Data

    init(manifest: Data, pack: Data) {
        self.manifest = manifest
        self.pack = pack
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data = request.url == CatalogRepository.manifestURL ? manifest : pack
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (data, response)
    }
}
