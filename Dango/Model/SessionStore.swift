import Foundation
import Combine

@MainActor
final class SessionStore: ObservableObject {

    static let shared = SessionStore()

    private let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Key {
        static let focusDuration = "dango.focusDuration"
        static let shortBreakDuration = "dango.shortBreakDuration"
        static let longBreakDuration = "dango.longBreakDuration"
        static let launchAtLogin = "dango.launchAtLogin"
        static let audioEnabled = "dango.audioEnabled"
        static let autoAdvance = "dango.autoAdvance"
        static let showFloatingCountdown = "dango.showFloatingCountdown"
        static let leftClickOpensPopover = "dango.leftClickOpensPopover"
        static let dailyStatsPrefix = "dango.stats."
        static let allTimeStats = "dango.stats.allTime"
        static let allTimeStatsMigrated = "dango.stats.allTimeMigrated"
        static let savedPhase = "dango.saved.phase"
        static let savedTimerState = "dango.saved.timerState"
        static let savedPhaseStartDate = "dango.saved.phaseStartDate"
        static let savedAccumulated = "dango.saved.accumulated"
        static let savedPhaseDuration = "dango.saved.phaseDuration"
    }

    // MARK: - Timer Durations (in minutes)

    @Published var focusDuration: Int {
        didSet { defaults.set(focusDuration, forKey: Key.focusDuration) }
    }

    @Published var shortBreakDuration: Int {
        didSet { defaults.set(shortBreakDuration, forKey: Key.shortBreakDuration) }
    }

    @Published var longBreakDuration: Int {
        didSet { defaults.set(longBreakDuration, forKey: Key.longBreakDuration) }
    }

