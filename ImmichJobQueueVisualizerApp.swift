//
//  ImmichJobQueueVisualizerApp.swift
//  Immich Job Queue Visualizer
//
//  A comprehensive macOS application for monitoring and managing Immich photo server job queues
//  Built with SwiftUI and native macOS frameworks
//

import SwiftUI

@main
struct ImmichJobQueueVisualizerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 1200, minHeight: 800)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Actions") {
                Button("Pause All Jobs") {
                    Task {
                        await appState.immichService.pauseAllQueues()
                    }
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                
                Button("Resume All Jobs") {
                    Task {
                        await appState.immichService.resumeAllQueues()
                    }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Retry Failed Jobs") {
                    Task {
                        await appState.immichService.retryFailedJobs()
                    }
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                
                Button("Clear Completed Jobs") {
                    Task {
                        await appState.immichService.clearCompletedJobs()
                    }
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
            }
            
            CommandMenu("View") {
                Button("Dashboard") {
                    appState.selectedView = .dashboard
                }
                .keyboardShortcut("1", modifiers: .command)
                
                Button("Queue Management") {
                    appState.selectedView = .queueManagement
                }
                .keyboardShortcut("2", modifiers: .command)
                
                Button("Analytics") {
                    appState.selectedView = .analytics
                }
                .keyboardShortcut("3", modifiers: .command)
                
                Button("Diagnostics") {
                    appState.selectedView = .diagnostics
                }
                .keyboardShortcut("4", modifiers: .command)
                
                Button("Failed Jobs") {
                    appState.selectedView = .failedJobs
                }
                .keyboardShortcut("5", modifiers: .command)
            }
        }
        
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

// MARK: - App Delegate for Menu Bar Support
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var menuBarPopover: NSPopover?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "photo.stack", accessibilityDescription: "Immich Queue")
            button.action = #selector(toggleMenuBarPopover)
            button.target = self
        }
    }
    
    @objc func toggleMenuBarPopover() {
        if let button = statusItem?.button {
            if menuBarPopover == nil {
                menuBarPopover = NSPopover()
                menuBarPopover?.contentSize = NSSize(width: 400, height: 600)
                menuBarPopover?.behavior = .transient
                menuBarPopover?.contentViewController = NSHostingController(
                    rootView: MenuBarView()
                        .environmentObject(AppState.shared)
                )
            }
            
            if let popover = menuBarPopover {
                if popover.isShown {
                    popover.performClose(nil)
                } else {
                    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                }
            }
        }
    }
}

// MARK: - App State Management
class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var selectedView: AppView = .dashboard
    @Published var isConnected = false
    @Published var lastUpdateTime: Date?
    @Published var connectionError: String?
    @Published var serverStats: ServerStats?
    
    let immichService: ImmichService
    let databaseManager: DatabaseManager
    let notificationManager: NotificationManager
    
    init() {
        self.immichService = ImmichService()
        self.databaseManager = DatabaseManager()
        self.notificationManager = NotificationManager()
        
        setupObservers()
    }
    
    private func setupObservers() {
        immichService.$isConnected
            .assign(to: &$isConnected)
        
        immichService.$lastUpdateTime
            .assign(to: &$lastUpdateTime)
        
        immichService.$serverStats
            .assign(to: &$serverStats)
    }
}

enum AppView {
    case dashboard
    case queueManagement
    case analytics
    case diagnostics
    case failedJobs
    case settings
}
