import SwiftUI

struct StatsView: View {

    let todayStats: DailyStats
    let allTimeStats: DailyStats
    var inFlightFocusSeconds: TimeInterval = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            statsSection(title: "Today", stats: todayStats, inFlightFocusSeconds: inFlightFocusSeconds)

            Divider()
                .opacity(0.15)

            statsSection(title: "All Time", stats: allTimeStats, inFlightFocusSeconds: inFlightFocusSeconds)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statsSection(title: String, stats: DailyStats, inFlightFocusSeconds: TimeInterval) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            HStack(spacing: 24) {
                statItem(title: "Rolls", value: "\(stats.rolls)")
                statItem(title: "Dangos", value: "\(stats.dangos)")
                statItem(
                    title: "Focus Time",
                    value: stats.formattedFocusTime(inFlightSeconds: inFlightFocusSeconds)
                )
            }
        }
    }

    private func statItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
