//
//  AdditionalViews.swift
//  Diagnostics, Failed Jobs, Settings, and Menu Bar views
//

import SwiftUI
import UserNotifications

// MARK: - Diagnostics View
struct DiagnosticsView: View {
    @EnvironmentObject var appState: AppState
    @State private var serverVersion: String = "Loading..."
    @State private var apiLatency: Double = 0
    @State private var isTestingLatency = false
    @State private var latencyHistory: [(timestamp: Date, latency: Double)] = []
    @State private var sessionStartTime = Date()
    @State private var refreshTimer: Timer?

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 16) {
                    // Connection & Server Info
                    ConnectionInfoCard(
                        isConnected: appState.isConnected,
                        serverURL: appState.immichService.serverURL,
                        serverVersion: serverVersion,
                        lastUpdate: appState.lastUpdateTime
                    )
                    .frame(maxWidth: .infinity)

                    // API Latency Card
                    APILatencyCard(
                        latency: apiLatency,
                        isTestingLatency: isTestingLatency,
                        latencyHistory: latencyHistory,
                        onRefresh: { await measureLatency() }
                    )
                    .frame(maxWidth: .infinity)

                    // Queue Health Summary
                    QueueHealthCard(queues: appState.immichService.queues)
                        .frame(maxWidth: .infinity)

                    // App Session Info
                    AppSessionCard(
                        sessionStart: sessionStartTime,
                        completedJobs: appState.serverStats?.jobsProcessedToday ?? 0,
                        failedJobs: appState.serverStats?.jobsFailedToday ?? 0,
                        pollingInterval: appState.immichService.pollingInterval
                    )
                    .frame(maxWidth: .infinity)
                }
                .padding()
            }
        }
        .navigationTitle("Diagnostics")
        .task {
            await loadServerInfo()
            await measureLatency()
        }
        .onAppear {
            startPeriodicLatencyCheck()
        }
        .onDisappear {
            refreshTimer?.invalidate()
        }
    }

    private func loadServerInfo() async {
        if let version = await appState.immichService.fetchServerVersion() {
            await MainActor.run {
                serverVersion = version
            }
        } else {
            await MainActor.run {
                serverVersion = appState.isConnected ? "Unknown" : "Not connected"
            }
        }
    }

    private func measureLatency() async {
        await MainActor.run {
            isTestingLatency = true
        }

        let startTime = Date()
        let success = await appState.immichService.testConnection()
        let elapsed = Date().timeIntervalSince(startTime)

        await MainActor.run {
            if success {
                apiLatency = elapsed
                latencyHistory.append((timestamp: Date(), latency: elapsed))
                // Keep last 20 measurements
                if latencyHistory.count > 20 {
                    latencyHistory.removeFirst()
                }
            }
            isTestingLatency = false
        }
    }

    private func startPeriodicLatencyCheck() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task {
                await measureLatency()
            }
        }
    }
}

