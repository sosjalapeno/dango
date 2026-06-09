import Foundation

enum PomodoroPhase: Equatable, Codable {
    case idle
    case focus(session: Int)
    case shortBreak(after: Int)
    case longBreak

    // MARK: - Display

    var completedSessionCount: Int {
        switch self {
        case .idle:
            return 0
        case .focus(let s):
            return s - 1
        case .shortBreak(let after):
            return after
        case .longBreak:
            return 4
        }
    }

    var completedBreakCount: Int {
        switch self {
        case .idle:
            return 0
        case .focus(let s):
            return max(0, s - 1)
        case .shortBreak(let after):
            return max(0, after - 1)
        case .longBreak:
            return 3
        }
    }

    var isBreak: Bool {
        switch self {
        case .shortBreak, .longBreak: return true
        default: return false
        }
    }

    var isFocus: Bool {
        if case .focus = self { return true }
        return false
    }
}
