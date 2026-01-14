//
//  DatabaseManager.swift
//  SQLite database management for historical metrics and analytics
//

import Foundation
import SQLite

class DatabaseManager {
    private var db: Connection?
    private let databasePath: String
    
    // Table definitions
    private let historicalMetrics = Table("historical_metrics")
    private let failedJobRecords = Table("failed_job_records")
    private let performanceProfiles = Table("performance_profiles")
    
    // Column definitions for historical_metrics
    private let id = Expression<String>("id")
    private let timestamp = Expression<Date>("timestamp")
    private let queueName = Expression<String?>("queue_name")
    private let metricType = Expression<String>("metric_type")
    private let value = Expression<Double>("value")
    private let metadata = Expression<String?>("metadata")
    
    // Column definitions for failed_job_records
    private let recordId = Expression<String>("id")
    private let jobId = Expression<String>("job_id")
    private let recordQueueName = Expression<String>("queue_name")
    private let assetId = Expression<String?>("asset_id")
    private let assetName = Expression<String?>("asset_name")
    private let errorMessage = Expression<String>("error_message")
    private let stackTrace = Expression<String?>("stack_trace")
    private let failedAt = Expression<Date>("failed_at")
    private let retryCount = Expression<Int>("retry_count")
    private let fileType = Expression<String?>("file_type")
    private let fileSize = Expression<Int64?>("file_size")
    private let exifData = Expression<String?>("exif_data")
    private let thumbnailPath = Expression<String?>("thumbnail_path")
    
    init() {
        // Store database in Application Support directory
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("ImmichJobQueueVisualizer", isDirectory: true)
        
        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        
        databasePath = appDirectory.appendingPathComponent("metrics.db").path
        
        do {
            db = try Connection(databasePath)
            try createTables()
        } catch {
            print("Database initialization error: \(error)")
        }
    }
    
    // MARK: - Table Creation
    
    private func createTables() throws {
        try db?.run(historicalMetrics.create(ifNotExists: true) { table in
            table.column(id, primaryKey: true)
            table.column(timestamp)
            table.column(queueName)
            table.column(metricType)
            table.column(value)
            table.column(metadata)
        })
        
        try db?.run(historicalMetrics.createIndex(timestamp, ifNotExists: true))
        try db?.run(historicalMetrics.createIndex(metricType, ifNotExists: true))
        
        try db?.run(failedJobRecords.create(ifNotExists: true) { table in
            table.column(recordId, primaryKey: true)
            table.column(jobId)
            table.column(recordQueueName)
            table.column(assetId)
            table.column(assetName)
            table.column(errorMessage)
            table.column(stackTrace)
            table.column(failedAt)
            table.column(retryCount)
            table.column(fileType)
            table.column(fileSize)
            table.column(exifData)
            table.column(thumbnailPath)
        })
        
        try db?.run(failedJobRecords.createIndex(failedAt, ifNotExists: true))
        try db?.run(failedJobRecords.createIndex(recordQueueName, ifNotExists: true))
        
        try db?.run(performanceProfiles.create(ifNotExists: true) { table in
            table.column(id, primaryKey: true)
            table.column(queueName)
            table.column(fileType)
            table.column(Expression<Double>("average_time"))
            table.column(Expression<Double>("min_time"))
            table.column(Expression<Double>("max_time"))
            table.column(Expression<Int>("count"))
            table.column(Expression<Int64?>("total_size"))
            table.column(timestamp)
        })
    }
    
    // MARK: - Historical Metrics
    
    func recordMetric(_ metric: HistoricalMetric) {
        do {
            try db?.run(historicalMetrics.insert(
                id <- metric.id.uuidString,
                timestamp <- metric.timestamp,
                queueName <- metric.queueName,
                metricType <- metric.metricType.rawValue,
                value <- metric.value,
                metadata <- metric.metadata
            ))
        } catch {
            print("Error recording metric: \(error)")
        }
    }
    
    func recordMetrics(_ metrics: [HistoricalMetric]) {
        for metric in metrics {
            recordMetric(metric)
        }
    }
    
    func fetchMetrics(
        type: MetricType,
        queueName: String? = nil,
        since: Date? = nil,
        until: Date? = nil
    ) -> [HistoricalMetric] {
        guard let db = db else { return [] }
        
        var query = historicalMetrics
            .filter(metricType == type.rawValue)
            .order(timestamp.desc)
        
        if let queueName = queueName {
            query = query.filter(self.queueName == queueName)
        }
        
        if let since = since {
            query = query.filter(timestamp >= since)
        }
        
        if let until = until {
            query = query.filter(timestamp <= until)
        }
        
        do {
            return try db.prepare(query).map { row in
                HistoricalMetric(
                    id: UUID(uuidString: row[id]) ?? UUID(),
                    timestamp: row[timestamp],
                    queueName: row[self.queueName],
                    metricType: MetricType(rawValue: row[metricType]) ?? .queueDepth,
                    value: row[value],
                    metadata: row[metadata]
                )
            }
        } catch {
            print("Error fetching metrics: \(error)")
            return []
        }
    }
    
