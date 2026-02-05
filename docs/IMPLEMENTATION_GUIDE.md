# Immich Job Queue Visualizer - Implementation Guide

## Project Overview

This is a comprehensive, production-ready native macOS application built with SwiftUI that provides real-time monitoring and management of Immich photo server job queues. The application follows Apple's Human Interface Guidelines and uses modern Swift concurrency patterns.

## Key Architectural Decisions

### 1. SwiftUI-First Design
- **Reasoning**: Native performance, automatic dark mode support, future-proof for Apple platforms
- **Trade-offs**: Requires macOS 13+, but gives us access to latest APIs like Swift Charts
- **Benefits**: Minimal code for complex UI, reactive updates via Combine

### 2. SQLite for Historical Data
- **Reasoning**: Lightweight, serverless, built-in on macOS, excellent for time-series data
- **Library**: SQLite.swift for type-safe Swift bindings
- **Schema**: Optimized indexes on timestamp and metric type for fast queries
- **Retention**: Configurable data retention (default 90 days)

### 3. Polling vs WebSocket
- **Current**: Timer-based polling (configurable interval)
- **Reasoning**: Simpler implementation, works with all Immich versions
- **Future**: WebSocket support can be added for real-time updates
- **Benefit**: Reliable fallback mechanism

### 4. Async/Await for Networking
- **Reasoning**: Modern Swift concurrency, easier error handling
- **Pattern**: All network calls are async, UI updates on MainActor
- **Error Handling**: Comprehensive error types with user-friendly messages

### 5. Menu Bar Integration
- **NSStatusItem**: Native menu bar presence
- **NSPopover**: Compact popover interface for quick access
- **Main Window**: Full dashboard remains accessible

## Code Structure

### Models.swift
Contains all data models that map to Immich API responses:
- `Job`: Individual job with status, progress, worker info
- `Queue`: Queue configuration and statistics
- `ServerStats`: Overall server health metrics
- `HistoricalMetric`: Time-series data points for analytics
- `FailedJobRecord`: Persistent record of job failures

**Design Pattern**: Codable for JSON serialization, Identifiable for SwiftUI lists

### ImmichService.swift
Central service layer for all Immich API interactions:
- **Connection Management**: Server URL, API key, polling configuration
- **API Methods**: Type-safe async methods for each endpoint
- **Error Handling**: Custom `ImmichError` enum with localized descriptions
- **Publishing**: Uses `@Published` properties for reactive UI updates
- **Polling**: Timer-based automatic refresh with configurable interval

**Key Methods**:
- `fetchAllJobs()`: Get all jobs across queues
- `pauseQueue()`, `resumeQueue()`: Queue control
- `retryJob()`, `cancelJob()`: Individual job management
- `fetchServerStats()`: System health metrics

### DatabaseManager.swift
SQLite database abstraction for historical data:
- **Tables**: historical_metrics, failed_job_records, performance_profiles
- **CRUD Operations**: Type-safe insert, fetch, delete operations
- **Aggregation**: Time-based aggregation for charts
- **Maintenance**: Vacuum, size monitoring, old data cleanup

**Performance**: Indexed queries for fast retrieval even with large datasets

### Views
Each view is a self-contained module with its own ViewModel:

**DashboardView**:
- Real-time stats cards
- Processing rate line chart
- Resource monitors (CPU, memory, workers)
- Live job list with progress bars
- Quick action buttons

**QueueManagementView**:
- Sidebar with queue list
- Main table with sortable columns
- Search and filter capabilities
- Batch selection and operations
- Context menus for individual actions

**AnalyticsView**:
- Job timeline (Gantt chart visualization)
- Performance profiling charts
- File type analysis
- Resource correlation graphs
- Trend analysis (7-day, 30-day)
- Outlier detection
- Predictive completion time

**DiagnosticsView**:
- PostgreSQL health monitoring
- Network latency tracking
- Storage I/O statistics
- Memory leak detection
- Real-time log viewer

**FailedJobsView**:
- Master-detail interface
- Full error messages and stack traces
- Asset metadata display
- Retry and delete actions

**SettingsView**:
- Server connection configuration
- Notification preferences
- Database maintenance
- Multiple profile support

## API Integration

### Endpoint Mapping
The app assumes these Immich API endpoints (adjust based on actual Immich version):

```
GET    /api/jobs                      # List all jobs
GET    /api/jobs/queues               # List all queues
GET    /api/jobs/{queueName}          # Get specific queue
POST   /api/jobs/{queueName}/pause    # Pause queue
POST   /api/jobs/{queueName}/resume   # Resume queue
POST   /api/jobs/{jobId}/retry        # Retry job
DELETE /api/jobs/{jobId}/cancel       # Cancel job
DELETE /api/jobs/completed            # Clear completed
GET    /api/server-info/stats         # Server statistics
GET    /api/diagnostics               # Diagnostic info
GET    /api/logs                      # Server logs
```

### Authentication
API key is sent in `x-api-key` header with every request.

