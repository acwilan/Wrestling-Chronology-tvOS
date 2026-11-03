import SwiftUI
import AVKit

// MARK: - Visual language

private enum WCTheme {
    static let background = Color(red: 0.025, green: 0.035, blue: 0.075)
    static let surface = Color(red: 0.075, green: 0.09, blue: 0.16)
    static let surfaceRaised = Color(red: 0.12, green: 0.14, blue: 0.23)
    static let accent = Color(red: 0.98, green: 0.32, blue: 0.47)
    static let gold = Color(red: 1.0, green: 0.72, blue: 0.28)
}

private struct WCBackground: View {
    var body: some View {
        ZStack {
            WCTheme.background.ignoresSafeArea()
            LinearGradient(
                colors: [Color.indigo.opacity(0.25), .clear, WCTheme.accent.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}

private struct SectionHeading: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.title2.weight(.bold)).foregroundStyle(.white)
            if let subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(.white.opacity(0.55))
            }
        }
    }
}

private struct FocusCardModifier: ViewModifier {
    @Environment(\.isFocused) private var isFocused

    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: 18).fill(isFocused ? WCTheme.surfaceRaised : WCTheme.surface))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(isFocused ? WCTheme.accent : .white.opacity(0.06), lineWidth: isFocused ? 3 : 1))
            .shadow(color: isFocused ? WCTheme.accent.opacity(0.28) : .black.opacity(0.2), radius: isFocused ? 18 : 8)
            .scaleEffect(isFocused ? 1.045 : 1.0)
            .animation(.easeOut(duration: 0.16), value: isFocused)
    }
}

private extension View {
    func focusCard() -> some View { modifier(FocusCardModifier()) }
}

private extension CompanyID {
    var themeColor: Color {
        switch self {
        case .wcw: return Color(red: 0.10, green: 0.47, blue: 0.92)
        case .wwe: return Color(red: 0.92, green: 0.18, blue: 0.27)
        case .aew: return Color(red: 0.75, green: 0.76, blue: 0.80)
        case .ecw: return Color(red: 0.28, green: 0.28, blue: 0.32)
        case .njpw: return Color(red: 0.96, green: 0.58, blue: 0.12)
        case .nxt: return Color(red: 0.98, green: 0.72, blue: 0.18)
        case .roh: return Color(red: 0.44, green: 0.30, blue: 0.78)
        case .tna: return Color(red: 0.06, green: 0.70, blue: 0.66)
        }
    }
}

// MARK: - Home

struct ContentView: View {
    @StateObject var model: AppModel
    @FocusState private var focusedCompany: CompanyID?

    var body: some View {
        NavigationStack {
            ZStack {
                WCBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 42) {
                        HomeHero(model: model)
                        if !model.continueWatching.isEmpty {
                            EpisodeRow(title: "Continue Watching", subtitle: "Pick up where you left off", episodes: model.continueWatching, model: model)
                        }
                        CompanyPicker(model: model, focusedCompany: $focusedCompany)
                        HStack(spacing: 18) {
                            NavigationLink(destination: LibraryView(model: model)) {
                                ActionTile(icon: "calendar.badge.clock", title: "Browse Chronology", subtitle: "Explore every broadcast")
                            }
                            .buttonStyle(.plain).focusCard()
                            NavigationLink(destination: SearchView(model: model)) {
                                ActionTile(icon: "magnifyingglass", title: "Search", subtitle: "Find a title or show")
                            }
                            .buttonStyle(.plain).focusCard()
                            NavigationLink(destination: SettingsView(model: model)) {
                                ActionTile(icon: "slider.horizontal.3", title: "Settings", subtitle: "Playback and catalogue")
                            }
                            .buttonStyle(.plain).focusCard()
                        }
                        .frame(maxWidth: 1200)
                        if let latest = model.library?.episodes.suffix(12), !latest.isEmpty {
                            EpisodeRow(title: "Recently Added", subtitle: "Latest catalogue updates", episodes: Array(latest.reversed()), model: model)
                        }
                    }
                    .padding(.horizontal, 76).padding(.vertical, 54)
                }
            }
            .navigationTitle("")
            .task { await model.loadSelectedCompany() }
        }
        .tint(WCTheme.accent)
    }
}