// MARK: - Connection Info Card
struct ConnectionInfoCard: View {
    let isConnected: Bool
    let serverURL: String
    let serverVersion: String
    let lastUpdate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "server.rack")
                    .font(.title2)
                    .foregroundColor(isConnected ? .green : .red)
                Text("Server Connection")
                    .font(.headline)
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(isConnected ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    Text(isConnected ? "Connected" : "Disconnected")
                        .font(.subheadline)
                        .foregroundColor(isConnected ? .green : .red)
                }
            }

            Divider()

            VStack(spacing: 12) {
                DiagnosticInfoRow(label: "Server URL", value: serverURL.isEmpty ? "Not configured" : serverURL)
                DiagnosticInfoRow(label: "Server Version", value: serverVersion)
                if let lastUpdate = lastUpdate {
                    DiagnosticInfoRow(label: "Last Update", value: lastUpdate.formatted(date: .omitted, time: .standard))
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - API Latency Card
struct APILatencyCard: View {
    let latency: Double
    let isTestingLatency: Bool
    let latencyHistory: [(timestamp: Date, latency: Double)]
    let onRefresh: () async -> Void

    private var latencyMs: Int {
        Int(latency * 1000)
    }

    private var latencyColor: Color {
        if latency < 0.1 { return .green }
        else if latency < 0.3 { return .yellow }
        else if latency < 0.5 { return .orange }
        else { return .red }
    }

    private var latencyStatus: String {
        if latency < 0.1 { return "Excellent" }
        else if latency < 0.3 { return "Good" }
        else if latency < 0.5 { return "Fair" }
        else { return "Poor" }
    }

    private var averageLatency: Double {
        guard !latencyHistory.isEmpty else { return 0 }
        return latencyHistory.reduce(0) { $0 + $1.latency } / Double(latencyHistory.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "network")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("API Latency")
                    .font(.headline)
                Spacer()
                Button(action: {
                    Task { await onRefresh() }
                }) {
                    if isTestingLatency {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.plain)
                .disabled(isTestingLatency)
            }

            Divider()

            HStack(spacing: 0) {
                // Current Latency
                VStack(spacing: 8) {
                    Text("\(latencyMs)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(latencyColor)
                    Text("ms")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 50)

                // Status
                VStack(spacing: 8) {
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(latencyColor.opacity(index < latencyBars ? 1.0 : 0.2))
                                .frame(width: 10, height: 10)
                        }
                    }
                    Text(latencyStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 50)

                // Average
                VStack(spacing: 8) {
                    Text("\(Int(averageLatency * 1000))")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    Text("Avg (ms)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            if !latencyHistory.isEmpty {
                Text("\(latencyHistory.count) measurements")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private var latencyBars: Int {
        if latency < 0.1 { return 3 }
        else if latency < 0.3 { return 2 }
        else { return 1 }
    }
}

// MARK: - Queue Health Card
struct QueueHealthCard: View {
    let queues: [Queue]

    private var totalActive: Int {
        queues.reduce(0) { $0 + $1.activeCount }
    }

    private var totalWaiting: Int {
        queues.reduce(0) { $0 + $1.count - $1.activeCount }
    }

    private var totalFailed: Int {
        queues.reduce(0) { $0 + $1.failedCount }
    }

    private var healthStatus: (color: Color, text: String) {
        if totalFailed > 10 {
            return (.red, "Degraded - High failure rate")
        } else if totalWaiting > 1000 {
            return (.orange, "Busy - Large queue backlog")
        } else if totalActive > 0 {
            return (.blue, "Processing")
        } else if queues.isEmpty {
            return (.secondary, "No data")
        } else {
            return (.green, "Healthy - All queues clear")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "heart.text.square")
                    .font(.title2)
                    .foregroundColor(healthStatus.color)
                Text("Queue Health")
                    .font(.headline)
                Spacer()
                Text(healthStatus.text)
                    .font(.caption)
                    .foregroundColor(healthStatus.color)
            }

            Divider()

            HStack(spacing: 0) {
                VStack(spacing: 8) {
                    Text("\(queues.count)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("Total Queues")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 50)

                VStack(spacing: 8) {
                    Text("\(totalActive)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                    Text("Active")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 50)

                VStack(spacing: 8) {
                    Text("\(totalWaiting)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                    Text("Waiting")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 50)

                VStack(spacing: 8) {
                    Text("\(totalFailed)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(totalFailed > 0 ? .red : .secondary)
                    Text("Failed")
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

// MARK: - App Session Card
struct AppSessionCard: View {
    let sessionStart: Date
    let completedJobs: Int
    let failedJobs: Int
    let pollingInterval: Double

    private var sessionDuration: String {
        let elapsed = Date().timeIntervalSince(sessionStart)
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.badge.checkmark")
                    .font(.title2)
                    .foregroundColor(.purple)
                Text("App Session")
                    .font(.headline)
                Spacer()
                Text("Since \(sessionStart.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            VStack(spacing: 12) {
                DiagnosticInfoRow(label: "Session Duration", value: sessionDuration)
                DiagnosticInfoRow(label: "Jobs Tracked", value: "\(completedJobs)")
                DiagnosticInfoRow(label: "Failures Tracked", value: "\(failedJobs)")
                DiagnosticInfoRow(label: "Polling Interval", value: "\(Int(pollingInterval))s")
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Diagnostic Info Row
struct DiagnosticInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// Keep StatItem for any other views that might use it
struct StatItem: View {
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

// MARK: - Failed Jobs View
struct FailedJobsView: View {
    @EnvironmentObject var appState: AppState
    @State private var failedRecords: [FailedJobRecord] = []
    @State private var selectedRecord: FailedJobRecord?
    
    var body: some View {
        HStack(spacing: 0) {
            // Failed jobs list
            List(failedRecords, selection: $selectedRecord) { record in
                FailedJobListItem(record: record)
            }
            .frame(width: 400)
            
            Divider()
            
            // Job details
            if let record = selectedRecord {
                FailedJobDetailView(record: record)
            } else {
                EmptyStateView(
                    icon: "checkmark.circle",
                    title: "No Failed Job Selected",
                    message: "Select a failed job to view details"
                )
            }
        }
        .navigationTitle("Failed Jobs")
        .toolbar {
            ToolbarItem {
                Button("Retry All") {
                    Task {
                        await appState.immichService.retryFailedJobs()
                    }
                }
            }
        }
        .task {
            loadFailedJobs()
        }
    }
    
    private func loadFailedJobs() {
        failedRecords = appState.databaseManager.fetchFailedJobs()
    }
}

struct FailedJobListItem: View {
    let record: FailedJobRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(record.assetName ?? "Unknown Asset")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text(record.queueName)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(record.failedAt, style: .relative)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            if record.retryCount > 0 {
                Text("Retried \(record.retryCount) times")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}

struct FailedJobDetailView: View {
    let record: FailedJobRecord
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(record.assetName ?? "Unknown Asset")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(record.queueName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Error message
                VStack(alignment: .leading, spacing: 8) {
                    Text("Error Message")
                        .font(.headline)
                    
                    Text(record.errorMessage)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                
                // Stack trace
                if let stackTrace = record.stackTrace {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Stack Trace")
                            .font(.headline)
                        
                        ScrollView(.horizontal) {
                            Text(stackTrace)
                                .font(.system(.caption, design: .monospaced))
                                .padding()
                        }
                        .frame(height: 200)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }
                
                // Metadata
                VStack(alignment: .leading, spacing: 12) {
                    Text("Metadata")
                        .font(.headline)
                    
                    if let fileType = record.fileType {
                        MetadataRow(label: "File Type", value: fileType)
                    }
                    
                    if let fileSize = record.fileSize {
                        MetadataRow(label: "File Size", value: ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))
                    }
                    
                    MetadataRow(label: "Failed At", value: record.failedAt.formatted())
                    MetadataRow(label: "Retry Count", value: "\(record.retryCount)")
                }
                
                // Actions
                HStack(spacing: 12) {
                    Button("Retry Job") {
                        Task {
                            try? await appState.immichService.retryJob(jobId: record.jobId)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Delete Record") {
                        appState.databaseManager.deleteFailedJob(id: record.id)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
    }
}

struct MetadataRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("serverURL") private var serverURL = ""
    @AppStorage("apiKey") private var apiKey = ""
    @AppStorage("pollingInterval") private var pollingInterval = 3.0
    @State private var testingConnection = false
    @State private var connectionStatus = ""
    @State private var showApiKey = false
    
    var body: some View {
        Form {
            Section("Server Connection") {
                TextField("Server URL (e.g., http://192.168.1.100:2283)", text: $serverURL)
                
                HStack {
                    if showApiKey {
                        TextField("API Key", text: $apiKey)
                    } else {
                        SecureField("API Key", text: $apiKey)
                    }
                    
                    Button(action: { showApiKey.toggle() }) {
                        Image(systemName: showApiKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                    .help(showApiKey ? "Hide API Key" : "Show API Key")
                }
                
                Slider(value: $pollingInterval, in: 1...30, step: 1) {
                    Text("Polling Interval: \(Int(pollingInterval))s")
                }
                
                HStack {
                    Button("Test Connection") {
                        testConnection()
                    }
                    .disabled(testingConnection)
                    
                    if !connectionStatus.isEmpty {
                        Text(connectionStatus)
                            .font(.caption)
                            .foregroundColor(connectionStatus.contains("Success") ? .green : .red)
                    }
                }
                
                Button("Save Settings") {
                    saveSettings()
                }
                .buttonStyle(.borderedProminent)
            }
            
            Section("Notifications") {
                Toggle("Enable Notifications", isOn: .constant(true))
                Toggle("Queue Stall Alerts", isOn: .constant(true))
                Toggle("Job Failure Alerts", isOn: .constant(true))
            }
            
            Section("Database") {
                HStack {
                    Text("Database Size:")
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: appState.databaseManager.getDatabaseSize(), countStyle: .file))
                        .foregroundColor(.secondary)
                }
                
                Button("Vacuum Database") {
                    appState.databaseManager.vacuum()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 600, height: 500)
    }
    
    private func testConnection() {
        testingConnection = true
        connectionStatus = "Testing..."

        // Trim whitespace from inputs
        let trimmedURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        // Update service with current form values before testing
        appState.immichService.updateConnection(
            serverURL: trimmedURL,
            apiKey: trimmedKey,
            pollingInterval: pollingInterval
        )

        Task {
            let success = await appState.immichService.testConnection()
            await MainActor.run {
                if success {
                    connectionStatus = "✓ Connection Successful"
                } else {
                    // Show the actual error message
                    let errorMsg = appState.immichService.errorMessage ?? "Unknown error"
                    connectionStatus = "✗ Failed: \(errorMsg)"
                }
                testingConnection = false
            }
        }
    }
    
    private func saveSettings() {
        appState.immichService.updateConnection(
            serverURL: serverURL,
            apiKey: apiKey,
            pollingInterval: pollingInterval
        )
    }
}

// MARK: - Menu Bar View
struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 16) {
            // Status
            HStack {
                Circle()
                    .fill(appState.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                Text(appState.isConnected ? "Connected" : "Disconnected")
                    .font(.caption)
                
                Spacer()
            }
            .padding(.horizontal)
            
            Divider()
            
            // Quick stats
            VStack(spacing: 12) {
                StatRow(label: "Active Jobs", value: "\(appState.immichService.getActiveJobs().count)")
                StatRow(label: "Queued", value: "\(appState.immichService.getTotalQueuedCount())")
                StatRow(label: "Failed", value: "\(appState.immichService.getFailedJobs().count)")
            }
            .padding(.horizontal)
            
            Divider()
            
            // Quick actions
            VStack(spacing: 8) {
                Button("Open Dashboard") {
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.borderedProminent)
                
                Button("Pause All") {
                    Task {
                        await appState.immichService.pauseAllQueues()
                    }
                }
                
                Button("Resume All") {
                    Task {
                        await appState.immichService.resumeAllQueues()
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.vertical)
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Notification Manager
class NotificationManager {
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            }
        }
    }
    
    func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
