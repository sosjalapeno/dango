import XCTest
@testable import Dango

@MainActor
final class TimerEngineTests: XCTestCase {

    private var engine: TimerEngine!
    private var stateMachine: PomodoroStateMachine!
    private var store: SessionStore!

    override func setUp() {
        super.setUp()
        store = SessionStore()
        store.focusDuration = 25
        store.shortBreakDuration = 5
        store.longBreakDuration = 30
        stateMachine = PomodoroStateMachine(store: store)
        engine = stateMachine.timerEngine
    }

    override func tearDown() {
        engine = nil
        stateMachine = nil
        store = nil
        super.tearDown()
    }

    // MARK: - Duration Calculation

    func testFocusDurationIsCorrect() {
        let duration = store.durationSeconds(for: .focus(session: 1))
        XCTAssertEqual(duration, 25 * 60)
    }

    func testShortBreakDurationIsCorrect() {
        let duration = store.durationSeconds(for: .shortBreak(after: 1))
        XCTAssertEqual(duration, 5 * 60)
    }

    func testLongBreakDurationIsCorrect() {
        let duration = store.durationSeconds(for: .longBreak)
        XCTAssertEqual(duration, 30 * 60)
    }

    // MARK: - Duration Clamping

    func testDurationClampingMinimum() {
        XCTAssertEqual(store.clampedMinutes(0), 1)
        XCTAssertEqual(store.clampedMinutes(-5), 1)
    }

    func testDurationClampingMaximum() {
        XCTAssertEqual(store.clampedMinutes(200), 180)
        XCTAssertEqual(store.clampedMinutes(999), 180)
    }

    func testDurationClampingValid() {
        XCTAssertEqual(store.clampedMinutes(25), 25)
        XCTAssertEqual(store.clampedMinutes(1), 1)
        XCTAssertEqual(store.clampedMinutes(180), 180)
    }

    // MARK: - Remaining Seconds

    func testRemainingSecondsDecreasesOverTime() {
        stateMachine.toggle()

        Thread.sleep(forTimeInterval: 0.1)

        let remaining = engine.remainingSeconds
        let expected = 25.0 * 60.0
        XCTAssertLessThan(remaining, expected)
        XCTAssertGreaterThan(remaining, expected - 1.0)
    }

    // MARK: - Pause / Resume Accumulation

    func testPauseAccumulatesElapsedTime() {
        stateMachine.toggle()
        Thread.sleep(forTimeInterval: 0.3)

        engine.pause()
        let accumulated = engine.accumulatedBeforePause

        XCTAssertGreaterThan(accumulated, 0.2)
        XCTAssertLessThan(accumulated, 0.5)
        XCTAssertNil(engine.phaseStartDate)
    }

    // MARK: - Debounce

    func testDebounceAllowsFirstToggle() {
        XCTAssertTrue(engine.shouldAllowToggle())
    }

    func testDebounceBlocksRapidSecondToggle() {
        _ = engine.shouldAllowToggle()
        XCTAssertFalse(engine.shouldAllowToggle())
    }

    func testDebounceAllowsAfterDelay() {
        _ = engine.shouldAllowToggle()
        Thread.sleep(forTimeInterval: 0.25)
        XCTAssertTrue(engine.shouldAllowToggle())
    }

    // MARK: - Idle Duration

    func testIdleDurationIsZero() {
        let duration = store.durationSeconds(for: .idle)
        XCTAssertEqual(duration, 0)
    }
}
