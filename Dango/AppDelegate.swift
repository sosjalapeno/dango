import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var stateMachine: PomodoroStateMachine!
    private var statusItemController: StatusItemController!
    private var sleepObserver: SleepNotificationObserver!
    private var floatingWindowController: FloatingCountdownWindowController!
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        stateMachine = PomodoroStateMachine(store: .shared)

        stateMachine.onPhaseTransition = { [weak self] oldPhase, newPhase in
            self?.handlePhaseTransition(from: oldPhase, to: newPhase)
        }

        statusItemController = StatusItemController(stateMachine: stateMachine)
        statusItemController.setup()

        sleepObserver = SleepNotificationObserver(engine: stateMachine.timerEngine)
        sleepObserver.startObserving()

        stateMachine.sessionStore.launchAtLogin = LoginItemService.shared.isEnabled

        stateMachine.restoreIfNeeded()

        floatingWindowController = FloatingCountdownWindowController(stateMachine: stateMachine)

        Publishers.CombineLatest(
            stateMachine.$timerState,
            stateMachine.sessionStore.$showFloatingCountdown
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _, _ in
            self?.floatingWindowController.updateVisibility()
        }
        .store(in: &cancellables)
    }

    func applicationWillTerminate(_ notification: Notification) {
        sleepObserver?.stopObserving()
        AudioFeedbackService.shared.stopAll()
    }

    // MARK: - Phase Transition Handling

    private func handlePhaseTransition(from oldPhase: PomodoroPhase, to newPhase: PomodoroPhase) {
        let rings = numberOfRingsForTransition(from: oldPhase, to: newPhase)
        if rings > 0 {
            AudioFeedbackService.shared.playTransitionClick(rings: rings)
        }

        if oldPhase != .idle {
            HapticFeedbackService.phaseTransition()
        }
    }

    private func numberOfRingsForTransition(from: PomodoroPhase, to: PomodoroPhase) -> Int {
        switch (from, to) {
        case (.focus(let session), .shortBreak), (.focus(let session), .longBreak):
            return session
        case (.shortBreak(let after), .focus):
            return after
        case (.longBreak, .idle):
            return 1
        default:
            return 0
        }
    }
}

@MainActor
final class FloatingCountdownWindowController: NSWindowController {

    private let stateMachine: PomodoroStateMachine

    init(stateMachine: PomodoroStateMachine) {
        self.stateMachine = stateMachine

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 80, height: 36),
            styleMask: [.nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.isMovableByWindowBackground = true
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.hasShadow = false

        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        let hostingView = NSHostingView(rootView: FloatingCountdownView(
            stateMachine: stateMachine,
            sessionStore: stateMachine.sessionStore
        ))
        panel.contentView = hostingView

        super.init(window: panel)

        positionWindow(panel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func positionWindow(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }

        window.setFrameAutosaveName("dango.floatingCountdown.v2")

        if UserDefaults.standard.string(forKey: "NSWindow Frame dango.floatingCountdown.v2") == nil {
            let visibleFrame = screen.visibleFrame
            let frame = window.frame
            let x = visibleFrame.maxX - frame.width - 20
            let y = visibleFrame.maxY - 20
            window.setFrameTopLeftPoint(NSPoint(x: x, y: y))
        }
    }

    func updateVisibility() {
        guard let panel = window else { return }
        let shouldShow = stateMachine.timerState == .running && stateMachine.sessionStore.showFloatingCountdown

        if shouldShow {
            panel.ignoresMouseEvents = false
            panel.orderFrontRegardless()
        } else {
            panel.ignoresMouseEvents = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self = self else { return }
                let stillShouldShow = self.stateMachine.timerState == .running && self.stateMachine.sessionStore.showFloatingCountdown
                if !stillShouldShow && panel.isVisible {
                    panel.orderOut(nil)
                }
            }
        }
    }
}

struct FloatingCountdownView: View {
    @ObservedObject var stateMachine: PomodoroStateMachine
    @ObservedObject var sessionStore: SessionStore

    private var shouldShow: Bool {
        stateMachine.timerState == .running && sessionStore.showFloatingCountdown
    }

    var body: some View {
        ZStack {
            Color.clear.frame(minWidth: 85, minHeight: 36)

            if shouldShow {
                Text(stateMachine.formattedRemainingTime)
                    .font(.system(size: 20, weight: .medium, design: .default))
                    .monospacedDigit()
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        VisualEffectView(material: .hudWindow, blendingMode: .behindWindow, state: .active)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.92, anchor: .center).combined(with: .opacity),
                        removal: .scale(scale: 0.92, anchor: .center).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75, blendDuration: 0), value: shouldShow)
    }
}