private struct HomeHero: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(alignment: .bottom, spacing: 30) {
            VStack(alignment: .leading, spacing: 12) {
                Text("WRESTLING CHRONOLOGY").font(.caption.weight(.bold)).tracking(2.5).foregroundStyle(WCTheme.gold)
                Text("Every broadcast.\nIn order.")
                    .font(.system(size: 54, weight: .black, design: .rounded))
                    .foregroundStyle(.white).lineSpacing(-4)
                Text("A community-maintained archive of wrestling history, made for the big screen.")
                    .font(.title3).foregroundStyle(.white.opacity(0.68)).frame(maxWidth: 650, alignment: .leading)
                HStack(spacing: 10) {
                    Circle().fill(model.library == nil ? .orange : .green).frame(width: 8, height: 8)
                    Text(model.statusMessage).font(.caption).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                }.padding(.top, 5)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Image(systemName: "play.rectangle.on.rectangle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(LinearGradient(colors: [WCTheme.accent, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                Text(model.selectedCompany.displayName).font(.headline).foregroundStyle(.white.opacity(0.75))
            }.padding(.trailing, 28)
        }
        .frame(maxWidth: 1400, minHeight: 220, alignment: .bottomLeading)
    }
}

private struct ActionTile: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon).font(.title2.weight(.semibold)).foregroundStyle(WCTheme.accent).frame(width: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).foregroundStyle(.white)
                Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.55))
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.4))
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CompanyPicker: View {
    @ObservedObject var model: AppModel
    @FocusState.Binding var focusedCompany: CompanyID?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionHeading(title: "Company Libraries", subtitle: "Choose a promotion to enter its timeline")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 20) {
                    ForEach(CompanyID.allCases) { company in
                        Button { model.selectCompany(company) } label: {
                            ZStack(alignment: .bottomLeading) {
                                LinearGradient(colors: [company.themeColor, .black.opacity(0.92)], startPoint: .topTrailing, endPoint: .bottomLeading)
                                Circle().fill(.white.opacity(0.1)).frame(width: 130, height: 130).offset(x: 165, y: 28)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(company.displayName).font(.title3.weight(.bold)).foregroundStyle(.white).lineLimit(2)
                                    Text(company.years).font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.68))
                                }.padding(18)
                            }
                            .frame(width: 260, height: 136)
                        }
                        .buttonStyle(.plain).focusCard().focused($focusedCompany, equals: company)
                        .accessibilityLabel("Open \(company.displayName), \(company.years)")
                    }
                }.padding(.vertical, 10)
            }
        }
    }
}

private struct EpisodeRow: View {
    let title: String
    var subtitle: String? = nil
    let episodes: [Episode]
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeading(title: title, subtitle: subtitle)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 20) {
                    ForEach(episodes) { episode in
                        NavigationLink(destination: EpisodeDetailView(episode: episode, model: model)) {
                            EpisodeCard(episode: episode, model: model)
                        }.buttonStyle(.plain)
                    }
                }.padding(.vertical, 10)
            }
        }
    }
}

private struct EpisodeCard: View {
    let episode: Episode
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: episode.category == "ppv" ? [Color.orange.opacity(0.9), .purple, .black] : [Color.blue.opacity(0.9), .indigo, .black], startPoint: .topTrailing, endPoint: .bottomLeading)
                    .frame(width: 282, height: 158)
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: episode.category == "ppv" ? "star.fill" : "waveform.path.ecg")
                            .font(.title3).foregroundStyle(.white.opacity(0.8)).padding(15)
                    }
                    .overlay(alignment: .bottomLeading) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(episode.show.uppercased()).font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(.white.opacity(0.72))
                            Text(episode.displayDate).font(.caption.weight(.semibold)).foregroundStyle(.white)
                        }.padding(15)
                    }
                if model.isCompleted(episode) {
                    Label("Watched", systemImage: "checkmark.circle.fill")
                        .font(.caption2.weight(.bold)).foregroundStyle(.white)
                        .padding(.horizontal, 9).padding(.vertical, 6)
                        .background(.black.opacity(0.65), in: Capsule()).padding(12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                if model.progress(for: episode) > 0 && !model.isCompleted(episode) {
                    ProgressView(value: model.progress(for: episode)).tint(WCTheme.accent).padding(.horizontal, 13).padding(.bottom, 8)
                }
            }
            Text(episode.title).font(.headline).foregroundStyle(.white).lineLimit(2).frame(width: 282, height: 42, alignment: .topLeading)
            Text(episode.runtimeText ?? "Runtime unknown").font(.caption).foregroundStyle(.white.opacity(0.48))
        }
        .padding(10).focusCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(episode.title), \(episode.displayDate), \(episode.show)")
    }
}

// MARK: - Browsing and search

struct LibraryView: View {
    @ObservedObject var model: AppModel
    @StateObject private var localState = LibraryViewState()

