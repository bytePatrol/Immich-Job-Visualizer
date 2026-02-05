//
//  ImmichService.swift
//  Service layer for Immich API integration with async/await and error handling
//

import Foundation
import Combine

class ImmichService: ObservableObject {
    @Published var isConnected = false
    @Published var lastUpdateTime: Date?
    @Published var currentJobs: [Job] = []
    @Published var queues: [Queue] = []
    @Published var serverStats: ServerStats?
    @Published var errorMessage: String?
    
    var serverURL: String
    private var apiKey: String
    private(set) var pollingInterval: TimeInterval
    private var pollingTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    init(serverURL: String? = nil, apiKey: String? = nil, pollingInterval: TimeInterval = 3.0) {
        // Load from UserDefaults or use provided values
        let defaultServerURL = ""
        let defaultApiKey = ""
        
        self.serverURL = serverURL ?? UserDefaults.standard.string(forKey: "serverURL") ?? defaultServerURL
        self.apiKey = apiKey ?? UserDefaults.standard.string(forKey: "apiKey") ?? defaultApiKey
        self.pollingInterval = pollingInterval
        
        // Don't save empty defaults
        if !defaultServerURL.isEmpty && UserDefaults.standard.string(forKey: "serverURL") == nil {
            UserDefaults.standard.set(defaultServerURL, forKey: "serverURL")
        }
        if !defaultApiKey.isEmpty && UserDefaults.standard.string(forKey: "apiKey") == nil {
            UserDefaults.standard.set(defaultApiKey, forKey: "apiKey")
        }
        
        startPolling()
    }
    
    deinit {
        stopPolling()
    }
    
    // MARK: - Connection Management
    
    func updateConnection(serverURL: String, apiKey: String, pollingInterval: TimeInterval) {
        self.serverURL = serverURL
        self.apiKey = apiKey
        self.pollingInterval = pollingInterval
        
        UserDefaults.standard.set(serverURL, forKey: "serverURL")
        UserDefaults.standard.set(apiKey, forKey: "apiKey")
        
        restartPolling()
    }
    
    func testConnection() async -> Bool {
        do {
            // Use the correct Immich API endpoint
            struct PingResponse: Codable {
                let res: String
            }

            print("🔍 Testing connection to '\(serverURL)' with key '\(String(apiKey.prefix(10)))...'")

            let response: PingResponse = try await makeRequest(endpoint: "/api/server/ping")
            print("✅ Ping successful: \(response.res)")
            
            await MainActor.run {
                self.isConnected = true
                self.errorMessage = nil
            }
            return true
        } catch let error as ImmichError {
            print("❌ Connection failed: \(error.errorDescription ?? "Unknown error")")
            await MainActor.run {
                self.isConnected = false
                self.errorMessage = error.errorDescription
            }
            return false
        } catch {
            print("❌ Unexpected error: \(error.localizedDescription)")
            print("❌ Full error details: \(error)")
            await MainActor.run {
                self.isConnected = false
                self.errorMessage = error.localizedDescription
            }
            return false
        }
    }

    func fetchServerVersion() async -> String? {
        struct VersionResponse: Codable {
            let major: Int
            let minor: Int
            let patch: Int
        }

        do {
            let response: VersionResponse = try await makeRequest(endpoint: "/api/server/version")
            return "\(response.major).\(response.minor).\(response.patch)"
        } catch {
            print("Failed to fetch server version: \(error)")
            return nil
        }
    }

