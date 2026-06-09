import SwiftUI

struct ActionRowView: View {

    @ObservedObject var stateMachine: PomodoroStateMachine
    @Binding var showSettings: Bool
    @Binding var showStats: Bool

    @State private var showingResetConfirmation = false

    var body: some View {
        HStack(spacing: 14) {
            Button {
                stateMachine.toggle()
            } label: {
                Image(systemName: playPauseIcon)
                    .contentTransition(.symbolEffect(.replace))
            }

            Button {
                stateMachine.skip()
            } label: {
                Image(systemName: "forward.end")
            }
            .disabled(stateMachine.phase == .idle)

            Button {
                stateMachine.resetCurrentPhase()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(stateMachine.phase == .idle)

            Spacer()

            Button {
                showingResetConfirmation = true
            } label: {
                Image(systemName: "trash")
            }
            .padding(.trailing, 4)
            .disabled(stateMachine.phase == .idle)

            Button {
                withAnimation(.easeInOut(duration: 0.28)) {
                    if showSettings { showSettings = false }
                    showStats.toggle()
                }
            } label: {
                Image(systemName: "chart.bar")
                    .foregroundStyle(showStats ? .primary : .secondary)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.28)) {
                    if showStats { showStats = false }
                    showSettings.toggle()
                }
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(showSettings ? .primary : .secondary)
            }
        }
        .buttonStyle(.borderless)
        .font(.system(size: 14, weight: .regular))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .alert("Clear Current Roll?", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                stateMachine.reset()
            }
        } message: {
            Text("This stops the timer and clears progress on the current roll. Your statistics won't be affected.")
        }
        .onReceive(NotificationCenter.default.publisher(for: .dangoExternalDismissal)) { _ in
            showingResetConfirmation = false
        }
    }

    // MARK: - Helpers

    private var playPauseIcon: String {
        switch stateMachine.timerState {
        case .running: return "pause"
        case .paused: return "play"
        case .stopped: return "play"
        }
    }
}
