//
//  AnalyticsView.swift
//  Analytics and insights with charts and performance data
//

import SwiftUI
import Charts

struct AnalyticsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 16) {
                    // Predictive Analytics Card
                    PredictiveAnalyticsCard(
                        remainingJobs: appState.immichService.getTotalQueuedCount(),
                        estimatedCompletion: calculateEstimatedCompletion(),
                        processingRate: appState.serverStats?.averageProcessingRate ?? 0
                    )
                    .frame(maxWidth: .infinity)

                    // Processing Rate Chart
                    ProcessingRateAnalyticsChart(
                        metrics: appState.immichService.processingRateHistory
                    )
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 250, maxHeight: geometry.size.height * 0.35)

                    // Queue Overview
                    QueueOverviewCard(queues: appState.immichService.queues)
                        .frame(maxWidth: .infinity)

                    // Session Statistics
                    SessionStatsCard(
                        completedJobs: appState.serverStats?.jobsProcessedToday ?? 0,
                        failedJobs: appState.serverStats?.jobsFailedToday ?? 0,
                        activeWorkers: appState.serverStats?.activeWorkers ?? 0
                    )
                    .frame(maxWidth: .infinity)
                }
                .padding()
            }
        }
        .navigationTitle("Analytics & Insights")
    }

    private func calculateEstimatedCompletion() -> Date? {
        let remaining = appState.immichService.getTotalQueuedCount()
        guard let rate = appState.serverStats?.averageProcessingRate, rate > 0, remaining > 0 else {
            return nil
        }
        let remainingMinutes = Double(remaining) / rate
        return Date().addingTimeInterval(remainingMinutes * 60)
    }
}

// MARK: - Predictive Analytics Card
struct PredictiveAnalyticsCard: View {
    let remainingJobs: Int
    let estimatedCompletion: Date?
    let processingRate: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("Predictions & Estimates")
                    .font(.headline)
                Spacer()
            }

            Divider()

            HStack(spacing: 0) {
                // Remaining Jobs
                VStack(spacing: 8) {
                    Text("\(remainingJobs)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("Remaining Jobs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 50)

                // Processing Rate
                VStack(spacing: 8) {
                    Text(String(format: "%.1f", processingRate))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    Text("Jobs/Minute")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 50)

                // Estimated Completion
                VStack(spacing: 8) {
                    if let completion = estimatedCompletion {
                        Text(completion, style: .relative)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                    } else {
                        Text("--")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    Text("Est. Completion")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Processing Rate Chart
struct ProcessingRateAnalyticsChart: View {
    let metrics: [(timestamp: Date, rate: Double)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "speedometer")
                    .foregroundColor(.blue)
                Text("Processing Rate Over Time")
                    .font(.headline)
                Spacer()
                if !metrics.isEmpty {
                    Text("\(metrics.count) data points")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if metrics.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Processing rate data will appear here as jobs complete")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Chart {
                    ForEach(Array(metrics.enumerated()), id: \.offset) { index, item in
                        LineMark(
                            x: .value("Time", item.timestamp),
                            y: .value("Rate", item.rate)
                        )
                        .foregroundStyle(.blue)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Time", item.timestamp),
                            y: .value("Rate", item.rate)
                        )
                        .foregroundStyle(.blue.opacity(0.1))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.hour().minute())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let rate = value.as(Double.self) {
                                Text("\(Int(rate))")
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Queue Overview Card
struct QueueOverviewCard: View {
    let queues: [Queue]

    private var activeQueues: [Queue] {
        queues.filter { $0.count > 0 || $0.activeCount > 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundColor(.purple)
                Text("Queue Overview")
                    .font(.headline)
                Spacer()
                Text("\(activeQueues.count) active")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            if activeQueues.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.title)
                            .foregroundColor(.green)
                        Text("All queues are empty")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    Spacer()
                }
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(activeQueues) { queue in
                        QueueMiniCard(queue: queue)
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct QueueMiniCard: View {
    let queue: Queue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(queue.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)

            HStack {
                Label("\(queue.activeCount)", systemImage: "bolt.fill")
                    .font(.caption)
                    .foregroundColor(.blue)

                Spacer()

                Label("\(queue.count)", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.orange)

                if queue.failedCount > 0 {
                    Spacer()
                    Label("\(queue.failedCount)", systemImage: "xmark.circle")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            if queue.count > 0 {
                ProgressView(value: Double(queue.activeCount), total: Double(max(queue.count, 1)))
                    .tint(.blue)
            }
        }
        .padding(12)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Session Stats Card
struct SessionStatsCard: View {
    let completedJobs: Int
    let failedJobs: Int
    let activeWorkers: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.badge.checkmark")
                    .foregroundColor(.green)
                Text("Session Statistics")
                    .font(.headline)
                Spacer()
                Text("Since app started")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            HStack(spacing: 0) {
                AnalyticsStatItem(
                    value: "\(completedJobs)",
                    label: "Completed",
                    color: .green,
                    icon: "checkmark.circle.fill"
                )
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 40)

                AnalyticsStatItem(
                    value: "\(failedJobs)",
                    label: "Failed",
                    color: .red,
                    icon: "xmark.circle.fill"
                )
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 40)

                AnalyticsStatItem(
                    value: "\(activeWorkers)",
                    label: "Active Workers",
                    color: .blue,
                    icon: "person.3.fill"
                )
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct AnalyticsStatItem: View {
    let value: String
    let label: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
