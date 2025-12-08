import SwiftUI
import SwiftData

struct StatisticsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var statistics: ReviewStatistics?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let stats = statistics {
                        // Daily Progress
                        VStack(spacing: 12) {
                            Text("Today's Progress")
                                .font(.headline)

                            HStack {
                                Text("\(stats.reviewedToday)")
                                    .font(.system(size: 48, weight: .bold))
                                Text("/ \(stats.dailyGoal)")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }

                            ProgressView(value: stats.dailyProgress)
                                .tint(.blue)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        // Streak
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "flame.fill")
                                    .foregroundStyle(.orange)
                                Text("Current Streak")
                                    .font(.headline)
                            }

                            Text("\(stats.currentStreak)")
                                .font(.system(size: 48, weight: .bold))
                            Text("days")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        // Overview
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Overview")
                                .font(.headline)

                            StatRow(
                                title: "Total Sections",
                                value: "\(stats.totalSections)",
                                icon: "square.grid.2x2"
                            )

                            StatRow(
                                title: "Reviewed",
                                value: "\(stats.reviewedSections)",
                                icon: "checkmark.circle.fill",
                                color: .green
                            )

                            StatRow(
                                title: "New",
                                value: "\(stats.newSections)",
                                icon: "plus.circle.fill",
                                color: .blue
                            )

                            Divider()

                            HStack {
                                Text("Progress")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int(stats.progress * 100))%")
                                    .fontWeight(.semibold)
                            }

                            ProgressView(value: stats.progress)
                                .tint(.green)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        ProgressView("Loading statistics...")
                    }
                }
                .padding()
            }
            .navigationTitle("Statistics")
            .onAppear {
                loadStatistics()
            }
        }
    }

    private func loadStatistics() {
        let engine = RepetitionEngine(modelContext: modelContext)
        statistics = engine.getStatistics()
    }
}

struct StatRow: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = .primary

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)

            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.semibold)
        }
    }
}

#Preview {
    StatisticsView()
        .modelContainer(for: [
            MarkdownSection.self,
            RepetitionRecord.self
        ], inMemory: true)
}
