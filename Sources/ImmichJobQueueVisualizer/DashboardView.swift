//
//  DashboardView.swift
//  Main dashboard with real-time stats and monitoring
//

import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = DashboardViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Connection Status Header
                ConnectionStatusBar(
                    isConnected: appState.isConnected,
                    serverURL: appState.immichService.serverURL,
                    lastUpdate: appState.lastUpdateTime
                )
                
                // Stats Cards Row
                HStack(spacing: 15) {
                    StatCard(
                        title: "Active Jobs",
                        value: "\(appState.immichService.getActiveJobs().count)",
                        icon: "bolt.circle.fill",
                        color: .blue
                    )
                    
                    StatCard(
                        title: "Queued Count",
                        value: "\(appState.immichService.getTotalQueuedCount())",
                        icon: "tray.full.fill",
                        color: .orange
                    )
                    
                    StatCard(
                        title: "Completed",
                        value: "\(appState.serverStats?.jobsProcessedToday ?? 0)",
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                    
                    StatCard(
                        title: "Failed Jobs",
                        value: "\(appState.immichService.getFailedJobs().count)",
                        icon: "xmark.circle.fill",
                        color: .red
                    )
                }
                .padding(.horizontal)
                
                // Processing Rate Graph
                ProcessingRateChart(metrics: viewModel.processingRateMetrics)
                    .frame(height: 250)
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                    .padding(.horizontal)
                
                // Processing Stats
                HStack(spacing: 15) {
                    ResourceMonitor(
                        title: "Active Workers",
                        value: Double(appState.serverStats?.activeWorkers ?? 0),
                        unit: "",
                        icon: "person.3.fill",
                        color: .blue,
                        maxValue: max(Double(appState.serverStats?.activeWorkers ?? 1), 10)
                    )

                    ResourceMonitor(
                        title: "Processing Rate",
                        value: appState.serverStats?.averageProcessingRate ?? 0,
                        unit: "/min",
                        icon: "speedometer",
                        color: .green,
                        maxValue: max((appState.serverStats?.averageProcessingRate ?? 0) * 1.5, 10)
                    )

                    ResourceMonitor(
                        title: "Completed Total",
                        value: Double(appState.serverStats?.jobsProcessedToday ?? 0),
                        unit: "",
                        icon: "checkmark.circle",
                        color: .purple,
                        maxValue: max(Double(appState.serverStats?.jobsProcessedToday ?? 1), 100)
                    )
                }
                .padding(.horizontal)
                
                // Quick Actions
                QuickActionsBar()
                    .padding(.horizontal)
                
                // Live Processing Jobs
                LiveJobsListView(jobs: appState.immichService.getActiveJobs())
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Dashboard")
        .onAppear {
            viewModel.startMonitoring(appState: appState)
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }
}

// MARK: - Connection Status Bar
struct ConnectionStatusBar: View {
    let isConnected: Bool
    let serverURL: String
    let lastUpdate: Date?
    
    var body: some View {
        HStack {
            Circle()
                .fill(isConnected ? Color.green : Color.red)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(isConnected ? "Connected" : "Disconnected")
                    .font(.headline)
                
                Text(serverURL)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let lastUpdate = lastUpdate {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Last Updated")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(lastUpdate, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 32, weight: .bold))
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Processing Rate Chart
struct ProcessingRateChart: View {
    let metrics: [ProcessingRateMetric]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Processing Rate (jobs/minute)")
                .font(.headline)
            
            if metrics.isEmpty {
                Text("No data available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Chart(metrics) { metric in
                    LineMark(
                        x: .value("Time", metric.timestamp),
                        y: .value("Rate", metric.rate)
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)
                    
                    AreaMark(
                        x: .value("Time", metric.timestamp),
                        y: .value("Rate", metric.rate)
                    )
                    .foregroundStyle(.blue.opacity(0.1))
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .minute, count: 10)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.hour().minute())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
        .padding()
    }
}

struct ProcessingRateMetric: Identifiable {
    let id = UUID()
    let timestamp: Date
    let rate: Double
}

// MARK: - Resource Monitor
struct ResourceMonitor: View {
    let title: String
    let value: Double
    let unit: String
    let icon: String
    let color: Color
    var maxValue: Double = 100

    var displayValue: String {
        if unit == "/min" {
            return String(format: "%.1f%@", value, unit)
        } else {
            return "\(Int(value))\(unit)"
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
                Text(displayValue)
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            ProgressView(value: min(value, maxValue), total: maxValue)
                .tint(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Quick Actions Bar
struct QuickActionsBar: View {
    @EnvironmentObject var appState: AppState
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        HStack(spacing: 12) {
            ActionButton(
                title: "Pause All",
                icon: "pause.circle.fill",
                color: .orange
            ) {
                Task {
                    await appState.immichService.pauseAllQueues()
                    alertMessage = "All queues paused"
                    showingAlert = true
                }
            }
            
            ActionButton(
                title: "Resume All",
                icon: "play.circle.fill",
                color: .green
            ) {
                Task {
                    await appState.immichService.resumeAllQueues()
                    alertMessage = "All queues resumed"
                    showingAlert = true
                }
            }
            
            ActionButton(
                title: "Clear Completed",
                icon: "trash.circle.fill",
                color: .blue
            ) {
                Task {
                    await appState.immichService.clearCompletedJobs()
                    alertMessage = "Completed jobs cleared"
                    showingAlert = true
                }
            }
            
            ActionButton(
                title: "Retry Failed",
                icon: "arrow.clockwise.circle.fill",
                color: .red
            ) {
                Task {
                    await appState.immichService.retryFailedJobs()
                    alertMessage = "Failed jobs queued for retry"
                    showingAlert = true
                }
            }
        }
        .alert("Action Completed", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Live Jobs List
struct LiveJobsListView: View {
    let jobs: [Job]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Currently Processing (\(jobs.count))")
                .font(.headline)
            
            if jobs.isEmpty {
                Text("No active jobs")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
            } else {
                ForEach(jobs.prefix(10)) { job in
                    LiveJobRow(job: job)
                }
            }
        }
    }
}

struct LiveJobRow: View {
    let job: Job
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.assetName ?? "Unknown Asset")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(job.queueName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let workerId = job.workerId {
                    Text("Worker: \(workerId)")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
                
                Text("\(Int(job.progress * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            
            ProgressView(value: job.progress)
                .tint(.blue)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - View Model
@MainActor
class DashboardViewModel: ObservableObject {
    @Published var processingRateMetrics: [ProcessingRateMetric] = []
    private var monitoringTask: Task<Void, Never>?

    func startMonitoring(appState: AppState) {
        monitoringTask = Task {
            while !Task.isCancelled {
                updateProcessingRateMetrics(appState: appState)
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            }
        }
    }

    func stopMonitoring() {
        monitoringTask?.cancel()
    }

    private func updateProcessingRateMetrics(appState: AppState) {
        // Use processing rate history from the service
        processingRateMetrics = appState.immichService.processingRateHistory.map { item in
            ProcessingRateMetric(timestamp: item.timestamp, rate: item.rate)
        }
    }
}
