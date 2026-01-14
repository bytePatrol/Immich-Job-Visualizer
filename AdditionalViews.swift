//
//  AdditionalViews.swift
//  Diagnostics, Failed Jobs, Settings, and Menu Bar views
//

import SwiftUI
import UserNotifications

// MARK: - Diagnostics View
struct DiagnosticsView: View {
    @EnvironmentObject var appState: AppState
    @State private var diagnosticInfo: DiagnosticInfo?
    @State private var logs: [LogEntry] = []
    @State private var selectedLogLevel: String = "all"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // PostgreSQL Health
                PostgresHealthCard(poolInfo: diagnosticInfo?.postgresConnectionPool)
                    .padding(.horizontal)
                
                // Network Latency
                NetworkLatencyCard(latency: diagnosticInfo?.apiLatency ?? 0)
                    .padding(.horizontal)
                
                // Storage I/O
                StorageIOCard(ioStats: diagnosticInfo?.storageIOStats)
                    .padding(.horizontal)
                
                // Memory Leak Detection
                if let leaks = diagnosticInfo?.memoryLeaks, !leaks.isEmpty {
                    MemoryLeakWarningsCard(warnings: leaks)
                        .padding(.horizontal)
                }
                
                // Log Viewer
                LogViewerCard(logs: logs, selectedLevel: $selectedLogLevel)
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Diagnostics")
        .task {
            await loadDiagnostics()
        }
    }
    
    private func loadDiagnostics() async {
        do {
            diagnosticInfo = try await appState.immichService.fetchDiagnosticInfo()
            logs = try await appState.immichService.fetchLogs()
        } catch {
            print("Error loading diagnostics: \(error)")
        }
    }
}

struct PostgresHealthCard: View {
    let poolInfo: PostgresPoolInfo?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("PostgreSQL Health", systemImage: "cylinder.fill")
                .font(.headline)
            
            if let info = poolInfo {
                HStack(spacing: 40) {
                    StatItem(label: "Total", value: "\(info.totalConnections)")
                    StatItem(label: "Active", value: "\(info.activeConnections)", color: .green)
                    StatItem(label: "Idle", value: "\(info.idleConnections)", color: .blue)
                    StatItem(label: "Waiting", value: "\(info.waitingClients)", color: .orange)
                }
            } else {
                Text("Loading...")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct NetworkLatencyCard: View {
    let latency: TimeInterval
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("API Latency", systemImage: "network")
                .font(.headline)
            
            HStack {
                Text(String(format: "%.0f ms", latency * 1000))
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                LatencyIndicator(latency: latency)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct LatencyIndicator: View {
    let latency: TimeInterval
    
    var color: Color {
        if latency < 0.1 { return .green }
        else if latency < 0.5 { return .yellow }
        else { return .red }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(color.opacity(index < latencyBars ? 1.0 : 0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }
    
    var latencyBars: Int {
        if latency < 0.1 { return 3 }
        else if latency < 0.5 { return 2 }
        else { return 1 }
    }
}

struct StorageIOCard: View {
    let ioStats: StorageIOStats?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Storage I/O", systemImage: "externaldrive.fill")
                .font(.headline)
            
            if let stats = ioStats {
                HStack(spacing: 40) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Read Speed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f MB/s", stats.readSpeed))
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Write Speed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f MB/s", stats.writeSpeed))
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("IOPS")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(stats.iops)")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct MemoryLeakWarningsCard: View {
    let warnings: [MemoryLeakWarning]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Memory Leak Warnings", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundColor(.red)
            
            ForEach(warnings) { warning in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Worker: \(warning.workerId)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Growth Rate: \(String(format: "%.1f MB/hour", warning.growthRate))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(formatBytes(warning.currentMemory))
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .memory)
    }
}

struct LogViewerCard: View {
    let logs: [LogEntry]
    @Binding var selectedLevel: String
    
    var filteredLogs: [LogEntry] {
        if selectedLevel == "all" {
            return logs
        }
        return logs.filter { $0.level.lowercased() == selectedLevel.lowercased() }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Logs", systemImage: "doc.text")
                    .font(.headline)
                
                Spacer()
                
                Picker("Level", selection: $selectedLevel) {
                    Text("All").tag("all")
                    Text("Error").tag("error")
                    Text("Warning").tag("warning")
                    Text("Info").tag("info")
                }
                .pickerStyle(.menu)
            }
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(filteredLogs.prefix(100)) { log in
                        LogEntryRow(entry: log)
                    }
                }
            }
            .frame(height: 400)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct LogEntryRow: View {
    let entry: LogEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(entry.timestamp, style: .time)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            
            Text(entry.level.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(levelColor)
                .frame(width: 60, alignment: .leading)
            
            Text(entry.message)
                .font(.caption)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
    
    var levelColor: Color {
        switch entry.level.lowercased() {
        case "error": return .red
        case "warning": return .orange
        case "info": return .blue
        default: return .secondary
        }
    }
}

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
        Task {
            let success = await appState.immichService.testConnection()
            await MainActor.run {
                connectionStatus = success ? "✓ Connection Successful" : "✗ Connection Failed"
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
