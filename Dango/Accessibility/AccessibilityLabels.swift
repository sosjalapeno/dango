import Foundation

extension PomodoroStateMachine {

    var accessibilityLabel: String {
        let remaining = Int(remainingSeconds)
        let minutes = remaining / 60
        let seconds = remaining % 60
        let button = sessionStore.leftClickOpensPopover ? "Right-click" : "Left-click"

        switch (phase, timerState) {
        case (.idle, _):
            return "Dango Pomodoro Timer. Ready. \(button) to start focusing."

        case (.focus(let session), .running):
            return "Focus session \(session) of 4. \(minutes) minutes \(seconds) seconds remaining. \(button) to pause."

        case (.focus(let session), .paused):
            return "Focus session \(session) of 4. Paused with \(minutes) minutes \(seconds) seconds remaining. \(button) to resume."

        case (.shortBreak, .running):
            return "Short break. \(minutes) minutes \(seconds) seconds remaining."

        case (.shortBreak, .paused):
            return "Short break paused. \(minutes) minutes \(seconds) seconds remaining."

        case (.longBreak, .running):
            return "Long break. \(minutes) minutes \(seconds) seconds remaining."

        case (.longBreak, .paused):
            return "Long break paused. \(minutes) minutes \(seconds) seconds remaining."

        default:
            return "Dango Pomodoro Timer."
        }
    }
}
