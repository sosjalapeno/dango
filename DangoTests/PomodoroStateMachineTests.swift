import XCTest
@testable import Dango

@MainActor
final class PomodoroStateMachineTests: XCTestCase {

    private var sut: PomodoroStateMachine!
    private var store: SessionStore!

    override func setUp() {
        super.setUp()
        store = SessionStore()
        store.focusDuration = 1
        store.shortBreakDuration = 1
        store.longBreakDuration = 1
        sut = PomodoroStateMachine(store: store)
    }

    override func tearDown() {
        sut = nil
        store = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialStateIsIdle() {
        XCTAssertEqual(sut.phase, .idle)
        XCTAssertEqual(sut.timerState, .stopped)
        XCTAssertEqual(sut.progress, 0.0)
        XCTAssertEqual(sut.completedSessions, 0)
    }

    // MARK: - Toggle from Idle

    func testToggleFromIdleStartsFocus1() {
        sut.toggle()
        XCTAssertEqual(sut.phase, .focus(session: 1))
        XCTAssertEqual(sut.timerState, .running)
    }

    // MARK: - Toggle Pause / Resume

    func testTogglePausesRunningTimer() {
        sut.toggle()
        Thread.sleep(forTimeInterval: 0.25)
        sut.toggle()
        XCTAssertEqual(sut.timerState, .paused)
        XCTAssertEqual(sut.phase, .focus(session: 1))
    }

    func testToggleResumesPausedTimer() {
        sut.toggle()
        Thread.sleep(forTimeInterval: 0.25)
        sut.toggle()
        Thread.sleep(forTimeInterval: 0.25)
        sut.toggle()
        XCTAssertEqual(sut.timerState, .running)
    }

    // MARK: - Full Cycle Transitions

    func testFocus1CompletesToShortBreak1() {
        sut.toggle()
        sut.completeCurrentPhase()
        XCTAssertEqual(sut.phase, .shortBreak(after: 1))
        XCTAssertEqual(sut.timerState, .running)
    }

    func testShortBreak1CompletesToFocus2() {
        sut.toggle()
        sut.completeCurrentPhase()
        sut.completeCurrentPhase()
        XCTAssertEqual(sut.phase, .focus(session: 2))
    }

    func testFullCycleEndsWithLongBreak() {
        sut.toggle()
        for _ in 0..<7 { sut.completeCurrentPhase() }
        XCTAssertEqual(sut.phase, .longBreak)
    }

    func testLongBreakCompletesToIdle() {
        sut.toggle()
        for _ in 0..<7 { sut.completeCurrentPhase() }
        sut.completeCurrentPhase()
        XCTAssertEqual(sut.phase, .idle)
        XCTAssertEqual(sut.timerState, .stopped)
    }

    // MARK: - Reset

    func testResetFromAnyStateGoesToIdle() {
        sut.toggle()
        sut.completeCurrentPhase()
        sut.reset()
        XCTAssertEqual(sut.phase, .idle)
        XCTAssertEqual(sut.timerState, .stopped)
        XCTAssertEqual(sut.progress, 0.0)
    }

    // MARK: - Skip

    func testSkipCompletesCurrentPhase() {
        sut.toggle()
        sut.skip()
        XCTAssertEqual(sut.phase, .shortBreak(after: 1))
    }

    func testSkipDoesNothingWhenIdle() {
        sut.skip()
        XCTAssertEqual(sut.phase, .idle)
    }

    // MARK: - Completed Session Count

    func testCompletedSessionsIncrementsCorrectly() {
        XCTAssertEqual(sut.completedSessions, 0)

        sut.toggle()
        XCTAssertEqual(sut.completedSessions, 0)

        sut.completeCurrentPhase()
        XCTAssertEqual(sut.completedSessions, 1)

        sut.completeCurrentPhase()
        XCTAssertEqual(sut.completedSessions, 1)

        sut.completeCurrentPhase()
        XCTAssertEqual(sut.completedSessions, 2)
    }

    // MARK: - Stats Recording

    func testFocusCompletionRecordsStats() {
        let initialToday = sut.todayStats.dangos
        let initialAllTime = sut.allTimeStats.dangos
        sut.toggle()
        sut.completeCurrentPhase()
        XCTAssertEqual(sut.todayStats.dangos, initialToday + 1)
        XCTAssertEqual(sut.allTimeStats.dangos, initialAllTime + 1)
    }

    func testFullCycleRecordsRoll() {
        let initialToday = sut.todayStats.rolls
        let initialAllTime = sut.allTimeStats.rolls
        sut.toggle()
        for _ in 0..<8 { sut.completeCurrentPhase() }
        XCTAssertEqual(sut.todayStats.rolls, initialToday + 1)
        XCTAssertEqual(sut.allTimeStats.rolls, initialAllTime + 1)
    }

    // MARK: - Debounce

    func testClearTodayStatsSubtractsFromAllTime() {
        store.recordDango(durationSeconds: 1500)
        store.recordRoll()
        let todayBefore = store.todayStats
        let allTimeBefore = store.allTimeStats

        store.clearTodayStats()

        XCTAssertEqual(store.todayStats, DailyStats())
        XCTAssertEqual(store.allTimeStats.rolls, allTimeBefore.rolls - todayBefore.rolls)
        XCTAssertEqual(store.allTimeStats.dangos, allTimeBefore.dangos - todayBefore.dangos)
        XCTAssertEqual(store.allTimeStats.focusSeconds, allTimeBefore.focusSeconds - todayBefore.focusSeconds)
    }

    func testClearAllStatsRemovesTodayAndAllTime() {
        store.recordDango(durationSeconds: 1500)
        store.clearAllStats()

        XCTAssertEqual(store.todayStats, DailyStats())
        XCTAssertEqual(store.allTimeStats, DailyStats())
    }

    func testRapidToggleIsDebounced() {
        sut.toggle()
        sut.toggle()
        XCTAssertEqual(sut.timerState, .running)
    }
}
