import Foundation
import AVFoundation
import AVKit
import Combine
import SwiftUI

@MainActor
final class PlaybackCoordinator: ObservableObject {
    enum State: Equatable {
        case idle
        case resolving
        case playing
        case paused
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var player: AVQueuePlayer?
    @Published private(set) var episode: Episode?
    @Published private(set) var selectedSource: EpisodeSource?
    @Published private(set) var currentPart = 0

    private let resolver: SourceResolverProtocol
    private let history: HistoryStore
    private var progressTimer: Timer?
    private var endObserver: NSObjectProtocol?
    private var currentCompany: CompanyID?
    private var autoplay: Bool

    init(resolver: SourceResolverProtocol = SourceResolver(), history: HistoryStore, autoplay: Bool = true) {
        self.resolver = resolver
        self.history = history
        self.autoplay = autoplay
    }

    func setAutoplay(_ enabled: Bool) { autoplay = enabled }

    func start(episode: Episode, company: CompanyID, preferredSourceKey: String? = nil) async {
        stop(save: true)
        self.episode = episode
        self.currentCompany = company
        state = .resolving

        let ordered = episode.sources.sorted { lhs, rhs in
            if lhs.sourceKey == preferredSourceKey { return true }
            if rhs.sourceKey == preferredSourceKey { return false }
            if lhs.kind == .archive && rhs.kind != .archive { return true }
            return lhs.displayLabel < rhs.displayLabel
        }

        var lastError: Error?
        for source in ordered {
            do {
                let plan = try await resolver.resolve(source)
                let items = plan.urls.map { AVPlayerItem(url: $0) }
                guard !items.isEmpty else { continue }
                let queue = AVQueuePlayer(items: items)
                self.player = queue
                self.selectedSource = source
                self.currentPart = 0
                let key = HistoryKey(company: company, episodeID: episode.id)
                let resume = (try? await history.resumePosition(for: key)) ?? 0
                if resume > 0 { _ = await queue.seek(to: CMTime(seconds: resume, preferredTimescale: 600)) }
                observe(queue: queue, key: key)
                queue.play()
                state = .playing
                return
            } catch {
                lastError = error
            }
        }
        state = .failed(lastError?.localizedDescription ?? PlaybackError.noEligibleSource.localizedDescription)
    }

    func stop(save: Bool) {
        if save { saveProgress() }
        progressTimer?.invalidate()
        progressTimer = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        player?.pause()
        player = nil
        selectedSource = nil
        episode = nil
        currentCompany = nil
        state = .idle
    }

    func togglePlayPause() {
        guard let player else { return }
        if player.timeControlStatus == .playing {
            player.pause(); state = .paused
        } else {
            player.play(); state = .playing
        }
    }

    func saveProgress() {
        guard let player, let episode, let company = currentCompany else { return }
        let key = HistoryKey(company: company, episodeID: episode.id)
        let position = max(0, player.currentTime().seconds.isFinite ? player.currentTime().seconds : 0)
        Task { try? await history.saveProgress(for: key, position: position, duration: episode.duration, partIndex: currentPart, preferredSourceKey: selectedSource?.sourceKey) }
    }

    private func observe(queue: AVQueuePlayer, key: HistoryKey) {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.saveProgress()
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main) { [weak self] notification in
            Task { @MainActor [weak self] in
                guard let self, let item = notification.object as? AVPlayerItem, item === queue.currentItem else { return }
                if queue.items().count <= 1 {
                    Task { try? await self.history.markCompleted(for: key, duration: self.episode?.duration, preferredSourceKey: self.selectedSource?.sourceKey) }
                    self.state = .paused
                    if self.autoplay { self.state = .playing }
                } else {
                    self.currentPart += 1
                }
            }
        }
    }
}

struct PlayerViewController: UIViewControllerRepresentable {
    let player: AVQueuePlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== player { controller.player = player }
    }
}
