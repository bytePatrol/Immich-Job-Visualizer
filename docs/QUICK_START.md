# Quick Start Guide - Immich Job Queue Visualizer

Get up and running with the Immich Job Queue Visualizer in 5 minutes!

## Step 1: Installation

### Option A: Download Pre-built App (Recommended)
1. Download the latest release from GitHub
2. Unzip the downloaded file
3. Drag `ImmichJobQueueVisualizer.app` to your Applications folder
4. Double-click to launch

### Option B: Build from Source
```bash
git clone https://github.com/yourusername/immich-job-queue-visualizer.git
cd immich-job-queue-visualizer
./build.sh
```

## Step 2: Get Your Immich API Key

1. Open your Immich web interface (usually http://your-server:2283)
2. Click your profile icon in the top right
3. Go to "Account Settings"
4. Click "API Keys" in the sidebar
5. Click "New API Key"
6. Give it a name: "Queue Visualizer"
7. Click "Create" and copy the key (you won't see it again!)

## Step 3: Configure the App

1. Launch Immich Queue Visualizer
2. Press `Cmd+,` to open Settings (or menu: Immich Job Queue Visualizer > Settings)
3. Enter your details:
   ```
   Server URL: http://YOUR-SERVER-IP:2283
   API Key: [paste your key here]
   Polling Interval: 3 seconds (recommended)
   ```
4. Click "Test Connection" - you should see "✓ Connection Successful"
5. Click "Save Settings"

## Step 4: Explore the Dashboard

You should now see:
- ✅ Green connection indicator
- 📊 Four stat cards showing your job counts
- 📈 A live processing rate graph
- 🔄 System resource monitors
- 📋 List of currently processing jobs

### Understanding the Dashboard

**Stat Cards**:
- **Active Jobs**: Jobs currently being processed
- **Queued Count**: Jobs waiting to be processed
- **Completed Today**: Successfully finished jobs since midnight
- **Failed Jobs**: Jobs that encountered errors

**Quick Actions**:
- **Pause All**: Temporarily stop all queue processing
- **Resume All**: Restart all paused queues
- **Clear Completed**: Remove completed jobs from the queue
- **Retry Failed**: Re-queue all failed jobs for another attempt

## Step 5: Manage Your Queues

1. Press `Cmd+2` or click "Queue Management" in the sidebar
2. Select a queue from the left (e.g., "Thumbnail Generation")
3. View all jobs in that queue with detailed information

### Queue Management Features

**Filtering**:
- Click the filter button to show only specific job statuses
- Use the search bar to find specific assets
- Sort by clicking column headers

**Batch Operations**:
1. Select multiple jobs (Cmd+Click or Shift+Click)
2. Use toolbar buttons: Pause, Resume, Cancel, or Retry
3. Right-click for more options

## Step 6: Analyze Performance

1. Press `Cmd+3` or click "Analytics & Insights"
2. Review performance trends:
   - Which queues are slowest?
   - Which file types take longest?
   - Are there any outliers (unusually slow jobs)?

**Time Range Selection**:
- Toggle between 24 Hours, 7 Days, or 30 Days
- Watch trends over time
- Identify patterns and bottlenecks

## Step 7: Monitor System Health

1. Press `Cmd+4` or click "Diagnostics"
2. Check:
   - PostgreSQL connection pool usage
   - API latency (should be under 100ms)
   - Storage I/O speeds
   - Any memory leaks

**Warning Signs**:
- 🔴 Red indicators mean action needed
- 🟡 Yellow means caution
- 🟢 Green means all good

## Step 8: Handle Failed Jobs

1. Press `Cmd+5` or click "Failed Jobs"
2. Select a failed job to see details:
   - Error message
   - Stack trace (for debugging)
   - Asset information
3. Click "Retry Job" to try again
4. Or "Delete Record" to dismiss

## Menu Bar Mode

The app also runs in your menu bar for quick access:

1. Click the photo stack icon in your menu bar
2. View quick stats
3. Access quick actions
4. Click "Open Dashboard" for full interface

## Keyboard Shortcuts

Essential shortcuts to memorize:

| Shortcut | Action |
|----------|--------|
| `Cmd+1` | Dashboard |
| `Cmd+2` | Queue Management |
| `Cmd+3` | Analytics |
| `Cmd+Shift+P` | Pause All |
| `Cmd+Shift+R` | Resume All |
| `Cmd+,` | Settings |

## Tips for Daily Use

### Morning Routine
1. Check Dashboard for overnight processing
2. Review Failed Jobs
3. Check Analytics for any performance degradation

### Performance Optimization
1. Monitor CPU and Memory usage
2. If queues are backing up:
   - Check Diagnostics for bottlenecks
   - Consider increasing worker count in Immich
   - Pause non-critical queues during peak hours

### Notification Setup
1. Go to Settings > Notifications
2. Enable alerts for:
   - Queue stalls (no progress for 10+ minutes)
   - High error rate (>10 failed jobs per hour)
   - Worker offline events

## Common Tasks

### Pause Jobs During Backups
```
1. Click "Pause All" in Dashboard
2. Wait for active jobs to complete
3. Run your backup
4. Click "Resume All" when done
```

### Clear Out Old Failed Jobs
```
1. Go to Failed Jobs view
2. Select old jobs (Shift+Click for range)
3. Click "Delete Record"
```

### Export Performance Report
```
1. Go to Analytics view
2. Take screenshots of key charts
3. Or use Settings > Database > Export to CSV
```

## Troubleshooting

### "Connection Failed"
- ✅ Check server URL is correct (include http://)
- ✅ Verify Immich is running
- ✅ Test API key in Immich web UI
- ✅ Check firewall isn't blocking connection

### "No Data Available" in Charts
- ✅ Wait a few minutes for metrics to collect
- ✅ Check that jobs are actually running
- ✅ Verify polling is working (check last update time)

### App is Slow
- ✅ Increase polling interval (Settings)
- ✅ Clear old metrics (Settings > Database > Vacuum)
- ✅ Close other resource-intensive apps

### Jobs Stuck in "Active" State
- ✅ Check Immich server health
- ✅ Review Diagnostics for deadlocks
- ✅ May need to restart Immich workers

## Getting Help

- **Documentation**: See README.md for detailed info
- **GitHub Issues**: Report bugs or request features
- **Immich Community**: Discord/Reddit for Immich-specific questions

## Next Steps

Now that you're set up:
1. ⭐ Star the project on GitHub
2. 📢 Share with other Immich users
3. 🐛 Report bugs or suggest features
4. 🤝 Contribute improvements

Enjoy monitoring your Immich queues! 🎉

---

**Pro Tip**: Keep the app running in the background with menu bar mode enabled. You'll get notifications when issues arise, and you can quickly check status without opening the full interface.
