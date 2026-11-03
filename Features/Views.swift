import SwiftUI
import AVKit

struct ContentView: View {
    @StateObject var model: AppModel
    @FocusState private var focusedCompany: CompanyID?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 40) {
                    header
                    if !model.continueWatching.isEmpty {
                        EpisodeRow(title: "Continue Watching", episodes: model.continueWatching, model: model)
                    }
                    CompanyPicker(model: model, focusedCompany: $focusedCompany)
                    NavigationLink("Browse Chronology", destination: LibraryView(model: model))
                        .buttonStyle(.borderedProminent)
                    if let latest = model.library?.episodes.suffix(12), !latest.isEmpty {
                        EpisodeRow(title: "Recently Added", episodes: Array(latest.reversed()), model: model)
                    }
                    NavigationLink("Search", destination: SearchView(model: model))
                        .buttonStyle(.borderedProminent)
                    NavigationLink("Settings", destination: SettingsView(model: model))
                        .buttonStyle(.bordered)
                }
                .padding(.horizontal, 80)
                .padding(.vertical, 50)
            }
            .navigationTitle("Wrestling Chronology")
            .task { await model.loadSelectedCompany() }
        }
        .tint(.pink)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Wrestling Chronology")
                .font(.largeTitle.bold())
            Text(model.statusMessage)
                .foregroundStyle(.secondary)
        }
    }
}

struct CompanyPicker: View {
    @ObservedObject var model: AppModel
    @FocusState.Binding var focusedCompany: CompanyID?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Company Libraries").font(.title2.bold())
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 22) {
                    ForEach(CompanyID.allCases) { company in
                        Button {
                            model.selectCompany(company)
                        } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(LinearGradient(colors: [.indigo, .black], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 270, height: 145)
                                    .overlay(Text(company.displayName).font(.title3.bold()).multilineTextAlignment(.center).padding())
                                Text(company.years).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .focused($focusedCompany, equals: company)
                        .accessibilityLabel("Open \(company.displayName), \(company.years)")
                    }
                }
            }
        }
    }
}

struct EpisodeRow: View {
    let title: String
    let episodes: [Episode]
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title).font(.title2.bold())
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(episodes) { episode in
                        NavigationLink(destination: EpisodeDetailView(episode: episode, model: model)) {
                            EpisodeCard(episode: episode, model: model)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct EpisodeCard: View {
    let episode: Episode
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: [.blue.opacity(0.7), .black], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 240, height: 135)
                Image(systemName: episode.category == "ppv" ? "star.fill" : "play.tv.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(16)
                if model.progress(for: episode) > 0 {
                    ProgressView(value: model.progress(for: episode))
                        .tint(.pink)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 7)
                }
            }
            Text(episode.title).font(.headline).lineLimit(2).frame(width: 240, alignment: .leading)
            Text("\(episode.displayDate) · \(episode.show)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(episode.title), \(episode.displayDate), \(episode.show)")
    }
}

struct LibraryView: View {
    @ObservedObject var model: AppModel
    @StateObject private var localState = LibraryViewState()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Picker("Year", selection: Binding(get: { model.selectedYear ?? model.years.last ?? 0 }, set: { model.selectedYear = $0 })) {
                    ForEach(model.years, id: \.self) { Text(String($0)).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 1000)
                Picker("Show", selection: $localState.showFilter) {
                    Text("All").tag("All")
                    ForEach(Array(Set(model.filteredEpisodes.map(\.show))).sorted(), id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 270), spacing: 24)], spacing: 28) {
                    ForEach(model.filteredEpisodes.filter { localState.showFilter == "All" || $0.show == localState.showFilter }) { episode in
                        NavigationLink(destination: EpisodeDetailView(episode: episode, model: model)) {
                            EpisodeCard(episode: episode, model: model)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(70)
        }
        .navigationTitle("\(model.selectedCompany.displayName) · Chronology")
    }
}

