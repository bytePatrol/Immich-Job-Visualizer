//
//  AnalyticsView.swift
//  Analytics and insights with charts and performance profiling
//

import SwiftUI
import Charts

struct AnalyticsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = AnalyticsViewModel()
    @State private var selectedTimeRange: TimeRange = .day
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Time range picker
                Picker("Time Range", selection: $selectedTimeRange) {
                    Text("24 Hours").tag(TimeRange.day)
                    Text("7 Days").tag(TimeRange.week)
                    Text("30 Days").tag(TimeRange.month)
                }
                .pickerStyle(.segmented)
                .frame(width: 400)
                .padding(.top)
                
                // Job Timeline (Gantt Chart)
                JobTimelineChart(jobs: viewModel.recentJobs)
                    .frame(height: 200)
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                    .padding(.horizontal)
                
                // Performance Profiling
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Average Processing Time by Queue")
                            .font(.headline)
                        
                        ProcessingTimeChart(profiles: viewModel.performanceProfiles)
                            .frame(height: 250)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("File Type Performance")
                            .font(.headline)
                        
                        FileTypePerformanceChart(profiles: viewModel.fileTypeProfiles)
                            .frame(height: 250)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Resource Correlation
                ResourceCorrelationChart(
                    cpuMetrics: viewModel.cpuMetrics,
                    memoryMetrics: viewModel.memoryMetrics,
                    completionMetrics: viewModel.completionMetrics
                )
                .frame(height: 300)
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Historical Trends
                HStack(spacing: 16) {
                    TrendChart(
                        title: "Queue Depth Trend",
                        metrics: viewModel.queueDepthTrend,
                        color: .blue
                    )
                    
                    TrendChart(
                        title: "Completion Rate Trend",
                        metrics: viewModel.completionRateTrend,
                        color: .green
                    )
                    
                    TrendChart(
                        title: "Error Rate Trend",
                        metrics: viewModel.errorRateTrend,
                        color: .red
                    )
                }
                .padding(.horizontal)
                
                // Outlier Detection
                OutlierDetectionView(outliers: viewModel.outlierJobs)
                    .padding(.horizontal)
                
                // Predictive Analytics
                PredictiveAnalyticsCard(
                    estimatedCompletion: viewModel.estimatedCompletionTime,
                    remainingJobs: viewModel.remainingJobs
                )
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Analytics & Insights")
        .onAppear {
            viewModel.loadAnalytics(appState: appState, timeRange: selectedTimeRange)
        }
        .onChange(of: selectedTimeRange) { newValue in
            viewModel.loadAnalytics(appState: appState, timeRange: newValue)
        }
    }
}

enum TimeRange {
    case day, week, month
    
    var duration: TimeInterval {
        switch self {
        case .day: return 86400
        case .week: return 604800
        case .month: return 2592000
        }
    }
}

// MARK: - Job Timeline Chart
struct JobTimelineChart: View {
    let jobs: [Job]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Job Timeline (Last 24 Hours)")
                .font(.headline)
            