    var body: some View {
        ZStack {
            WCBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.selectedCompany.displayName).font(.largeTitle.weight(.black))
                        Text("Chronological broadcast archive").foregroundStyle(.white.opacity(0.58))
                    }
                    YearStrip(model: model)
                    Picker("Show", selection: $localState.showFilter) {
                        Text("All shows").tag("All")
                        ForEach(Array(Set(model.filteredEpisodes.map(\.show))).sorted(), id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.menu).frame(maxWidth: 350, alignment: .leading)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 310), spacing: 24)], spacing: 24) {
                        ForEach(model.filteredEpisodes.filter { localState.showFilter == "All" || $0.show == localState.showFilter }) { episode in
                            NavigationLink(destination: EpisodeDetailView(episode: episode, model: model)) {
                                EpisodeCard(episode: episode, model: model)
                            }.buttonStyle(.plain)
                        }
                    }
                }.padding(76)
            }
        }.navigationTitle("Chronology")
    }
}

private struct YearStrip: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YEAR").font(.caption.weight(.bold)).tracking(1.8).foregroundStyle(WCTheme.gold)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(model.years, id: \.self) { year in
                        Button(String(year)) { model.selectedYear = year }
                            .buttonStyle(.borderedProminent)
                            .tint(model.selectedYear == year ? WCTheme.accent : WCTheme.surfaceRaised)
                    }
                }
            }
        }
    }
}

struct SearchView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ZStack {
            WCBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    TextField("Search titles, shows, dates", text: $model.searchText)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(WCTheme.surface, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.12)))
                        .frame(maxWidth: 850)
                    if model.searchText.isEmpty {
                        EmptyState(icon: "magnifyingglass", title: "Search the archive", message: "Try a show name, event title, or date.")
                    } else if model.filteredEpisodes.isEmpty {
                        EmptyState(icon: "rectangle.and.text.magnifyingglass", title: "No matches", message: "Try a shorter title or a different year.")
                    } else {
                        Text("\(model.filteredEpisodes.count) results").font(.headline).foregroundStyle(.white.opacity(0.6))
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 310), spacing: 24)], spacing: 24) {
                            ForEach(model.filteredEpisodes) { episode in
                                NavigationLink(destination: EpisodeDetailView(episode: episode, model: model)) {
                                    EpisodeCard(episode: episode, model: model)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }.padding(76)
            }
        }.navigationTitle("Search")
    }
}

private struct EmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).font(.system(size: 42)).foregroundStyle(WCTheme.accent)
            Text(title).font(.title2.weight(.bold))
            Text(message).foregroundStyle(.white.opacity(0.58))
        }.padding(28).frame(maxWidth: 620, alignment: .leading).background(WCTheme.surface, in: RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Episode detail and playback

struct EpisodeDetailView: View {
    let episode: Episode
    @ObservedObject var model: AppModel
    @StateObject private var localState = EpisodeDetailViewState()
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            WCBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    HStack(alignment: .top, spacing: 35) {
                        detailArtwork
                        VStack(alignment: .leading, spacing: 14) {
                            Text(episode.show.uppercased()).font(.caption.weight(.bold)).tracking(2).foregroundStyle(WCTheme.gold)
                            Text(episode.title).font(.system(size: 40, weight: .black, design: .rounded)).foregroundStyle(.white)
                            Text("\(episode.displayDate)  ·  \(episode.show)  ·  \(episode.runtimeText ?? "Runtime unknown")").foregroundStyle(.white.opacity(0.62))
                            if let description = episode.description, !description.isEmpty {
                                Text(description).font(.body).foregroundStyle(.white.opacity(0.78)).lineSpacing(3)
                            }
                            if let record = model.history(for: episode), record.position > 0, !record.completed {
                                Label("Resume at \(Int(record.position / 60)) minutes", systemImage: "arrow.triangle.2.circlepath").foregroundStyle(WCTheme.accent)
                            }
                            HStack(spacing: 15) {
                                Button(model.history(for: episode)?.completed == true ? "Play Again" : "Play / Resume") {
                                    Task {
                                        await model.playback.start(episode: episode, company: model.selectedCompany, preferredSourceKey: model.history(for: episode)?.preferredSourceKey)
                                        localState.showingPlayer = true
                                    }
                                }.buttonStyle(.borderedProminent)
                                Button("Mark Watched") {
                                    Task {
                                        try? await model.history.markCompleted(for: HistoryKey(company: model.selectedCompany, episodeID: episode.id), duration: episode.duration)
                                        await model.reloadHistory()
                                    }
                                }.buttonStyle(.bordered)
                            }
                        }
                    }
                    SectionHeading(title: "Where to watch", subtitle: "Direct playback is available only where tvOS can safely support the provider")
                    VStack(spacing: 12) {
                        ForEach(episode.sources) { source in SourceRow(source: source, openURL: openURL) }
                    }
                }.padding(76)
            }
        }
        .navigationTitle(episode.title)
        .fullScreenCover(isPresented: $localState.showingPlayer, onDismiss: {
            model.playback.stop(save: true)
            Task { await model.reloadHistory() }
        }) { PlayerScreen(coordinator: model.playback) }
    }

    private var detailArtwork: some View {
        ZStack {
            LinearGradient(colors: [WCTheme.accent, .purple, .black], startPoint: .topTrailing, endPoint: .bottomLeading)
            Image(systemName: episode.category == "ppv" ? "star.fill" : "play.tv.fill").font(.system(size: 68)).foregroundStyle(.white.opacity(0.85))
        }.frame(width: 390, height: 220).clipShape(RoundedRectangle(cornerRadius: 24)).shadow(color: WCTheme.accent.opacity(0.25), radius: 20)
    }
}