    func aggregateMetrics(
        type: MetricType,
        queueName: String? = nil,
        since: Date,
        groupBy: TimeInterval = 3600 // Default: 1 hour
    ) -> [(timestamp: Date, average: Double)] {
        // This would perform time-based aggregation
        // Simplified implementation - in production, use SQL aggregation functions
        let metrics = fetchMetrics(type: type, queueName: queueName, since: since)
        
        var buckets: [Date: [Double]] = [:]
        
        for metric in metrics {
            let bucketTime = Date(timeIntervalSince1970: floor(metric.timestamp.timeIntervalSince1970 / groupBy) * groupBy)
            buckets[bucketTime, default: []].append(metric.value)
        }
        
        return buckets.map { (timestamp: $0.key, average: $0.value.reduce(0, +) / Double($0.value.count)) }
            .sorted { $0.timestamp < $1.timestamp }
    }
    
    func deleteOldMetrics(olderThan: Date) {
        do {
            let query = historicalMetrics.filter(timestamp < olderThan)
            try db?.run(query.delete())
        } catch {
            print("Error deleting old metrics: \(error)")
        }
    }
    
    // MARK: - Failed Job Records
    
    func recordFailedJob(_ record: FailedJobRecord) {
        do {
            try db?.run(failedJobRecords.insert(
                recordId <- record.id.uuidString,
                jobId <- record.jobId,
                recordQueueName <- record.queueName,
                assetId <- record.assetId,
                assetName <- record.assetName,
                errorMessage <- record.errorMessage,
                stackTrace <- record.stackTrace,
                failedAt <- record.failedAt,
                retryCount <- record.retryCount,
                fileType <- record.fileType,
                fileSize <- record.fileSize,
                exifData <- record.exifData,
                thumbnailPath <- record.thumbnailPath
            ))
        } catch {
            print("Error recording failed job: \(error)")
        }
    }
    
    func fetchFailedJobs(
        queueName: String? = nil,
        since: Date? = nil,
        limit: Int = 100
    ) -> [FailedJobRecord] {
        guard let db = db else { return [] }
        
        var query = failedJobRecords.order(failedAt.desc).limit(limit)
        
        if let queueName = queueName {
            query = query.filter(recordQueueName == queueName)
        }
        
        if let since = since {
            query = query.filter(failedAt >= since)
        }
        
        do {
            return try db.prepare(query).map { row in
                FailedJobRecord(
                    id: UUID(uuidString: row[recordId]) ?? UUID(),
                    jobId: row[jobId],
                    queueName: row[recordQueueName],
                    assetId: row[assetId],
                    assetName: row[assetName],
                    errorMessage: row[errorMessage],
                    stackTrace: row[stackTrace],
                    failedAt: row[failedAt],
                    retryCount: row[retryCount],
                    fileType: row[fileType],
                    fileSize: row[fileSize],
                    exifData: row[exifData],
                    thumbnailPath: row[thumbnailPath]
                )
            }
        } catch {
            print("Error fetching failed jobs: \(error)")
            return []
        }
    }
    
    func updateRetryCount(jobId: String) {
        do {
            let job = failedJobRecords.filter(self.jobId == jobId)
            try db?.run(job.update(retryCount <- retryCount + 1))
        } catch {
            print("Error updating retry count: \(error)")
        }
    }
    
    func deleteFailedJob(id: UUID) {
        do {
            let job = failedJobRecords.filter(recordId == id.uuidString)
            try db?.run(job.delete())
        } catch {
            print("Error deleting failed job: \(error)")
        }
    }
    
    // MARK: - Performance Profiles
    
    func recordPerformanceProfile(
        queueName: String,
        fileType: String?,
        averageTime: TimeInterval,
        minTime: TimeInterval,
        maxTime: TimeInterval,
        count: Int,
        totalSize: Int64?
    ) {
        do {
            try db?.run(performanceProfiles.insert(
                id <- UUID().uuidString,
                self.queueName <- queueName,
                self.fileType <- fileType,
                Expression<Double>("average_time") <- averageTime,
                Expression<Double>("min_time") <- minTime,
                Expression<Double>("max_time") <- maxTime,
                Expression<Int>("count") <- count,
                Expression<Int64?>("total_size") <- totalSize,
                timestamp <- Date()
            ))
        } catch {
            print("Error recording performance profile: \(error)")
        }
    }
    
    func fetchPerformanceProfiles(queueName: String? = nil, since: Date? = nil) -> [PerformanceProfile] {
        guard let db = db else { return [] }
        
        var query = performanceProfiles.order(timestamp.desc)
        
        if let queueName = queueName {
            query = query.filter(self.queueName == queueName)
        }
        
        if let since = since {
            query = query.filter(timestamp >= since)
        }
        
        do {
            return try db.prepare(query).map { row in
                PerformanceProfile(
                    jobType: QueueType(rawValue: row[self.queueName] ?? "other") ?? .other,
                    fileType: row[fileType],
                    averageTime: row[Expression<Double>("average_time")],
                    minTime: row[Expression<Double>("min_time")],
                    maxTime: row[Expression<Double>("max_time")],
                    count: row[Expression<Int>("count")],
                    totalSize: row[Expression<Int64?>("total_size")]
                )
            }
        } catch {
            print("Error fetching performance profiles: \(error)")
            return []
        }
    }
    
    // MARK: - Database Maintenance
    
    func vacuum() {
        do {
            try db?.run("VACUUM")
        } catch {
            print("Error vacuuming database: \(error)")
        }
    }
    
    func getDatabaseSize() -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: databasePath)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    func exportToCSV(table: String, outputPath: String) throws {
        // Export table data to CSV file
        // Implementation would query the table and write CSV format
    }
}
