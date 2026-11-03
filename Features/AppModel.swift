import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var library: CatalogLibrary?
    @Published private(set) var statusMessage = "Loading catalogue…"
    @Published private(set) var historyRecords: [String: WatchRecord] = [:]
    @Published var selectedCompany: CompanyID = CompanyID(rawValue: UserDefaults.standard.string(forKey: "selectedCompany") ?? "wwe") ?? .wwe
    @Published var selectedYear: Int?
    @Published var searchText = ""
    @Published var showOnlyUnwatched = false
    @Published var autoplay: Bool {
        didSet { UserDefaults.standard.set(autoplay, forKey: "autoplay") }
    }
    @Published var preferredSource: String {
        didSet { UserDefaults.standard.set(preferredSource, forKey: "preferredSource") }
    }

    let repository: CatalogRepository
    let history: HistoryStore
    let playback: PlaybackCoordinator

    init(repository: CatalogRepository = CatalogRepository(), history: HistoryStore = HistoryStore()) {
        self.repository = repository
        self.history = history
        let autoplayValue = UserDefaults.standard.object(forKey: "autoplay") as? Bool ?? true
        let preferredSourceValue = UserDefaults.standard.string(forKey: "preferredSource") ?? "automatic"
        self.autoplay = autoplayValue
        self.preferredSource = preferredSourceValue
        self.playback = PlaybackCoordinator(history: history, autoplay: autoplayValue)
    }

    var years: [Int] { CatalogOrdering.years(library?.episodes ?? []) }

    var filteredEpisodes: [Episode] {
        guard let episodes = library?.episodes else { return [] }
        return episodes.filter { episode in
            (selectedYear == nil || episode.year == selectedYear) &&
            (!showOnlyUnwatched || !isCompleted(episode)) &&
            (searchText.isEmpty || episode.searchText.localizedCaseInsensitiveContains(searchText))
        }
    }

    var continueWatching: [Episode] {
        guard let episodes = library?.episodes else { return [] }
        return episodes.filter { episode in
            guard let record = historyRecords[HistoryKey(company: selectedCompany, episodeID: episode.id).rawValue] else { return false }
            return record.isStarted && !record.completed
        }.sorted { lhs, rhs in
            let left = historyRecords[HistoryKey(company: selectedCompany, episodeID: lhs.id).rawValue]?.lastPlayedAt ?? .distantPast
            let right = historyRecords[HistoryKey(company: selectedCompany, episodeID: rhs.id).rawValue]?.lastPlayedAt ?? .distantPast
            return left > right
        }
    }

    func loadSelectedCompany() async {
        statusMessage = "Loading \(selectedCompany.displayName)…"
        do {
            library = try await repository.library(for: selectedCompany)
            if selectedYear == nil { selectedYear = years.last }
            await reloadHistory()
            let company = selectedCompany
            statusMessage = "Offline catalogue ready; refreshing \(company.displayName)…"
            Task { [weak self] in
                guard let self else { return }
                let refreshStatus = await self.repository.refresh(company: company)
                guard self.selectedCompany == company else { return }
                if refreshStatus.kind == .refreshed {
                    self.library = try? await self.repository.library(for: company)
                    if let yearsLast = self.years.last, self.selectedYear == nil || !self.years.contains(self.selectedYear ?? 0) {
                        self.selectedYear = yearsLast
                    }
                    await self.reloadHistory()
                }
                switch refreshStatus.kind {
                case .failed:
                    self.statusMessage = "Offline catalogue ready — online refresh unavailable: \(refreshStatus.message)"
                case .bundled:
                    self.statusMessage = "Bundled catalogue ready"
                default:
                    self.statusMessage = refreshStatus.message
                }
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func refresh() async {
        let status = await repository.refresh(company: selectedCompany, force: true)
        statusMessage = status.message
        if status.kind == .refreshed { library = try? await repository.library(for: selectedCompany) }
        await reloadHistory()
    }

    func selectCompany(_ company: CompanyID) {
        selectedCompany = company
        UserDefaults.standard.set(company.rawValue, forKey: "selectedCompany")
        selectedYear = nil
        searchText = ""
        Task { await loadSelectedCompany() }
    }

    func isCompleted(_ episode: Episode) -> Bool {
        historyRecords[HistoryKey(company: selectedCompany, episodeID: episode.id).rawValue]?.completed ?? false
    }

    func progress(for episode: Episode) -> Double {
        guard let record = historyRecords[HistoryKey(company: selectedCompany, episodeID: episode.id).rawValue] else { return 0 }
        if record.completed { return 1 }
        guard let duration = record.duration ?? episode.duration, duration > 0 else { return 0 }
        return min(0.99, record.position / duration)
    }

    func history(for episode: Episode) -> WatchRecord? {
        historyRecords[HistoryKey(company: selectedCompany, episodeID: episode.id).rawValue]
    }

    func reloadHistory() async {
        guard let records = try? await history.records() else { return }
        historyRecords = Dictionary(uniqueKeysWithValues: records.compactMap { record in
            guard let separator = record.id.firstIndex(of: "|") else { return nil }
            let company = String(record.id[..<separator])
            guard company == selectedCompany.rawValue else { return nil }
            return (record.id, record)
        })
    }

    func resetData() {
        Task {
            try? await history.reset()
            try? await repository.clearCache()
            historyRecords = [:]
            library = nil
            await loadSelectedCompany()
        }
    }
}
