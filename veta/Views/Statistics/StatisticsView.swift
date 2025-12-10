import SwiftUI
import SwiftData

struct StatisticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]
    @State private var statistics: ReviewStatistics?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let stats = statistics {
                        // Daily Progress - Blue gradient card
                        VStack(spacing: 16) {
                            HStack {
                                Image(systemName: "target")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                                Text("Today's Progress")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Spacer()
                            }

                            HStack(alignment: .lastTextBaseline, spacing: 8) {
                                Text("\(stats.reviewedToday)")
                                    .font(.system(size: 56, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("/ \(stats.dailyGoal)")
                                    .font(.title)
                                    .foregroundStyle(.white.opacity(0.7))
                            }

                            ProgressView(value: stats.dailyProgress)
                                .tint(.white)
                                .background(Color.white.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)

                        // Streak - Orange gradient card
                        VStack(spacing: 16) {
                            HStack {
                                Image(systemName: "flame.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                                Text("Current Streak")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Spacer()
                            }

                            VStack(spacing: 4) {
                                Text("\(stats.currentStreak)")
                                    .font(.system(size: 56, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("days in a row")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                colors: [Color.orange, Color.orange.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)

                        // Overview - Enhanced card
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Overview")
                                .font(.title3)
                                .fontWeight(.semibold)

                            VStack(spacing: 14) {
                                StatRow(
                                    title: "Total Sections",
                                    value: "\(stats.totalSections)",
                                    icon: "square.grid.2x2",
                                    color: .purple
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
                            }

                            Divider()
                                .padding(.vertical, 4)

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Overall Progress")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text("\(Int(stats.progress * 100))%")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.green)
                                }

                                ProgressView(value: stats.progress)
                                    .tint(.green)
                                    .scaleEffect(x: 1, y: 1.5, anchor: .center)
                            }
                        }
                        .padding(20)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
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
            .onChange(of: settings) { _, _ in
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
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(color)
            }

            Text(title)
                .font(.subheadline)

            Spacer()

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
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
