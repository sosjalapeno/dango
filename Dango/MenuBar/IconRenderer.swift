import SwiftUI
import AppKit

final class IconRenderer {

    private let iconSize = CGSize(width: 48, height: 18)

    @MainActor
    func render(stateMachine: PomodoroStateMachine) -> NSImage {
        let view = MenuBarIconView(
            completedSessions: stateMachine.completedSessions,
            completedBreaks: stateMachine.completedBreaks,
            activeProgress: stateMachine.progress,
            phase: stateMachine.phase,
            timerState: stateMachine.timerState,
            breakProgress: stateMachine.breakProgress
        )
        .frame(width: iconSize.width, height: iconSize.height)

        let renderer = ImageRenderer(content: view)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0

        guard let image = renderer.nsImage else {
            return NSImage(
                systemSymbolName: "circle",
                accessibilityDescription: "Dango"
            ) ?? NSImage()
        }

        image.isTemplate = true
        image.size = iconSize
        return image
    }
}