    private func startPolling() {
        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.pollData()
            }
        }
        
        // Initial poll
        Task {
            await pollData()
        }
    }
    
    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    private func restartPolling() {
        stopPolling()
        startPolling()
    }
    
    private func pollData() async {
        do {
            async let jobsTask = fetchAllJobs()
            async let queuesTask = fetchQueues()

            let (jobs, queues) = try await (jobsTask, queuesTask)

            // Calculate stats from actual queue data
            let stats = calculateServerStats(from: queues)

            await MainActor.run {
                self.currentJobs = jobs
                self.queues = queues
                self.serverStats = stats
                self.isConnected = true
                self.lastUpdateTime = Date()
                self.errorMessage = nil

                // Track processing rate history
                self.updateProcessingRateHistory(queues: queues)
            }
        } catch {
            await MainActor.run {
                self.isConnected = false
                self.errorMessage = error.localizedDescription
            }
        }
    }

    // Track waiting jobs to calculate processing rate
    private var lastWaitingCount: Int?
    private var lastPollTime: Date?
    private var completedSinceStart: Int = 0
    @Published var processingRateHistory: [(timestamp: Date, rate: Double)] = []

    private func updateProcessingRateHistory(queues: [Queue]) {
        // Total waiting jobs across all queues
        let totalWaiting = queues.reduce(0) { $0 + $1.count - $1.activeCount }
        let totalActive = queues.reduce(0) { $0 + $1.activeCount }
        let now = Date()

        if let lastWaiting = lastWaitingCount, let lastTime = lastPollTime {
            let timeDelta = now.timeIntervalSince(lastTime)
            if timeDelta > 0 {
                // Jobs completed = decrease in waiting count (if positive)
                // Account for new jobs being added by only counting decreases
                let waitingDecrease = lastWaiting - totalWaiting
                if waitingDecrease > 0 {
                    completedSinceStart += waitingDecrease
                    let rate = Double(waitingDecrease) / (timeDelta / 60.0) // jobs per minute
                    processingRateHistory.append((timestamp: now, rate: rate))
                } else if totalActive > 0 {
                    // Jobs are processing but queue grew - estimate rate from active workers
                    // Assume each worker processes ~1 job per poll interval
                    let estimatedRate = Double(totalActive) * (60.0 / timeDelta)
                    processingRateHistory.append((timestamp: now, rate: estimatedRate))
                } else {
                    // No activity
                    processingRateHistory.append((timestamp: now, rate: 0))
                }

                // Keep only last hour of data
                let oneHourAgo = now.addingTimeInterval(-3600)
                processingRateHistory = processingRateHistory.filter { $0.timestamp > oneHourAgo }
            }
        }

        lastWaitingCount = totalWaiting
        lastPollTime = now
    }

    private func calculateServerStats(from queues: [Queue]) -> ServerStats {
        let activeWorkers = queues.reduce(0) { $0 + $1.activeCount }
        let totalFailed = queues.reduce(0) { $0 + $1.failedCount }

        // Calculate average processing rate from recent history
        let recentRate: Double
        if processingRateHistory.count >= 2 {
            // Average of last 10 rate samples
            let recentRates = processingRateHistory.suffix(10).map { $0.rate }
            recentRate = recentRates.reduce(0, +) / Double(recentRates.count)
        } else if processingRateHistory.count == 1 {
            recentRate = processingRateHistory[0].rate
        } else {
            recentRate = 0
        }

        return ServerStats(
            totalAssets: 0,
            totalUsers: 0,
            totalStorage: 0,
            cpuUsage: 0,  // Not available from Immich API
            memoryUsage: 0,  // Not available from Immich API
            activeWorkers: activeWorkers,
            jobsProcessedToday: completedSinceStart,  // Track our own completed count
            jobsFailedToday: totalFailed,
            averageProcessingRate: recentRate,
            timestamp: Date()
        )
    }
    
    // MARK: - API Requests
    
    private func makeRequest<T: Decodable>(endpoint: String, method: String = "GET", body: Data? = nil) async throws -> T {
        let urlString = "\(serverURL)\(endpoint)"
        print("🌐 Making request to: \(urlString)")

        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            throw ImmichError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.timeoutInterval = 30

        if let body = body {
            request.httpBody = body
        }

        print("📤 Request headers: \(request.allHTTPHeaderFields ?? [:])")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                throw ImmichError.invalidResponse
            }

            print("📥 Response status: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ HTTP Error \(httpResponse.statusCode): \(errorMessage)")
                throw ImmichError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            do {
                let decoded = try decoder.decode(T.self, from: data)
                print("✅ Successfully decoded response")
                return decoded
            } catch {
                print("❌ Decoding error: \(error)")
                let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
                print("📄 Raw response: \(responseString)")
                throw ImmichError.decodingError(error)
            }
        } catch let error as ImmichError {
            throw error
        } catch {
            print("❌ Network error: \(error.localizedDescription)")
            print("❌ Full error: \(error)")
            throw ImmichError.networkError(error)
        }
    }
    
    // MARK: - Jobs API
    
    func fetchAllJobs() async throws -> [Job] {
        // Immich returns queue info, not individual jobs
        // We'll parse the queue counts into summary jobs
        let response: ImmichJobsResponse = try await makeRequest(endpoint: "/api/jobs")
        
        var jobs: [Job] = []
        
        // Helper to create jobs from queue info
        func createJobsFromQueue(name: String, info: QueueInfo?) -> [Job] {
            guard let info = info else { return [] }
            var queueJobs: [Job] = []
            
            let counts = info.jobCounts
            
            // Create representative jobs for each status
            if counts.active > 0 {
                queueJobs.append(Job(
                    id: "\(name)-active",
                    queueName: name,
                    assetId: nil,
                    assetName: "\(counts.active) active jobs",
                    status: .active,
                    progress: 0.5,
                    workerId: nil,
                    startedAt: Date(),
                    completedAt: nil,
                    duration: nil,
                    errorMessage: nil,
                    fileType: nil,
                    fileSize: nil,
                    metadata: nil
                ))
            }
            
            if counts.waiting > 0 {
                queueJobs.append(Job(
                    id: "\(name)-waiting",
                    queueName: name,
                    assetId: nil,
                    assetName: "\(counts.waiting) waiting jobs",
                    status: .waiting,
                    progress: 0.0,
                    workerId: nil,
                    startedAt: nil,
                    completedAt: nil,
                    duration: nil,
                    errorMessage: nil,
                    fileType: nil,
                    fileSize: nil,
                    metadata: nil
                ))
            }
            
            if counts.failed > 0 {
                queueJobs.append(Job(
                    id: "\(name)-failed",
                    queueName: name,
                    assetId: nil,
                    assetName: "\(counts.failed) failed jobs",
                    status: .failed,
                    progress: 0.0,
                    workerId: nil,
                    startedAt: nil,
                    completedAt: nil,
                    duration: nil,
                    errorMessage: "Jobs failed",
                    fileType: nil,
                    fileSize: nil,
                    metadata: nil
                ))
            }
            
            return queueJobs
        }
        
        // Process all queues
        jobs += createJobsFromQueue(name: "thumbnailGeneration", info: response.thumbnailGeneration)
        jobs += createJobsFromQueue(name: "metadataExtraction", info: response.metadataExtraction)
        jobs += createJobsFromQueue(name: "videoConversion", info: response.videoConversion)
        jobs += createJobsFromQueue(name: "smartSearch", info: response.smartSearch)
        jobs += createJobsFromQueue(name: "faceDetection", info: response.faceDetection)
        jobs += createJobsFromQueue(name: "facialRecognition", info: response.facialRecognition)
        jobs += createJobsFromQueue(name: "duplicateDetection", info: response.duplicateDetection)
        jobs += createJobsFromQueue(name: "storageTemplateMigration", info: response.storageTemplateMigration)
        jobs += createJobsFromQueue(name: "backgroundTask", info: response.backgroundTask)
        
        return jobs
    }
    
    func fetchJobsForQueue(queueName: String) async throws -> [Job] {
        // Immich doesn't provide individual job details per queue
        // We'll return the summary jobs from fetchAllJobs filtered by queue name
        let allJobs = try await fetchAllJobs()
        return allJobs.filter { $0.queueName == queueName }
    }
    
    func retryJob(jobId: String) async throws {
        let _: EmptyResponse = try await makeRequest(endpoint: "/api/jobs/\(jobId)/retry", method: "POST")
    }
    
    func retryFailedJobs(queueName: String? = nil) async {
        do {
            let endpoint = queueName != nil ? "/api/jobs/\(queueName!)/retry-failed" : "/api/jobs/retry-failed"
            let _: EmptyResponse = try await makeRequest(endpoint: endpoint, method: "POST")
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to retry jobs: \(error.localizedDescription)"
            }
        }
    }
    
    func cancelJob(jobId: String) async throws {
        let _: EmptyResponse = try await makeRequest(endpoint: "/api/jobs/\(jobId)/cancel", method: "DELETE")
    }
    
    // MARK: - Queue Management API
    
    func fetchQueues() async throws -> [Queue] {
        let response: ImmichJobsResponse = try await makeRequest(endpoint: "/api/jobs")
        
        var queues: [Queue] = []
        
        // Helper to create Queue from queue info
        func createQueue(id: String, name: String, displayName: String, info: QueueInfo?) -> Queue? {
            guard let info = info else { return nil }
            
            let counts = info.jobCounts
            let totalCount = counts.active + counts.waiting + counts.delayed + counts.paused
            
            return Queue(
                id: id,
                name: name,
                displayName: displayName,
                count: totalCount,
                activeCount: counts.active,
                completedCount: counts.completed,
                failedCount: counts.failed,
                pausedCount: counts.paused,
                delayedCount: counts.delayed,
                isPaused: info.queueStatus.isPaused,
                activeWorkers: counts.active,
                maxWorkers: 10, // Default, Immich doesn't expose this
                averageProcessingTime: nil,
                processingRate: nil
            )
        }
        
        // Create queues for all available job types
        if let queue = createQueue(id: "thumbnail", name: "thumbnailGeneration", displayName: "Thumbnail Generation", info: response.thumbnailGeneration) {
            queues.append(queue)
        }
        if let queue = createQueue(id: "metadata", name: "metadataExtraction", displayName: "Metadata Extraction", info: response.metadataExtraction) {
            queues.append(queue)
        }
        if let queue = createQueue(id: "video", name: "videoConversion", displayName: "Video Conversion", info: response.videoConversion) {
            queues.append(queue)
        }
        if let queue = createQueue(id: "search", name: "smartSearch", displayName: "Smart Search", info: response.smartSearch) {
            queues.append(queue)
        }
        if let queue = createQueue(id: "face", name: "faceDetection", displayName: "Face Detection", info: response.faceDetection) {
            queues.append(queue)
        }
        if let queue = createQueue(id: "facial", name: "facialRecognition", displayName: "Facial Recognition", info: response.facialRecognition) {
            queues.append(queue)
        }
        if let queue = createQueue(id: "duplicate", name: "duplicateDetection", displayName: "Duplicate Detection", info: response.duplicateDetection) {
            queues.append(queue)
        }
        if let queue = createQueue(id: "storage", name: "storageTemplateMigration", displayName: "Storage Migration", info: response.storageTemplateMigration) {
            queues.append(queue)
        }
        if let queue = createQueue(id: "background", name: "backgroundTask", displayName: "Background Tasks", info: response.backgroundTask) {
            queues.append(queue)
        }
        if let queue = createQueue(id: "library", name: "library", displayName: "Library", info: response.library) {
            queues.append(queue)
        }
        if let queue = createQueue(id: "sidecar", name: "sidecar", displayName: "Sidecar", info: response.sidecar) {
            queues.append(queue)
        }
        
        return queues
    }
    
    func pauseQueue(queueName: String) async throws {
        let _: EmptyResponse = try await makeRequest(endpoint: "/api/jobs/\(queueName)/pause", method: "POST")
    }
    
    func resumeQueue(queueName: String) async throws {
        let _: EmptyResponse = try await makeRequest(endpoint: "/api/jobs/\(queueName)/resume", method: "POST")
    }
    
    func pauseAllQueues() async {
        for queue in queues where !queue.isPaused {
            do {
                try await pauseQueue(queueName: queue.name)
            } catch {
                print("Failed to pause queue \(queue.name): \(error)")
            }
        }
        
        // Refresh queue status
        await pollData()
    }
    
    func resumeAllQueues() async {
        for queue in queues where queue.isPaused {
            do {
                try await resumeQueue(queueName: queue.name)
            } catch {
                print("Failed to resume queue \(queue.name): \(error)")
            }
        }
        
        // Refresh queue status
        await pollData()
    }
    
    func clearCompletedJobs() async {
        do {
            let _: EmptyResponse = try await makeRequest(endpoint: "/api/jobs/completed", method: "DELETE")
            await pollData()
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to clear completed jobs: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Server Statistics API
    
    func fetchServerStats() async throws -> ServerStats {
        // For now, return minimal stats since we need to discover the correct endpoints
        // The app will still work for job monitoring
        return ServerStats(
            totalAssets: 0,
            totalUsers: 0,
            totalStorage: 0,
            cpuUsage: 0,
            memoryUsage: 0,
            activeWorkers: 0,
            jobsProcessedToday: 0,
            jobsFailedToday: 0,
            averageProcessingRate: 0,
            timestamp: Date()
        )
    }
    
    // MARK: - Diagnostic APIs
    
    func fetchDiagnosticInfo() async throws -> DiagnosticInfo {
        return try await makeRequest(endpoint: "/api/diagnostics")
    }
    
    func fetchLogs(since: Date? = nil, level: String? = nil) async throws -> [LogEntry] {
        var endpoint = "/api/logs"
        var queryItems: [String] = []
        
        if let since = since {
            let formatter = ISO8601DateFormatter()
            queryItems.append("since=\(formatter.string(from: since))")
        }
        
        if let level = level {
            queryItems.append("level=\(level)")
        }
        
        if !queryItems.isEmpty {
            endpoint += "?" + queryItems.joined(separator: "&")
        }
        
        let response: LogsResponse = try await makeRequest(endpoint: endpoint)
        return response.logs
    }
    
    // MARK: - Worker Management
    
    func updateWorkerConcurrency(queueName: String, concurrency: Int) async throws {
        struct ConcurrencyUpdate: Encodable {
            let concurrency: Int
        }
        
        let body = try JSONEncoder().encode(ConcurrencyUpdate(concurrency: concurrency))
        let _: EmptyResponse = try await makeRequest(
            endpoint: "/api/jobs/\(queueName)/concurrency",
            method: "PUT",
            body: body
        )
    }
    
    // MARK: - Helper Methods
    
    func getActiveJobs() -> [Job] {
        currentJobs.filter { $0.isActive }
    }
    
    func getFailedJobs() -> [Job] {
        currentJobs.filter { $0.isFailed }
    }
    
    func getCompletedJobsToday() -> [Job] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return currentJobs.filter { job in
            guard let completedAt = job.completedAt else { return false }
            return calendar.isDate(completedAt, inSameDayAs: today) && job.isCompleted
        }
    }
    
    func getTotalQueuedCount() -> Int {
        queues.reduce(0) { $0 + $1.count }
    }
}

// MARK: - Helper Structs

struct EmptyResponse: Codable {}

struct LogEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let level: String
    let message: String
    let context: String?
    let stackTrace: String?
}

struct LogsResponse: Codable {
    let logs: [LogEntry]
}

// MARK: - Error Handling

enum ImmichError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode, let message):
            return "HTTP error \(statusCode): \(message ?? "Unknown error")"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