struct EpisodeDetailView: View {
    let episode: Episode
    @ObservedObject var model: AppModel
    @StateObject private var localState = EpisodeDetailViewState()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                RoundedRectangle(cornerRadius: 24)
                    .fill(LinearGradient(colors: [.indigo, .black], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(height: 270)
                    .overlay(Image(systemName: "play.tv.fill").font(.system(size: 70)).foregroundStyle(.white.opacity(0.8)))
                Text(episode.title).font(.largeTitle.bold())
                Text("\(episode.displayDate) · \(episode.show) · \(episode.runtimeText ?? "Runtime unknown")")
                    .foregroundStyle(.secondary)
                if let description = episode.description, !description.isEmpty { Text(description).font(.body) }
                if let record = model.history(for: episode), record.position > 0, !record.completed {
                    Text("Resume at \(Int(record.position / 60)) minutes").foregroundStyle(.pink)
                }
                HStack(spacing: 20) {
                    Button(model.history(for: episode)?.completed == true ? "Play Again" : "Play / Resume") {
                        Task {
                            await model.playback.start(episode: episode, company: model.selectedCompany,
                                                       preferredSourceKey: model.history(for: episode)?.preferredSourceKey)
                            localState.showingPlayer = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Mark Watched") {
                        Task {
                            try? await model.history.markCompleted(for: HistoryKey(company: model.selectedCompany, episodeID: episode.id), duration: episode.duration)
                            await model.reloadHistory()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                Text("Sources").font(.title2.bold())
                ForEach(episode.sources) { source in
                    HStack {
                        Image(systemName: source.kind == .archive ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(source.kind == .archive ? .green : .orange)
                        Text(source.displayLabel)
                        Spacer()
                        Text(source.kind == .archive ? "Available" : "Unsupported on tvOS")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(70)
        }
        .navigationTitle(episode.title)
        .fullScreenCover(isPresented: $localState.showingPlayer, onDismiss: {
            model.playback.stop(save: true)
            Task { await model.reloadHistory() }
        }) {
            PlayerScreen(coordinator: model.playback)
        }
    }
}

struct PlayerScreen: View {
    @ObservedObject var coordinator: PlaybackCoordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let player = coordinator.player {
                PlayerViewController(player: player).ignoresSafeArea()
            } else if case .failed(let message) = coordinator.state {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle").font(.largeTitle)
                    Text(message).multilineTextAlignment(.center)
                    Button("Close") { dismiss() }.buttonStyle(.borderedProminent)
                }
                .padding(80)
            } else {
                ProgressView("Preparing playback…")
            }
        }
        .onExitCommand { dismiss() }
    }
}

struct SearchView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading) {
            TextField("Search titles, shows, dates", text: $model.searchText)
                .padding(.horizontal, 70)
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 270), spacing: 24)], spacing: 28) {
                    ForEach(model.filteredEpisodes) { episode in
                        NavigationLink(destination: EpisodeDetailView(episode: episode, model: model)) {
                            EpisodeCard(episode: episode, model: model)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(70)
            }
        }
        .navigationTitle("Search")
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @StateObject private var localState = SettingsViewState()

    var body: some View {
        Form {
            Section("Playback") {
                Toggle("Autoplay next chronological broadcast", isOn: $model.autoplay)
                Picker("Preferred source", selection: $model.preferredSource) {
                    Text("Automatic").tag("automatic")
                    Text("Internet Archive").tag("archive")
                }
            }
            Section("Catalogue") {
                Text(model.statusMessage)
                Button("Refresh current company") { Task { await model.refresh() } }
                Button("Reset local data", role: .destructive) { localState.showingReset = true }
            }
            Section {
                NavigationLink("About", destination: AboutView())
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog("Delete cached catalogues and watch history?", isPresented: $localState.showingReset, titleVisibility: .visible) {
            Button("Delete Local Data", role: .destructive) { model.resetData() }
        }
    }
}

private final class LibraryViewState: ObservableObject {
    @Published var showFilter = "All"
}

private final class EpisodeDetailViewState: ObservableObject {
    @Published var showingPlayer = false
}

private final class SettingsViewState: ObservableObject {
    @Published var showingReset = false
}

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Wrestling Chronology for tvOS").font(.largeTitle.bold())
                Text("An unofficial community-maintained tvOS port of Wrestling Chronology by digitalm1nd.")
                Link("Upstream project", destination: URL(string: "https://github.com/deklol/Wrestling-Chronology")!)
                Link("tvOS project", destination: URL(string: "https://github.com/acwilan/Wrestling-Chronology-tvOS")!)
                Text("Licensed under GPL-3.0-or-later. This app does not host or redistribute recordings and is not endorsed by Apple or any wrestling promotion.")
                Text("Provider availability, rights, and geographic access can change. Unsupported sources are shown without extraction or DRM bypass.")
            }
            .padding(80)
        }
        .navigationTitle("About")
    }
}
