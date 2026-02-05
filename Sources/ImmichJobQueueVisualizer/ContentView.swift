//
//  ContentView.swift
//  Main content view with navigation sidebar
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedSidebarItem: SidebarItem = .dashboard
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(SidebarItem.allCases, id: \.self, selection: $selectedSidebarItem) { item in
                NavigationLink(value: item) {
                    Label(item.title, systemImage: item.icon)
                }
            }
            .navigationTitle("Immich Queue")
            .listStyle(.sidebar)
        } detail: {
            // Main content area
            Group {
                switch selectedSidebarItem {
                case .dashboard:
                    DashboardView()
                case .queueManagement:
                    QueueManagementView()
                case .analytics:
                    AnalyticsView()
                case .diagnostics:
                    DiagnosticsView()
                case .failedJobs:
                    FailedJobsView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

enum SidebarItem: String, CaseIterable {
    case dashboard
    case queueManagement
    case analytics
    case diagnostics
    case failedJobs
    case settings
    
    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .queueManagement: return "Queue Management"
        case .analytics: return "Analytics & Insights"
        case .diagnostics: return "Diagnostics"
        case .failedJobs: return "Failed Jobs"
        case .settings: return "Settings"
        }
    }
    
    var icon: String {
        switch self {
        case .dashboard: return "gauge"
        case .queueManagement: return "list.bullet.rectangle"
        case .analytics: return "chart.bar.xaxis"
        case .diagnostics: return "stethoscope"
        case .failedJobs: return "exclamationmark.triangle"
        case .settings: return "gearshape"
        }
    }
}
