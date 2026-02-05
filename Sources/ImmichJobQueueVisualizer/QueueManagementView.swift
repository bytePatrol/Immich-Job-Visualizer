//
//  QueueManagementView.swift
//  Advanced queue management with filtering and batch operations
//

import SwiftUI

struct QueueManagementView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedQueue: Queue?
    @State private var searchText = ""
    @State private var filterStatus: JobStatus?
    @State private var selectedJobs = Set<String>()
    @State private var showingFilters = false
    
    var filteredJobs: [Job] {
        guard let selectedQueue = selectedQueue else { return [] }
        
        return appState.immichService.currentJobs
            .filter { $0.queueName == selectedQueue.name }
            .filter { job in
                if let filterStatus = filterStatus {
                    return job.status == filterStatus
                }
                return true
            }
            .filter { job in
                if searchText.isEmpty { return true }
                return job.assetName?.localizedCaseInsensitiveContains(searchText) ?? false
            }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar with queue list
            QueueSidebarView(
                queues: appState.immichService.queues,
                selectedQueue: $selectedQueue
            )
            .frame(width: 280)
            
            Divider()
            
            // Main content area
            VStack(spacing: 0) {
                // Toolbar
                QueueToolbar(
                    searchText: $searchText,
                    filterStatus: $filterStatus,
                    selectedJobsCount: selectedJobs.count,
                    showingFilters: $showingFilters,
                    onPause: { pauseSelected() },
                    onResume: { resumeSelected() },
                    onCancel: { cancelSelected() },
                    onRetry: { retrySelected() }
                )
                
                Divider()
                
                // Job list
                if let queue = selectedQueue {
                    JobListView(
                        queue: queue,
                        jobs: filteredJobs,
                        selectedJobs: $selectedJobs
                    )
                } else {
                    EmptyStateView(
                        icon: "tray",
                        title: "Select a Queue",
                        message: "Choose a queue from the sidebar to view its jobs"
                    )
                }
            }
        }
        .navigationTitle("Queue Management")
        .sheet(isPresented: $showingFilters) {
            FilterSheet(filterStatus: $filterStatus)
        }
    }
    
    // MARK: - Actions
    
    private func pauseSelected() {
        // Implement batch pause
        Task {
            for _ in selectedJobs {
                // await appState.immichService.pauseJob(jobId: jobId)
            }
            selectedJobs.removeAll()
        }
    }
    
    private func resumeSelected() {
        // Implement batch resume
        Task {
            for _ in selectedJobs {
                // await appState.immichService.resumeJob(jobId: jobId)
            }
            selectedJobs.removeAll()
        }
    }
    
    private func cancelSelected() {
        Task {
            for jobId in selectedJobs {
                try? await appState.immichService.cancelJob(jobId: jobId)
            }
            selectedJobs.removeAll()
        }
    }
    
    private func retrySelected() {
        Task {
            for jobId in selectedJobs {
                try? await appState.immichService.retryJob(jobId: jobId)
            }
            selectedJobs.removeAll()
        }
    }
}

