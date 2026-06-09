import SwiftUI

struct DangoVisualizerSection: View {

    @ObservedObject var stateMachine: PomodoroStateMachine

    var body: some View {
        VStack(spacing: 12) {
            DangoVisualizerView(stateMachine: stateMachine)
                .frame(height: 80)

            if !stateMachine.sessionStore.showFloatingCountdown {
                Text(stateMachine.formattedRemainingTime)
                    .font(.system(size: 28, weight: .semibold, design: .default))
                    .monospacedDigit()
                    .foregroundColor(.primary)
                    .contentTransition(.numericText())
                    .transition(.opacity)
            }

            Text(stateDisplayText)
                .font(.system(.title3, design: .default, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.2), value: stateMachine.phase)
        }
        .padding(.top, 20)
        .padding(.bottom, 20)
        .padding(.horizontal, 16)
        .animation(.easeInOut(duration: 0.2), value: stateMachine.sessionStore.showFloatingCountdown)
    }

    // MARK: - State Display

    private var stateDisplayText: String {
        switch (stateMachine.phase, stateMachine.timerState) {
        case (.idle, _):
            return "Ready"
        case (_, .paused), (_, .stopped):
            return "Paused"
        case (.focus, _):
            return "Focusing"
        case (.shortBreak, _):
            return "Short Break"
        case (.longBreak, _):
            return "Long Break"
        }
    }
}
