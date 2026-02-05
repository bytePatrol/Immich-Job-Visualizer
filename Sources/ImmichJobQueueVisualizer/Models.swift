//
//  Models.swift
//  Data models for Immich API integration
//

import Foundation

// MARK: - Job Models
struct Job: Codable, Identifiable, Hashable {
    let id: String
    let queueName: String
    let assetId: String?
    let assetName: String?
    let status: JobStatus
    let progress: Double
    let workerId: String?
    let startedAt: Date?
    let completedAt: Date?
    let duration: TimeInterval?
    let errorMessage: String?
    let fileType: String?
    let fileSize: Int64?
    let metadata: JobMetadata?
    
    var isActive: Bool {
        status == .active || status == .waiting
    }
    
    var isFailed: Bool {
        status == .failed
    }
    
    var isCompleted: Bool {
        status == .completed
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Job, rhs: Job) -> Bool {
        lhs.id == rhs.id
    }
}

struct JobMetadata: Codable {
    let resolution: String?
    let exifData: [String: String]?
    let codec: String?
    let bitrate: Int?
}

enum JobStatus: String, Codable, CaseIterable {
    case waiting
    case active
    case completed
    case failed
    case paused
    case delayed
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var color: String {
        switch self {
        case .waiting: return "orange"
        case .active: return "blue"
        case .completed: return "green"
        case .failed: return "red"
        case .paused: return "gray"
        case .delayed: return "yellow"
        }
    }
}

// MARK: - Queue Models
struct Queue: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let displayName: String
    let count: Int
    let activeCount: Int
    let completedCount: Int
    let failedCount: Int
    let pausedCount: Int
    let delayedCount: Int
    let isPaused: Bool
    let activeWorkers: Int
    let maxWorkers: Int
    let averageProcessingTime: TimeInterval?
    let processingRate: Double? // jobs per minute
    
    var queueType: QueueType {
        QueueType(rawValue: name) ?? .other
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum QueueType: String, CaseIterable {
    case thumbnailGeneration = "thumbnail-generation"
    case metadataExtraction = "metadata-extraction"
    case smartSearch = "smart-search"
    case faceDetection = "face-detection"
    case videoTranscoding = "video-transcoding"
    case objectTagging = "object-tagging"
    case duplicateDetection = "duplicate-detection"
    case storageTemplateMigration = "storage-template-migration"
    case backgroundTask = "background-task"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .thumbnailGeneration: return "Thumbnail Generation"
        case .metadataExtraction: return "Metadata Extraction"
        case .smartSearch: return "Smart Search"
        case .faceDetection: return "Face Detection"
        case .videoTranscoding: return "Video Transcoding"
        case .objectTagging: return "Object Tagging"
        case .duplicateDetection: return "Duplicate Detection"
        case .storageTemplateMigration: return "Storage Template Migration"
        case .backgroundTask: return "Background Task"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .thumbnailGeneration: return "photo.on.rectangle"
        case .metadataExtraction: return "doc.text.magnifyingglass"
        case .smartSearch: return "magnifyingglass.circle"
        case .faceDetection: return "person.crop.rectangle"
        case .videoTranscoding: return "video.badge.waveform"
        case .objectTagging: return "tag"
        case .duplicateDetection: return "doc.on.doc"
        case .storageTemplateMigration: return "folder.badge.gearshape"
        case .backgroundTask: return "gearshape.2"
        case .other: return "square.grid.2x2"
        }
    }
}

// MARK: - Server Statistics
struct ServerStats: Codable {
    let totalAssets: Int
    let totalUsers: Int
    let totalStorage: Int64
    let cpuUsage: Double
    let memoryUsage: Double
    let activeWorkers: Int
    let jobsProcessedToday: Int
    let jobsFailedToday: Int
    let averageProcessingRate: Double // jobs per minute
    let timestamp: Date
}

// MARK: - Historical Metrics
struct HistoricalMetric: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let queueName: String?
    let metricType: MetricType
    let value: Double
    let metadata: String?
    
    init(id: UUID = UUID(), timestamp: Date = Date(), queueName: String? = nil, metricType: MetricType, value: Double, metadata: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.queueName = queueName
        self.metricType = metricType
        self.value = value
        self.metadata = metadata
    }
}

enum MetricType: String, Codable {
    case queueDepth
    case completionRate
    case errorRate
    case processingTime
    case cpuUsage
    case memoryUsage
    case activeWorkers
    case apiLatency
    case storageIO
}

// MARK: - Failed Job Record
struct FailedJobRecord: Codable, Identifiable, Hashable {
    let id: UUID
    let jobId: String
    let queueName: String
    let assetId: String?
    let assetName: String?
    let errorMessage: String
    let stackTrace: String?
    let failedAt: Date
    let retryCount: Int
    let fileType: String?
    let fileSize: Int64?
    let exifData: String? // JSON string
    let thumbnailPath: String?
    
