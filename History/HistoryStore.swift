import Foundation

struct HistoryKey: Hashable, Codable, Sendable {
    let company: CompanyID
    let episodeID: String

    var rawValue: String { "\(company.rawValue)|\(episodeID)" }
}

struct WatchRecord: Codable, Sendable, Equatable, Identifiable {
    var id: String
    var position: Double
    var duration: Double?
    var completed: Bool
    var lastPlayedAt: Date
    var partIndex: Int
    var preferredSourceKey: String?
    var schemaVersion: Int

    var isStarted: Bool { position > 0 || completed }
}

struct HistoryDocument: Codable, Sendable {
    var schemaVersion: Int
    var records: [String: WatchRecord]
}

actor HistoryStore {
    static let currentSchemaVersion = 1
    static let resumeThreshold: Double = 30

    private let fileManager: FileManager
    private let fileURL: URL
    private var document: HistoryDocument
    private var loaded = false

    init(fileURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WrestlingChronology", isDirectory: true)
            .appendingPathComponent("history.json")
        self.document = HistoryDocument(schemaVersion: Self.currentSchemaVersion, records: [:])
    }

    func load() throws {
        guard !loaded else { return }
        loaded = true
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(HistoryDocument.self, from: data)
            document = migrate(decoded)
        } catch {
            // A corrupt history file must never prevent catalogue browsing. Preserve it for diagnosis.
            let backup = fileURL.appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970))")
            try? fileManager.moveItem(at: fileURL, to: backup)
            document = HistoryDocument(schemaVersion: Self.currentSchemaVersion, records: [:])
        }
    }

    func record(for key: HistoryKey) throws -> WatchRecord? {
        try load()
        return document.records[key.rawValue]
    }

    func records() throws -> [WatchRecord] {
        try load()
        return Array(document.records.values).sorted { $0.lastPlayedAt > $1.lastPlayedAt }
    }

    func saveProgress(
        for key: HistoryKey,
        position: Double,
        duration: Double?,
        partIndex: Int = 0,
        preferredSourceKey: String? = nil
    ) throws {
        try load()
        let previous = document.records[key.rawValue]
        let completed = previous?.completed ?? false
        document.records[key.rawValue] = WatchRecord(
            id: key.rawValue,
            position: max(0, position),
            duration: duration,
            completed: completed,
            lastPlayedAt: Date(),
            partIndex: max(0, partIndex),
            preferredSourceKey: preferredSourceKey ?? previous?.preferredSourceKey,
            schemaVersion: Self.currentSchemaVersion
        )
        try persist()
    }

    func markCompleted(for key: HistoryKey, duration: Double?, preferredSourceKey: String? = nil) throws {
        try load()
        let previous = document.records[key.rawValue]
        document.records[key.rawValue] = WatchRecord(
            id: key.rawValue,
            position: duration ?? previous?.position ?? 0,
            duration: duration ?? previous?.duration,
            completed: true,
            lastPlayedAt: Date(),
            partIndex: previous?.partIndex ?? 0,
            preferredSourceKey: preferredSourceKey ?? previous?.preferredSourceKey,
            schemaVersion: Self.currentSchemaVersion
        )
        try persist()
    }

    func setPreferredSource(_ sourceKey: String, for key: HistoryKey) throws {
        try load()
        let previous = document.records[key.rawValue]
        document.records[key.rawValue] = WatchRecord(
            id: key.rawValue,
            position: previous?.position ?? 0,
            duration: previous?.duration,
            completed: previous?.completed ?? false,
            lastPlayedAt: previous?.lastPlayedAt ?? Date(),
            partIndex: previous?.partIndex ?? 0,
            preferredSourceKey: sourceKey,
            schemaVersion: Self.currentSchemaVersion
        )
        try persist()
    }

    func reset() throws {
        document = HistoryDocument(schemaVersion: Self.currentSchemaVersion, records: [:])
        loaded = true
        if fileManager.fileExists(atPath: fileURL.path) { try fileManager.removeItem(at: fileURL) }
    }

    func resumePosition(for key: HistoryKey) throws -> Double {
        guard let record = try record(for: key), !record.completed, record.position >= Self.resumeThreshold else { return 0 }
        return record.position
    }

    func progress(for key: HistoryKey) throws -> Double {
        guard let record = try record(for: key), let duration = record.duration, duration > 0 else { return 0 }
        if record.completed { return 1 }
        return min(0.99, max(0, record.position / duration))
    }

    private func migrate(_ old: HistoryDocument) -> HistoryDocument {
        guard old.schemaVersion < Self.currentSchemaVersion else { return old }
        var records = old.records
        for key in records.keys { records[key]?.schemaVersion = Self.currentSchemaVersion }
        return HistoryDocument(schemaVersion: Self.currentSchemaVersion, records: records)
    }

    private func persist() throws {
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(document)
        let temporary = fileURL.appendingPathExtension("tmp-\(UUID().uuidString)")
        try data.write(to: temporary, options: .atomic)
        if fileManager.fileExists(atPath: fileURL.path) {
            _ = try fileManager.replaceItemAt(fileURL, withItemAt: temporary, backupItemName: nil, options: .usingNewMetadataOnly)
        } else {
            try fileManager.moveItem(at: temporary, to: fileURL)
        }
    }
}
