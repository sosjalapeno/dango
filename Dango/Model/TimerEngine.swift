import Foundation
import Combine

@MainActor
final class TimerEngine {

    // MARK: - Dependencies

    private weak var stateMachine: PomodoroStateMachine?
    private let store: SessionStore

    // MARK: - Timer State

    private(set) var phaseStartDate: Date?
    private(set) var phaseDuration: TimeInterval = 0
    private(set) var accumulatedBeforePause: TimeInterval = 0

    private var displayTimer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "dango.timer.display", qos: .userInteractive)

    private var lastToggleDate: Date = .distantPast

    // MARK: - Initialization

    init(store: SessionStore) {
        self.store = store
    }

    func attach(to stateMachine: PomodoroStateMachine) {
        self.stateMachine = stateMachine
    }

    // MARK: - Start / Resume

    func startPhase(_ phase: PomodoroPhase) {
        phaseDuration = store.durationSeconds(for: phase)
        accumulatedBeforePause = 0
        phaseStartDate = Date()
        persistState()
        startDisplayTimer()
    }

    func resume() {
        phaseStartDate = Date()
        persistState()
        startDisplayTimer()
    }

    // MARK: - Pause

    func pause() {
        if let start = phaseStartDate {
            accumulatedBeforePause += Date().timeIntervalSince(start)
        }
        phaseStartDate = nil
        stopDisplayTimer()
        persistState()
        recalculateProgress()
    }

    // MARK: - Stop / Reset

    func stop() {
        phaseStartDate = nil
        accumulatedBeforePause = 0
        phaseDuration = 0
        stopDisplayTimer()
        store.clearSavedTimerState()
    }

    // MARK: - Recalculation

    func recalculate() {
        guard let sm = stateMachine else { return }
        guard sm.timerState == .running else { return }

        let progress = recalculateProgress()

        if progress >= 1.0 {
            stopDisplayTimer()
            sm.completeCurrentPhase()
        }
    }

    @discardableResult
    private func recalculateProgress() -> Double {
        guard phaseDuration > 0 else { return 0 }

        let elapsed = elapsedSeconds
        let progress = min(elapsed / phaseDuration, 1.0)
        publishProgress(progress)

        return progress
    }

    var elapsedSeconds: TimeInterval {
        var elapsed = accumulatedBeforePause
        if let start = phaseStartDate {
            elapsed += Date().timeIntervalSince(start)
        }
        return elapsed
    }

    private func publishProgress(_ progress: Double) {
        guard let sm = stateMachine else { return }

        switch sm.phase {
        case .shortBreak:
            sm.progress = 0
            sm.breakProgress = progress
        case .focus, .longBreak:
            sm.progress = progress
            sm.breakProgress = 0
        case .idle:
            sm.progress = 0
            sm.breakProgress = 0
        }

        if sm.phase.isFocus {
            sm.inFlightFocusSeconds = elapsedSeconds
        } else {
            sm.inFlightFocusSeconds = 0
        }
    }

    // MARK: - Debounce

    func shouldAllowToggle() -> Bool {
        let now = Date()
        guard now.timeIntervalSince(lastToggleDate) >= 0.2 else { return false }
        lastToggleDate = now
        return true
    }

    // MARK: - Remaining Time

    var remainingSeconds: TimeInterval {
        guard phaseDuration > 0 else { return 0 }
        return max(0, phaseDuration - elapsedSeconds)
    }

    // MARK: - Crash Recovery

    func restore(from saved: SessionStore.SavedTimerState) {
        phaseDuration = saved.phaseDuration
        accumulatedBeforePause = saved.accumulated
        phaseStartDate = saved.phaseStartDate

        recalculateProgress()

        if saved.timerState == .running {
            startDisplayTimer()
            recalculate()
        }
    }

    // MARK: - Display Timer

    private func startDisplayTimer() {
        stopDisplayTimer()

        let timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer.schedule(deadline: .now(), repeating: 1.0, leeway: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.recalculate()
            }
        }
        timer.resume()
        displayTimer = timer
    }

    private func stopDisplayTimer() {
        displayTimer?.cancel()
        displayTimer = nil
    }

    // MARK: - Persistence

    private func persistState() {
        guard let sm = stateMachine else { return }
        store.saveTimerState(
            phase: sm.phase,
            timerState: sm.timerState,
            phaseStartDate: phaseStartDate,
            accumulated: accumulatedBeforePause,
            phaseDuration: phaseDuration
        )
    }
}
