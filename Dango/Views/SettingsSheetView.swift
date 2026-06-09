import SwiftUI
import AppKit

struct SettingsSheetView: View {

    enum SettingsFocusField: Hashable {
        case focusSession, shortBreak, longBreak
    }

    @ObservedObject var store: SessionStore
    @ObservedObject var updateManager: UpdateManager
    @Binding var isPresented: Bool

    @FocusState private var focusedField: SettingsFocusField?

    @State private var showingClearTodayConfirmation = false
    @State private var showingClearAllConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.headline)
                .fontWeight(.semibold)

            Toggle("Launch at Login", isOn: $store.launchAtLogin)
                .onChange(of: store.launchAtLogin) { _, newValue in
                    LoginItemService.shared.setEnabled(newValue)
                }

            Toggle("Auditory Feedback", isOn: $store.audioEnabled)

            Toggle("Auto-Advance Phases", isOn: $store.autoAdvance)

            Toggle("Floating Countdown", isOn: $store.showFloatingCountdown)

            Toggle("Left-Click Opens Panel", isOn: $store.leftClickOpensPopover)

            Divider()

            Text("Timer Durations")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            DurationField(
                label: "Focus Session",
                value: $store.focusDuration,
                focusValue: .focusSession,
                focusedField: $focusedField
            )
            DurationField(
                label: "Short Break",
                value: $store.shortBreakDuration,
                focusValue: .shortBreak,
                focusedField: $focusedField
            )
            DurationField(
                label: "Long Break",
                value: $store.longBreakDuration,
                focusValue: .longBreak,
                focusedField: $focusedField
            )

            Divider()
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 12) {
                Text("Data & Updates")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 2)

                HStack {
                    Text("App Updates")

                    Spacer()

                    Button {
                        if updateManager.updateAvailable, let url = updateManager.releaseURL {
                            NSWorkspace.shared.open(url)
                        } else {
                            Task { await updateManager.checkForUpdates() }
                        }
                    } label: {
                        if updateManager.isChecking {
                            Text("Checking...")
                        } else if updateManager.updateAvailable {
                            Text("Download Latest")
                        } else {
                            Text("Check for Updates")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(updateManager.isChecking)
                }

                Button(action: { showingClearTodayConfirmation = true }) {
                    Text("Clear Today's Stats")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)

                Button(action: { showingClearAllConfirmation = true }) {
                    Text("Clear All Stats")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 8)

            HStack(spacing: 12) {
                Button(action: showSupportAlert) {
                    Text("🍡 Buy me a Dango")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button("Done") {
                    store.commitAndReinitialize()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isPresented = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
            }
        }
        .onAppear {
            focusedField = nil
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 24)
        .frame(width: 280)
        .alert("Clear Today?", isPresented: $showingClearTodayConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                store.clearTodayStats()
            }
        } message: {
            Text("Today's progress will be removed.")
        }
        .alert("Clear All?", isPresented: $showingClearAllConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                store.clearAllStats()
            }
        } message: {
            Text("All progress will be removed.")
        }
        .onReceive(NotificationCenter.default.publisher(for: .dangoExternalDismissal)) { _ in
            showingClearTodayConfirmation = false
            showingClearAllConfirmation = false
        }
    }

    private func showSupportAlert() {
        let alert = NSAlert()
        alert.messageText = "Buy me a Dango 🍡"
        alert.informativeText = """
        This app is free and open source, and always will be.

        If it's made your focus a little sweeter, you can buy me a dango as a thank-you. I'll put the funds toward shipping Dango to the App Store.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Support")
        alert.addButton(withTitle: "No thanks")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn,
           let url = URL(string: "https://buymeacoffee.com/sosjalapeno") {
            NSWorkspace.shared.open(url)
        }
    }
}