    // MARK: - Toggle States

    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Key.launchAtLogin) }
    }

    @Published var audioEnabled: Bool {
        didSet { defaults.set(audioEnabled, forKey: Key.audioEnabled) }
    }

    @Published var autoAdvance: Bool {
        didSet { defaults.set(autoAdvance, forKey: Key.autoAdvance) }
    }

    @Published var showFloatingCountdown: Bool {
        didSet { defaults.set(showFloatingCountdown, forKey: Key.showFloatingCountdown) }
    }

    @Published var leftClickOpensPopover: Bool {
        didSet { defaults.set(leftClickOpensPopover, forKey: Key.leftClickOpensPopover) }
    }

    // MARK: - Initialization

    init() {
        defaults.register(defaults: [
            Key.focusDuration: 25,
            Key.shortBreakDuration: 5,
            Key.longBreakDuration: 30,
            Key.launchAtLogin: false,
            Key.audioEnabled: true,
            Key.autoAdvance: true,
            Key.showFloatingCountdown: false,
            Key.leftClickOpensPopover: true,
        ])

        self.focusDuration = defaults.integer(forKey: Key.focusDuration)
        self.shortBreakDuration = defaults.integer(forKey: Key.shortBreakDuration)
        self.longBreakDuration = defaults.integer(forKey: Key.longBreakDuration)
        self.launchAtLogin = defaults.bool(forKey: Key.launchAtLogin)
        self.audioEnabled = defaults.bool(forKey: Key.audioEnabled)
        self.autoAdvance = defaults.bool(forKey: Key.autoAdvance)
        self.showFloatingCountdown = defaults.bool(forKey: Key.showFloatingCountdown)
        self.leftClickOpensPopover = defaults.bool(forKey: Key.leftClickOpensPopover)
    }

    // MARK: - Duration Accessors (in seconds)

    func durationSeconds(for phase: PomodoroPhase) -> TimeInterval {
        switch phase {
        case .idle:
            return 0
        case .focus:
            return TimeInterval(clampedMinutes(focusDuration)) * 60
        case .shortBreak:
            return TimeInterval(clampedMinutes(shortBreakDuration)) * 60
        case .longBreak:
            return TimeInterval(clampedMinutes(longBreakDuration)) * 60
        }
    }

    func clampedMinutes(_ value: Int) -> Int {
        max(1, min(180, value))
    }

    func commitAndReinitialize() {
        focusDuration = clampedMinutes(focusDuration)
        shortBreakDuration = clampedMinutes(shortBreakDuration)
        longBreakDuration = clampedMinutes(longBreakDuration)
    }

    // MARK: - Statistics

    private var todayKey: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return Key.dailyStatsPrefix + formatter.string(from: Date())
    }

    var todayStats: DailyStats {
        get { loadStats(forKey: todayKey) }
        set { saveStats(newValue, forKey: todayKey) }
    }

    var allTimeStats: DailyStats {
        get {
            migrateAllTimeStatsIfNeeded()
            return loadStats(forKey: Key.allTimeStats)
        }
        set { saveStats(newValue, forKey: Key.allTimeStats) }
    }

    func addFocusSeconds(_ seconds: TimeInterval) {
        guard seconds > 0 else { return }

        var today = todayStats
        today.addFocusSeconds(seconds)
        todayStats = today

        var allTime = allTimeStats
        allTime.addFocusSeconds(seconds)
        allTimeStats = allTime
    }

    func recordCompletedDango() {
        var today = todayStats
        today.recordCompletedDango()
        todayStats = today

        var allTime = allTimeStats
        allTime.recordCompletedDango()
        allTimeStats = allTime
    }

    func recordDango(durationSeconds: TimeInterval) {
        addFocusSeconds(durationSeconds)
        recordCompletedDango()
    }

    func recordRoll() {
        var today = todayStats
        today.recordRoll()
        todayStats = today

        var allTime = allTimeStats
        allTime.recordRoll()
        allTimeStats = allTime
    }

    func clearTodayStats() {
        let today = todayStats
        allTimeStats = allTimeStats.subtracting(today)
        todayStats = DailyStats()
        objectWillChange.send()
    }

    func clearAllStats() {
        todayStats = DailyStats()
        allTimeStats = DailyStats()
        objectWillChange.send()
    }

    private func loadStats(forKey key: String) -> DailyStats {
        guard let data = defaults.data(forKey: key),
              let stats = try? JSONDecoder().decode(DailyStats.self, from: data)
        else {
            return DailyStats()
        }
        return stats
    }

    private func saveStats(_ stats: DailyStats, forKey key: String) {
        if let data = try? JSONEncoder().encode(stats) {
            defaults.set(data, forKey: key)
        }
        objectWillChange.send()
    }

    private func migrateAllTimeStatsIfNeeded() {
        guard !defaults.bool(forKey: Key.allTimeStatsMigrated) else { return }

        var combined = DailyStats()
        for (key, value) in defaults.dictionaryRepresentation() {
            guard key.hasPrefix(Key.dailyStatsPrefix),
                  key != Key.allTimeStats,
                  key != Key.allTimeStatsMigrated,
                  let data = value as? Data,
                  let stats = try? JSONDecoder().decode(DailyStats.self, from: data)
            else { continue }
            combined.rolls += stats.rolls
            combined.dangos += stats.dangos
            combined.focusSeconds += stats.focusSeconds
        }

        saveStats(combined, forKey: Key.allTimeStats)
        defaults.set(true, forKey: Key.allTimeStatsMigrated)
    }

    // MARK: - Crash Recovery

    func saveTimerState(phase: PomodoroPhase, timerState: TimerState,
                        phaseStartDate: Date?, accumulated: TimeInterval,
                        phaseDuration: TimeInterval) {
        if let phaseData = try? JSONEncoder().encode(phase) {
            defaults.set(phaseData, forKey: Key.savedPhase)
        }
        if let stateData = try? JSONEncoder().encode(timerState) {
            defaults.set(stateData, forKey: Key.savedTimerState)
        }
        defaults.set(phaseStartDate, forKey: Key.savedPhaseStartDate)
        defaults.set(accumulated, forKey: Key.savedAccumulated)
        defaults.set(phaseDuration, forKey: Key.savedPhaseDuration)
    }

    struct SavedTimerState {
        let phase: PomodoroPhase
        let timerState: TimerState
        let phaseStartDate: Date?
        let accumulated: TimeInterval
        let phaseDuration: TimeInterval
    }

    func loadSavedTimerState() -> SavedTimerState? {
        guard let phaseData = defaults.data(forKey: Key.savedPhase),
              let phase = try? JSONDecoder().decode(PomodoroPhase.self, from: phaseData),
              let stateData = defaults.data(forKey: Key.savedTimerState),
              let timerState = try? JSONDecoder().decode(TimerState.self, from: stateData)
        else { return nil }

        let startDate = defaults.object(forKey: Key.savedPhaseStartDate) as? Date
        let accumulated = defaults.double(forKey: Key.savedAccumulated)
        let duration = defaults.double(forKey: Key.savedPhaseDuration)

        guard duration > 0 else { return nil }

        return SavedTimerState(
            phase: phase,
            timerState: timerState,
            phaseStartDate: startDate,
            accumulated: accumulated,
            phaseDuration: duration
        )
    }

    func clearSavedTimerState() {
        defaults.removeObject(forKey: Key.savedPhase)
        defaults.removeObject(forKey: Key.savedTimerState)
        defaults.removeObject(forKey: Key.savedPhaseStartDate)
        defaults.removeObject(forKey: Key.savedAccumulated)
        defaults.removeObject(forKey: Key.savedPhaseDuration)
    }
}