private struct SourceRow: View {
    let source: EpisodeSource
    let openURL: OpenURLAction

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: source.kind == .archive ? "play.circle.fill" : "arrow.up.right.square.fill")
                .font(.title2).foregroundStyle(source.kind == .archive ? .green : WCTheme.gold).frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(source.displayLabel).font(.headline)
                Text(source.kind == .archive ? "Playable on Apple TV when the recording is compatible" : "Open the provider page in its installed app or handler")
                    .font(.caption).foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            if source.kind == .archive {
                HStack(spacing: 12) {
                    Text("Apple TV playback").font(.caption.weight(.semibold)).foregroundStyle(.green)
                    if let url = source.externalURL {
                        Button("Open Archive") { openURL(url) }.buttonStyle(.bordered)
                    }
                }
            } else if let url = source.externalURL {
                Button(source.externalActionTitle) { openURL(url) }.buttonStyle(.bordered)
            } else {
                Text("No public link").font(.caption).foregroundStyle(.white.opacity(0.45))
            }
        }.padding(18).background(WCTheme.surface, in: RoundedRectangle(cornerRadius: 16))
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
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 45)).foregroundStyle(WCTheme.gold)
                    Text("Playback unavailable").font(.title2.weight(.bold))
                    Text(message).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.7))
                    Button("Close") { dismiss() }.buttonStyle(.borderedProminent)
                }.padding(80)
            } else {
                VStack(spacing: 15) {
                    ProgressView().tint(WCTheme.accent)
                    Text("Preparing playback…").foregroundStyle(.white.opacity(0.7))
                }
            }
        }.onExitCommand { dismiss() }
    }
}

// MARK: - Settings and attribution

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @StateObject private var localState = SettingsViewState()

    var body: some View {
        ZStack {
            WCBackground()
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
                Section { NavigationLink("About", destination: AboutView()) }
            }
            .background(Color.clear).padding(.horizontal, 55)
        }
        .navigationTitle("Settings")
        .confirmationDialog("Delete cached catalogues and watch history?", isPresented: $localState.showingReset, titleVisibility: .visible) {
            Button("Delete Local Data", role: .destructive) { model.resetData() }
        }
    }
}

private final class LibraryViewState: ObservableObject { @Published var showFilter = "All" }
private final class EpisodeDetailViewState: ObservableObject { @Published var showingPlayer = false }
private final class SettingsViewState: ObservableObject { @Published var showingReset = false }

struct AboutView: View {
    var body: some View {
        ZStack {
            WCBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Image(systemName: "play.rectangle.on.rectangle.fill").font(.system(size: 60)).foregroundStyle(LinearGradient(colors: [WCTheme.accent, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Text("Wrestling Chronology for tvOS").font(.largeTitle.weight(.black))
                    Text("An unofficial, community-maintained tvOS port of Wrestling Chronology by digitalm1nd.").foregroundStyle(.white.opacity(0.75))
                    Link("Visit the upstream project", destination: URL(string: "https://github.com/deklol/Wrestling-Chronology")!)
                    Link("Visit the tvOS project", destination: URL(string: "https://github.com/acwilan/Wrestling-Chronology-tvOS")!)
                    Divider().overlay(.white.opacity(0.15))
                    Text("Licensed under GPL-3.0-or-later. This app does not host or redistribute recordings and is not endorsed by Apple or any wrestling promotion.")
                    Text("Provider availability, rights, and geographic access can change. Unsupported sources are shown as external provider links without extraction, DRM bypass, or proxying.").foregroundStyle(.white.opacity(0.62))
                }.frame(maxWidth: 850, alignment: .leading).padding(80)
            }
        }.navigationTitle("About")
    }
}