### Response Handling
1. Decode JSON using Codable
2. Convert from snake_case (API) to camelCase (Swift)
3. Handle ISO 8601 date formats
4. Map to Swift models
5. Publish to UI via @Published properties

## Building and Distribution

### Development Build
```bash
# Using Swift Package Manager
swift build -c release

# Or open in Xcode
open ImmichJobQueueVisualizer.xcodeproj
# Press Cmd+R to build and run
```

### Creating an App Bundle (Xcode)
1. Open project in Xcode
2. Select "Any Mac" as target
3. Product > Archive
4. Distribute App > Copy App
5. Result: Standalone .app bundle

### App Signing
For distribution outside the Mac App Store:
1. Get Apple Developer ID certificate
2. Code sign the app bundle
3. Notarize with Apple
4. Create DMG for distribution

### Deployment
The app can be distributed as:
- Standalone .app bundle (drag to Applications)
- DMG disk image (recommended)
- PKG installer (for enterprise)

## Configuration

### UserDefaults Keys
- `serverURL`: Immich server base URL
- `apiKey`: Immich API key for authentication
- `pollingInterval`: Refresh interval in seconds
- Connection profiles stored as JSON array

### Database Location
`~/Library/Application Support/ImmichJobQueueVisualizer/metrics.db`

### Notification Settings
Uses macOS User Notification Center (UNUserNotificationCenter).
Requires user permission on first launch.

## Performance Considerations

### Polling Optimization
- **Default**: 3-second interval balances freshness and load
- **Adaptive**: Could implement adaptive polling based on activity
- **Background**: Timer continues even when app is in background

### Chart Performance
- Swift Charts automatically optimizes rendering
- Large datasets (>1000 points) are sampled for display
- Time-based aggregation reduces memory usage

### Database Performance
- Indexed timestamp columns for fast range queries
- Prepared statements via SQLite.swift
- Transaction batching for bulk inserts
- Automatic cleanup of old data

### Memory Management
- Lazy loading for large job lists
- Pagination for historical data
- Image previews loaded on-demand
- Proper cancellation of async tasks

## Error Handling

### Network Errors
- Connection failures: Show alert, keep retrying
- HTTP errors: Parse error response, show to user
- Timeout: Configurable timeout with retry logic

### Database Errors
- Locked database: Retry with exponential backoff
- Corruption: Offer to reset database
- Disk full: Alert user, stop recording metrics

### API Errors
- Invalid response: Log details, show user-friendly message
- Missing endpoints: Graceful degradation, disable feature
- Rate limiting: Implement backoff strategy

## Testing Strategy

### Unit Tests
- Test models: Codable serialization/deserialization
- Test database: CRUD operations, aggregations
- Test API client: Mock responses, error scenarios

### Integration Tests
- Test full data flow: API → Models → Database → UI
- Test error recovery
- Test performance under load

### UI Tests
- Test navigation flows
- Test user interactions
- Test accessibility features

## Future Enhancements

### High Priority
1. **WebSocket Support**: Real-time updates without polling
2. **Worker Tuning Wizard**: Automated concurrency testing
3. **Enhanced Notifications**: Rich notifications with inline actions

### Medium Priority
1. **Prometheus Integration**: Export metrics for monitoring
2. **AppleScript Support**: Automation capabilities
3. **Multiple Profiles**: Easy switching between dev/prod servers

### Low Priority
1. **iOS Companion App**: View status on iPhone/iPad
2. **CLI Tool**: Remote management from terminal
3. **Plugins System**: Extensibility for custom features

## Troubleshooting

### Common Issues

**Build Errors**:
- Ensure Xcode 15+ installed
- Clean build folder: Product > Clean Build Folder
- Delete derived data: ~/Library/Developer/Xcode/DerivedData

**Runtime Errors**:
- Check Console.app for crash logs
- Verify Immich server is reachable
- Test API key with curl/Postman

**Performance Issues**:
- Increase polling interval
- Vacuum database
- Check Immich server performance

## Development Environment

### Requirements
- macOS 13.0+ (for development and running)
- Xcode 15.0+
- Swift 5.9+
- Command Line Tools

### Recommended Tools
- SF Symbols app (for icon exploration)
- Proxyman/Charles (for API debugging)
- Instruments (for performance profiling)

## Contributing

### Code Standards
- Follow Swift API Design Guidelines
- Use SwiftLint for code style
- Document public APIs
- Write tests for new features
- Update README for user-facing changes

### Git Workflow
1. Fork repository
2. Create feature branch
3. Make changes with descriptive commits
4. Add tests
5. Update documentation
6. Submit pull request

## License

MIT License - see LICENSE file

## Contact

For questions, issues, or contributions:
- GitHub Issues: For bug reports and feature requests
- GitHub Discussions: For questions and community support

---

**Note**: This implementation provides a solid foundation. Some advanced features (WebSocket, Prometheus, AppleScript) are designed but not fully implemented, allowing for future expansion.