            if jobs.isEmpty {
                Text("No jobs to display")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Simplified timeline visualization
                Chart(jobs) { job in
                    if let startedAt = job.startedAt, let completedAt = job.completedAt {
                        RectangleMark(
                            xStart: .value("Start", startedAt),
                            xEnd: .value("End", completedAt),
                            y: .value("Queue", job.queueName)
                        )
                        .foregroundStyle(by: .value("Status", job.status.displayName))
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Processing Time Chart
struct ProcessingTimeChart: View {
    let profiles: [PerformanceProfile]
    
    var body: some View {
        if profiles.isEmpty {
            Text("No data available")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart(profiles) { profile in
                BarMark(
                    x: .value("Time", profile.averageTime),
                    y: .value("Queue", profile.jobType.displayName)
                )
                .foregroundStyle(.blue)
            }
            .chartXAxis {
                AxisMarks(position: .bottom) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let seconds = value.as(Double.self) {
                            Text("\(Int(seconds))s")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - File Type Performance Chart
struct FileTypePerformanceChart: View {
    let profiles: [PerformanceProfile]
    
    var body: some View {
        if profiles.isEmpty {
            Text("No data available")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart(profiles) { profile in
                BarMark(
                    x: .value("Time", profile.averageTime),
                    y: .value("Type", profile.fileType ?? "Unknown")
                )
                .foregroundStyle(.purple)
            }
        }
    }
}

// MARK: - Resource Correlation Chart
struct ResourceCorrelationChart: View {
    let cpuMetrics: [HistoricalMetric]
    let memoryMetrics: [HistoricalMetric]
    let completionMetrics: [HistoricalMetric]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Resource Usage vs Job Completion")
                .font(.headline)
            
            Chart {
                ForEach(cpuMetrics) { metric in
                    LineMark(
                        x: .value("Time", metric.timestamp),
                        y: .value("CPU %", metric.value)
                    )
                    .foregroundStyle(.blue)
                }
                
                ForEach(memoryMetrics) { metric in
                    LineMark(
                        x: .value("Time", metric.timestamp),
                        y: .value("Memory %", metric.value)
                    )
                    .foregroundStyle(.purple)
                }
                
                ForEach(completionMetrics) { metric in
                    LineMark(
                        x: .value("Time", metric.timestamp),
                        y: .value("Jobs/min", metric.value)
                    )
                    .foregroundStyle(.green)
                }
            }
        }
        .padding()
    }
}

// MARK: - Trend Chart
struct TrendChart: View {
    let title: String
    let metrics: [HistoricalMetric]
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            
            if metrics.isEmpty {
                Text("No data")
                    .foregroundColor(.secondary)
                    .frame(maxHeight: .infinity)
            } else {
                Chart(metrics) { metric in
                    LineMark(
                        x: .value("Time", metric.timestamp),
                        y: .value("Value", metric.value)
                    )
                    .foregroundStyle(color)
                    .interpolationMethod(.catmullRom)
                }
                .frame(height: 150)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Outlier Detection
struct OutlierDetectionView: View {
    let outliers: [Job]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Outlier Jobs (3x+ Slower Than Average)")
                .font(.headline)
            
            if outliers.isEmpty {
                Text("No outliers detected")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(outliers) { job in
                    OutlierJobRow(job: job)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct OutlierJobRow: View {
    let job: Job
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(job.assetName ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(job.queueName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let duration = job.duration {
                Text(formatDuration(duration))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(6)
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 60 {
            return String(format: "%.1fs", duration)
        } else {
            return String(format: "%.1fm", duration / 60)
        }
    }
}

// MARK: - Predictive Analytics
struct PredictiveAnalyticsCard: View {
    let estimatedCompletion: Date?
    let remainingJobs: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Predictive Analytics")
                    .font(.headline)
            }
            
            Divider()
            
            HStack(spacing: 40) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Remaining Jobs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(remainingJobs)")
                        .font(.title)
                        .fontWeight(.bold)
                }
                
                if let completion = estimatedCompletion {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Estimated Completion")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(completion, style: .relative)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - View Model
@MainActor
class AnalyticsViewModel: ObservableObject {
    @Published var recentJobs: [Job] = []
    @Published var performanceProfiles: [PerformanceProfile] = []
    @Published var fileTypeProfiles: [PerformanceProfile] = []
    @Published var cpuMetrics: [HistoricalMetric] = []
    @Published var memoryMetrics: [HistoricalMetric] = []
    @Published var completionMetrics: [HistoricalMetric] = []
    @Published var queueDepthTrend: [HistoricalMetric] = []
    @Published var completionRateTrend: [HistoricalMetric] = []
    @Published var errorRateTrend: [HistoricalMetric] = []
    @Published var outlierJobs: [Job] = []
    @Published var estimatedCompletionTime: Date?
    @Published var remainingJobs: Int = 0
    
    func loadAnalytics(appState: AppState, timeRange: TimeRange) {
        let since = Date().addingTimeInterval(-timeRange.duration)
        
        // Load recent jobs
        recentJobs = appState.immichService.currentJobs
            .filter { $0.completedAt ?? Date() > since }
        
        // Load performance profiles
        performanceProfiles = appState.databaseManager.fetchPerformanceProfiles(since: since)
        fileTypeProfiles = performanceProfiles.filter { $0.fileType != nil }
        
        // Load metrics
        cpuMetrics = appState.databaseManager.fetchMetrics(type: .cpuUsage, since: since)
        memoryMetrics = appState.databaseManager.fetchMetrics(type: .memoryUsage, since: since)
        completionMetrics = appState.databaseManager.fetchMetrics(type: .completionRate, since: since)
        queueDepthTrend = appState.databaseManager.fetchMetrics(type: .queueDepth, since: since)
        completionRateTrend = appState.databaseManager.fetchMetrics(type: .completionRate, since: since)
        errorRateTrend = appState.databaseManager.fetchMetrics(type: .errorRate, since: since)
        
        // Detect outliers
        detectOutliers(appState: appState)
        
        // Calculate predictions
        calculatePredictions(appState: appState)
    }
    
    private func detectOutliers(appState: AppState) {
        let completedJobs = appState.immichService.currentJobs.filter { $0.isCompleted }
        
        // Calculate average processing time per queue
        var queueAverages: [String: TimeInterval] = [:]
        for job in completedJobs {
            if let duration = job.duration {
                queueAverages[job.queueName, default: 0] += duration
            }
        }
        
        for (queue, total) in queueAverages {
            let count = completedJobs.filter { $0.queueName == queue }.count
            queueAverages[queue] = total / Double(count)
        }
        
        // Find outliers (3x+ average)
        outlierJobs = completedJobs.filter { job in
            guard let duration = job.duration,
                  let average = queueAverages[job.queueName] else { return false }
            return duration > average * 3
        }
    }
    
    private func calculatePredictions(appState: AppState) {
        remainingJobs = appState.immichService.getTotalQueuedCount()
        
        // Calculate average processing rate
        if let rate = appState.serverStats?.averageProcessingRate, rate > 0 {
            let remainingMinutes = Double(remainingJobs) / rate
            estimatedCompletionTime = Date().addingTimeInterval(remainingMinutes * 60)
        }
    }
}