    init(id: UUID = UUID(), jobId: String, queueName: String, assetId: String?, assetName: String?, errorMessage: String, stackTrace: String?, failedAt: Date, retryCount: Int, fileType: String?, fileSize: Int64?, exifData: String?, thumbnailPath: String?) {
        self.id = id
        self.jobId = jobId
        self.queueName = queueName
        self.assetId = assetId
        self.assetName = assetName
        self.errorMessage = errorMessage
        self.stackTrace = stackTrace
        self.failedAt = failedAt
        self.retryCount = retryCount
        self.fileType = fileType
        self.fileSize = fileSize
        self.exifData = exifData
        self.thumbnailPath = thumbnailPath
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: FailedJobRecord, rhs: FailedJobRecord) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Server Connection
struct ServerConnection: Codable, Identifiable {
    let id: UUID
    var name: String
    var serverURL: String
    var apiKey: String
    var pollingInterval: TimeInterval
    var isDefault: Bool
    
    init(id: UUID = UUID(), name: String, serverURL: String, apiKey: String, pollingInterval: TimeInterval = 3.0, isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.serverURL = serverURL
        self.apiKey = apiKey
        self.pollingInterval = pollingInterval
        self.isDefault = isDefault
    }
}

// MARK: - Worker Statistics
struct WorkerStats: Codable, Identifiable {
    let id: String
    let queueName: String
    let status: WorkerStatus
    let currentJobId: String?
    let jobsProcessed: Int
    let averageJobTime: TimeInterval
    let memoryUsage: Int64
    let cpuUsage: Double
    let uptime: TimeInterval
    let lastHeartbeat: Date
}

enum WorkerStatus: String, Codable {
    case active
    case idle
    case offline
    case error
    
    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - API Response Models
struct JobsResponse: Codable {
    // The API returns a dictionary of queue names to queue info
    // We'll decode this dynamically
}

struct ImmichJobsResponse: Codable {
    let thumbnailGeneration: QueueInfo?
    let metadataExtraction: QueueInfo?
    let videoConversion: QueueInfo?
    let smartSearch: QueueInfo?
    let storageTemplateMigration: QueueInfo?
    let migration: QueueInfo?
    let backgroundTask: QueueInfo?
    let search: QueueInfo?
    let duplicateDetection: QueueInfo?
    let faceDetection: QueueInfo?
    let facialRecognition: QueueInfo?
    let sidecar: QueueInfo?
    let library: QueueInfo?
    let notifications: QueueInfo?
    let backupDatabase: QueueInfo?
    let ocr: QueueInfo?
    let workflow: QueueInfo?
}

struct QueueInfo: Codable {
    let queueStatus: QueueStatus
    let jobCounts: JobCounts
}

struct QueueStatus: Codable {
    let isPaused: Bool
    let isActive: Bool
}

struct JobCounts: Codable {
    let active: Int
    let completed: Int
    let failed: Int
    let delayed: Int
    let waiting: Int
    let paused: Int
}

struct QueueResponse: Codable {
    let queues: [Queue]
}

struct ServerStatsResponse: Codable {
    let stats: ServerStats
}

// MARK: - Performance Profile
struct PerformanceProfile: Identifiable {
    let id = UUID()
    let jobType: QueueType
    let fileType: String?
    let averageTime: TimeInterval
    let minTime: TimeInterval
    let maxTime: TimeInterval
    let count: Int
    let totalSize: Int64?
}

// MARK: - Diagnostic Info
struct DiagnosticInfo: Codable {
    let postgresConnectionPool: PostgresPoolInfo
    let activeQueries: [ActiveQuery]
    let deadlocks: [DeadlockInfo]
    let apiLatency: TimeInterval
    let storageIOStats: StorageIOStats
    let memoryLeaks: [MemoryLeakWarning]
}

struct PostgresPoolInfo: Codable {
    let totalConnections: Int
    let activeConnections: Int
    let idleConnections: Int
    let waitingClients: Int
}

struct ActiveQuery: Codable, Identifiable {
    let id: String
    let query: String
    let duration: TimeInterval
    let state: String
}

struct DeadlockInfo: Codable, Identifiable {
    let id: UUID
    let detectedAt: Date
    let processes: [Int]
    let queries: [String]
}

struct StorageIOStats: Codable {
    let readSpeed: Double // MB/s
    let writeSpeed: Double // MB/s
    let iops: Int
    let latency: TimeInterval
}

struct MemoryLeakWarning: Codable, Identifiable {
    let id: UUID
    let workerId: String
    let initialMemory: Int64
    let currentMemory: Int64
    let growthRate: Double // MB per hour
    let detectedAt: Date
}
