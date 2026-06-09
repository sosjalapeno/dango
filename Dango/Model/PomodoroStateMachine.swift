import Foundation
import Combine

@MainActor
final class PomodoroStateMachine: ObservableObject {

    // MARK: - Published State

    @Published var phase: PomodoroPhase = .idle
    @Published var timerState: TimerState = .stopped
    @Published var progress: Double = 0.0
    @Published var breakProgress: Double = 0.0
    @Published var inFlightFocusSeconds: TimeInterval = 0

    // MARK: - Dependencies

    let sessionStore: SessionStore
    let timerEngine: TimerEngine

    var onPhaseTransition: ((PomodoroPhase, PomodoroPhase) -> Void)?
    var onStateChange: (() -> Void)?

    private var isRestoring = false

    // MARK: - Initialization

    init(store: SessionStore) {
        self.sessionStore = store
        self.timerEngine = TimerEngine(store: store)
        self.timerEngine.attach(to: self)
    }

    // MARK: - Computed Properties

    var isRunning: Bool {
        timerState == .running
    }

    var completedSessions: Int {
        phase.completedSessionCount
    }

    var completedBreaks: Int {
        phase.completedBreakCount
    }

    var todayStats: DailyStats {
        sessionStore.todayStats
    }

    var allTimeStats: DailyStats {
        sessionStore.allTimeStats
    }

    var remainingSeconds: TimeInterval {
        timerEngine.remainingSeconds
    }

    // MARK: - Time Formatting

    var formattedRemainingTime: String {
        let seconds: TimeInterval
        if timerState == .stopped && phase == .idle {
            seconds = sessionStore.durationSeconds(for: .focus(session: 1))
        } else if timerState == .stopped {
            seconds = sessionStore.durationSeconds(for: phase)
        } else {
            seconds = timerEngine.remainingSeconds
        }

        let total = Int(ceil(seconds))
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Actions

    func toggle() {
        guard timerEngine.shouldAllowToggle() else { return }

        switch timerState {
        case .stopped:
            if phase == .idle {
                startFocus(session: 1)
            } else {
                timerState = .running
                timerEngine.startPhase(phase)
                notifyStateChange()
            }

        case .running:
            timerState = .paused
            timerEngine.pause()
            notifyStateChange()

        case .paused:
            timerState = .running
            timerEngine.resume()
            notifyStateChange()
        }
    }

    func skip() {
        guard phase != .idle else { return }
        completeCurrentPhase()
    }

    func reset() {
        let oldPhase = phase
        if oldPhase.isFocus {
            let elapsed = timerEngine.elapsedSeconds
            if elapsed > 60 {
                sessionStore.addFocusSeconds(elapsed)
            }
        }
        inFlightFocusSeconds = 0
        timerEngine.stop()
        phase = .idle
        timerState = .stopped
        progress = 0
        breakProgress = 0
        if oldPhase != .idle {
            onPhaseTransition?(oldPhase, .idle)
        }
        notifyStateChange()
    }

    func resetCurrentPhase() {
        guard phase != .idle else { return }
        inFlightFocusSeconds = 0
        timerEngine.stop()
        progress = 0
        breakProgress = 0
        timerState = .stopped
        notifyStateChange()
    }

    // MARK: - Phase Transitions

    func completeCurrentPhase() {
        let oldPhase = phase

        if oldPhase.isFocus {
            let credited = min(timerEngine.elapsedSeconds, timerEngine.phaseDuration)
            sessionStore.addFocusSeconds(credited)
            sessionStore.recordCompletedDango()
        }

        inFlightFocusSeconds = 0

        let nextPhase = nextPhase(after: oldPhase)

        if case .longBreak = oldPhase {
            sessionStore.recordRoll()
        }

        timerEngine.stop()
        phase = nextPhase
        progress = 0
        breakProgress = 0

        if !isRestoring {
            onPhaseTransition?(oldPhase, nextPhase)
        }

        if nextPhase == .idle {
            timerState = .stopped
            notifyStateChange()
        } else {
            if sessionStore.autoAdvance {
                timerState = .running
                timerEngine.startPhase(nextPhase)
            } else {
                timerState = .stopped
            }
            notifyStateChange()
        }
    }

    private func nextPhase(after current: PomodoroPhase) -> PomodoroPhase {
        switch current {
        case .idle:
            return .focus(session: 1)

        case .focus(let session):
            if session >= 4 {
                return .longBreak
            } else {
                return .shortBreak(after: session)
            }

        case .shortBreak(let after):
            return .focus(session: after + 1)

        case .longBreak:
            return .idle
        }
    }

    // MARK: - Internal Helpers

    private func startFocus(session: Int) {
        let oldPhase = phase
        phase = .focus(session: session)
        timerState = .running
        progress = 0
        breakProgress = 0
        timerEngine.startPhase(phase)
        onPhaseTransition?(oldPhase, phase)
        notifyStateChange()
    }

    private func notifyStateChange() {
        onStateChange?()
    }

    // MARK: - Crash Recovery

    func restoreIfNeeded() {
        guard let saved = sessionStore.loadSavedTimerState() else { return }
        guard saved.phase != .idle else { return }

        isRestoring = true
        defer { isRestoring = false }

        phase = saved.phase
        timerState = saved.timerState
        timerEngine.restore(from: saved)
    }
}
