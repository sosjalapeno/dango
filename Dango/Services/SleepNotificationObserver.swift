import AppKit

@MainActor
final class SleepNotificationObserver {

    private let engine: TimerEngine

    init(engine: TimerEngine) {
        self.engine = engine
    }

    func startObserving() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    func stopObserving() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func systemDidWake(_ notification: Notification) {
        engine.recalculate()
    }
}
