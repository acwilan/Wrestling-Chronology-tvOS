import Foundation

enum CatalogOrdering {
    private static let showRanks: [String: Int] = [
        "All Nighter": 0, "Saturday Night": 1, "Worldwide": 2, "Pro": 3,
        "Power Hour": 4, "Main Event": 5, "Prime": 6, "Raw": 7,
        "SmackDown": 8, "Heat": 9, "Hardcore TV": 10, "ECW on TNN": 11,
        "Impact": 12, "Weekly PPV": 13, "Nitro": 14, "Thunder": 15,
        "Clash of the Champions": 16, "PPV": 17
    ]

    static func sorted(_ episodes: [Episode]) -> [Episode] {
        episodes.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            let leftRank = showRanks[lhs.show, default: 1_000]
            let rightRank = showRanks[rhs.show, default: 1_000]
            if leftRank != rightRank { return leftRank < rightRank }
            let leftEvent = lhs.eventOrder ?? 0
            let rightEvent = rhs.eventOrder ?? 0
            if leftEvent != rightEvent { return leftEvent < rightEvent }
            let titleOrder = lhs.title.localizedStandardCompare(rhs.title)
            if titleOrder != .orderedSame { return titleOrder == .orderedAscending }
            return lhs.id < rhs.id
        }
    }

    static func years(_ episodes: [Episode]) -> [Int] {
        Array(Set(episodes.map(\.year))).sorted()
    }
}