// MARK: - Queue Sidebar
struct QueueSidebarView: View {
    let queues: [Queue]
    @Binding var selectedQueue: Queue?
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Queues")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            
            Divider()
            
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(queues) { queue in
                        QueueSidebarRow(
                            queue: queue,
                            isSelected: selectedQueue?.id == queue.id
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedQueue = queue
                        }
                    }
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct QueueSidebarRow: View {
    let queue: Queue
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Image(systemName: queue.queueType.icon)
                .foregroundColor(queue.isPaused ? .gray : .blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(queue.displayName)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                HStack(spacing: 8) {
                    Label("\(queue.count)", systemImage: "tray")
                    Label("\(queue.activeCount)", systemImage: "bolt")
                    if queue.failedCount > 0 {
                        Label("\(queue.failedCount)", systemImage: "exclamationmark.triangle")
                            .foregroundColor(.red)
                    }
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(queue.activeWorkers)/\(queue.maxWorkers)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if let avgTime = queue.averageProcessingTime {
                    Text(formatDuration(avgTime))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 60 {
            return String(format: "%.1fs", duration)
        } else if duration < 3600 {
            return String(format: "%.1fm", duration / 60)
        } else {
            return String(format: "%.1fh", duration / 3600)
        }
    }
}

// MARK: - Queue Toolbar
struct QueueToolbar: View {
    @Binding var searchText: String
    @Binding var filterStatus: JobStatus?
    let selectedJobsCount: Int
    @Binding var showingFilters: Bool
    let onPause: () -> Void
    let onResume: () -> Void
    let onCancel: () -> Void
    let onRetry: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search jobs...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            // Filter button
            Button(action: { showingFilters = true }) {
                Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
            }
            
            Divider()
                .frame(height: 24)
            
            // Batch action buttons
            if selectedJobsCount > 0 {
                Text("\(selectedJobsCount) selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("Pause", action: onPause)
                Button("Resume", action: onResume)
                Button("Cancel", action: onCancel)
                Button("Retry", action: onRetry)
            }
            
            Spacer()
            
            // Filter indicator
            if let status = filterStatus {
                HStack(spacing: 4) {
                    Text("Filtered: \(status.displayName)")
                        .font(.caption)
                    Button(action: { filterStatus = nil }) {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding()
    }
}

// MARK: - Job List
struct JobListView: View {
    let queue: Queue
    let jobs: [Job]
    @Binding var selectedJobs: Set<String>
    
    var body: some View {
        Table(of: Job.self, selection: $selectedJobs) {
            TableColumn("Asset") { job in
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.assetName ?? "Unknown")
                        .font(.subheadline)
                    if let fileType = job.fileType {
                        Text(fileType.uppercased())
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
            .width(min: 200, max: 400)
            
            TableColumn("Size") { job in
                if let size = job.fileSize {
                    Text(formatBytes(size))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .width(80)
            
            TableColumn("Progress") { job in
                HStack(spacing: 8) {
                    ProgressView(value: job.progress)
                        .frame(width: 100)
                    Text("\(Int(job.progress * 100))%")
                        .font(.caption)
                        .monospacedDigit()
                }
            }
            .width(140)
            
            TableColumn("Worker") { job in
                if let workerId = job.workerId {
                    Text(workerId)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .width(100)
            
            TableColumn("Duration") { job in
                if let duration = job.duration {
                    Text(formatDuration(duration))
                        .font(.caption)
                        .monospacedDigit()
                }
            }
            .width(80)
            
            TableColumn("Status") { job in
                StatusBadge(status: job.status)
            }
            .width(100)
        } rows: {
            ForEach(jobs) { job in
                TableRow(job)
                    .contextMenu {
                        JobContextMenu(job: job)
                    }
            }
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct StatusBadge: View {
    let status: JobStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(6)
    }
    
    private var statusColor: Color {
        switch status {
        case .waiting: return .orange
        case .active: return .blue
        case .completed: return .green
        case .failed: return .red
        case .paused: return .gray
        case .delayed: return .yellow
        }
    }
}

struct JobContextMenu: View {
    let job: Job
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Button("View Details") {
            // Show job details
        }
        
        Divider()
        
        if job.isFailed {
            Button("Retry Job") {
                Task {
                    try? await appState.immichService.retryJob(jobId: job.id)
                }
            }
        }
        
        Button("Cancel Job") {
            Task {
                try? await appState.immichService.cancelJob(jobId: job.id)
            }
        }
        
        Divider()
        
        Button("Copy Job ID") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(job.id, forType: .string)
        }
    }
}

// MARK: - Filter Sheet
struct FilterSheet: View {
    @Binding var filterStatus: JobStatus?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Filter Jobs")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Status")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                ForEach(JobStatus.allCases, id: \.self) { status in
                    Button(action: {
                        filterStatus = status
                        dismiss()
                    }) {
                        HStack {
                            Text(status.displayName)
                            Spacer()
                            if filterStatus == status {
                                Image(systemName: "checkmark")
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 8)
                }
                
                Divider()
                
                Button("Clear Filter") {
                    filterStatus = nil
                    dismiss()
                }
            }
            .padding()
            
            Spacer()
        }
        .frame(width: 300, height: 400)
        .padding()
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
