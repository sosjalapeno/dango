import AppKit
import SwiftUI
import Combine

extension Notification.Name {
    static let dangoExternalDismissal = Notification.Name("dangoExternalDismissal")
}

@MainActor
final class StatusItemController: NSObject {

    // MARK: - Properties

    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var hostingController: NSHostingController<PopoverContentView>!
    private let stateMachine: PomodoroStateMachine
    private let iconRenderer = IconRenderer()
    private var cancellables = Set<AnyCancellable>()
    private var keyResignObserver: NSObjectProtocol?

    private let popoverWidth: CGFloat = 280

    // MARK: - Initialization

    init(stateMachine: PomodoroStateMachine) {
        self.stateMachine = stateMachine
        super.init()
    }

    // MARK: - Setup

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem.button else {
            fatalError("[Dango] Failed to access NSStatusBarButton")
        }

        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.action = #selector(handleClick(_:))
        button.target = self

        hostingController = NSHostingController(rootView: makePopoverContentView())
        hostingController.sizingOptions = [.intrinsicContentSize]
        popover.contentViewController = hostingController
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        stateMachine.onStateChange = { [weak self] in
            self?.updateIcon()
            self?.updateAccessibilityLabel()
        }

        stateMachine.$progress
            .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                self?.updateIcon()
            }
            .store(in: &cancellables)

        updateIcon()
        updateAccessibilityLabel()
    }

    // MARK: - Click Handling

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        let isRightClick = event.type == .rightMouseUp
        let popoverButtonIsLeft = stateMachine.sessionStore.leftClickOpensPopover

        if isRightClick == popoverButtonIsLeft {
            toggleTimer()
        } else {
            togglePopover(sender)
        }
    }

    private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            openPopover(sender)
        }
    }

    private func toggleTimer() {
        stateMachine.toggle()
        HapticFeedbackService.tick()
    }

    // MARK: - Popover Management

    private func openPopover(_ sender: NSStatusBarButton) {
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        syncPopoverSizeFromHostingView()

        NSApp.activate(ignoringOtherApps: true)
        hostingController.view.window?.makeKeyAndOrderFront(nil)

        installKeyResignObserver()
    }

    private func makePopoverContentView() -> PopoverContentView {
        PopoverContentView(
            stateMachine: stateMachine,
            updateManager: UpdateManager.shared
        ) { [weak self] height in
            self?.updatePopoverSize(height: height)
        }
    }

    private func closePopoverIfNeeded() {
        guard popover.isShown else { return }
        popover.performClose(nil)
    }

    private func installKeyResignObserver() {
        removeKeyResignObserver()

        keyResignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }

                if NSApp.keyWindow != nil {
                    return
                }

                NotificationCenter.default.post(name: .dangoExternalDismissal, object: nil)

                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        self.closePopoverIfNeeded()
                    }
                }
            }
        }
    }

    private func removeKeyResignObserver() {
        if let keyResignObserver {
            NotificationCenter.default.removeObserver(keyResignObserver)
            self.keyResignObserver = nil
        }
    }

    private func updatePopoverSize(height: CGFloat) {
        guard height > 0 else { return }
        popover.contentSize = NSSize(width: popoverWidth, height: height)
    }

    private func syncPopoverSizeFromHostingView() {
        hostingController.view.layoutSubtreeIfNeeded()
        let height = hostingController.view.fittingSize.height
        updatePopoverSize(height: height)
    }

    // MARK: - Icon Updates

    private func updateIcon() {
        let image = iconRenderer.render(stateMachine: stateMachine)
        statusItem.button?.image = image
    }

    // MARK: - Accessibility

    private func updateAccessibilityLabel() {
        statusItem.button?.setAccessibilityLabel(stateMachine.accessibilityLabel)
    }
}

extension StatusItemController: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        removeKeyResignObserver()
    }
}
