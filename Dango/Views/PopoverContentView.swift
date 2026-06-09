import SwiftUI

private struct PopoverHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct PopoverContentView: View {

    @ObservedObject var stateMachine: PomodoroStateMachine
    @ObservedObject var updateManager: UpdateManager
    var onHeightChange: ((CGFloat) -> Void)?

    @State private var showSettings = false
    @State private var showStats = false

    init(
        stateMachine: PomodoroStateMachine,
        updateManager: UpdateManager,
        onHeightChange: ((CGFloat) -> Void)? = nil
    ) {
        self.stateMachine = stateMachine
        self.updateManager = updateManager
        self.onHeightChange = onHeightChange
    }

    var body: some View {
        VStack(spacing: 0) {
            if showSettings {
                SettingsSheetView(
                    store: stateMachine.sessionStore,
                    updateManager: updateManager,
                    isPresented: $showSettings
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                primaryLayout
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .frame(width: 280)
        .background(
            GeometryReader { geometry in
                Color.clear.preference(key: PopoverHeightKey.self, value: geometry.size.height)
            }
        )
        .onPreferenceChange(PopoverHeightKey.self) { height in
            guard height > 0 else { return }
            onHeightChange?(height)
        }
    }

    private var primaryLayout: some View {
        VStack(spacing: 0) {
            DangoVisualizerSection(stateMachine: stateMachine)

            Divider()
                .opacity(0.15)
                .padding(.horizontal, 16)

            ActionRowView(
                stateMachine: stateMachine,
                showSettings: $showSettings,
                showStats: $showStats
            )

            if showStats {
                statsDrawer
            }
        }
        .animation(.easeInOut(duration: 0.28), value: showStats)
    }

    private var statsDrawer: some View {
        Group {
            Divider()
                .opacity(0.15)
                .padding(.horizontal, 16)

            StatsView(
                todayStats: stateMachine.todayStats,
                allTimeStats: stateMachine.allTimeStats,
                inFlightFocusSeconds: stateMachine.inFlightFocusSeconds
            )
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
        }
        .clipped()
    }
}
