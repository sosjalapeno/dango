import Foundation

struct DailyStats: Codable, Equatable {
    var rolls: Int = 0
    var dangos: Int = 0
    var focusSeconds: TimeInterval = 0

    private enum CodingKeys: String, CodingKey {
        case rolls
        case dangos
        case pomodoros
        case sessions
        case focusSeconds
    }

    init(rolls: Int = 0, dangos: Int = 0, focusSeconds: TimeInterval = 0) {
        self.rolls = rolls
        self.dangos = dangos
        self.focusSeconds = focusSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rolls = try container.decodeIfPresent(Int.self, forKey: .rolls) ?? 0
        dangos = try container.decodeIfPresent(Int.self, forKey: .dangos)
            ?? container.decodeIfPresent(Int.self, forKey: .pomodoros)
            ?? container.decodeIfPresent(Int.self, forKey: .sessions)
            ?? 0
        focusSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .focusSeconds) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rolls, forKey: .rolls)
        try container.encode(dangos, forKey: .dangos)
        try container.encode(focusSeconds, forKey: .focusSeconds)
    }

    var formattedFocusTime: String {
        formattedFocusTime(inFlightSeconds: 0)
    }

    func formattedFocusTime(inFlightSeconds: TimeInterval) -> String {
        let totalMinutes = Int((focusSeconds + inFlightSeconds) / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    mutating func addFocusSeconds(_ seconds: TimeInterval) {
        guard seconds > 0 else { return }
        focusSeconds += seconds
    }

    mutating func recordCompletedDango() {
        dangos += 1
    }

    mutating func recordDango(durationSeconds: TimeInterval) {
        addFocusSeconds(durationSeconds)
        recordCompletedDango()
    }

    mutating func recordRoll() {
        rolls += 1
    }

    func subtracting(_ other: DailyStats) -> DailyStats {
        DailyStats(
            rolls: max(0, rolls - other.rolls),
            dangos: max(0, dangos - other.dangos),
            focusSeconds: max(0, focusSeconds - other.focusSeconds)
        )
    }
}
