import SwiftUI

struct PerformanceSettingsView: View {
    @AppStorage("useOptimizedTaskList") private var useOptimizedTaskList = true
    @AppStorage("enableFPSMonitoring") private var enableFPSMonitoring = true
    @AppStorage("enablePrefetching") private var enablePrefetching = true
    @AppStorage("maxTasksPerPage") private var maxTasksPerPage = 50.0
    @AppStorage("enableImageCaching") private var enableImageCaching = true
    @AppStorage("enableBatteryOptimization") private var enableBatteryOptimization = true
    
    @StateObject private var analytics = PerformanceAnalytics.shared
    @StateObject private var networkManager = NetworkOptimizationManager.shared
    @StateObject private var batteryManager = BatteryOptimizationManager.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section("UI Performance") {
                    Toggle("Use Optimized Task List", isOn: $useOptimizedTaskList)
                        .onChange(of: useOptimizedTaskList) { enabled in
                            if enabled {
                                // Enable optimizations
                                TaskCacheManager.shared.clearCache()
                            }
                        }
                    
                    Toggle("Enable FPS Monitoring", isOn: $enableFPSMonitoring)
                        .onChange(of: enableFPSMonitoring) { enabled in
                            if enabled {
                                analytics.startFPSMonitoring()
                            } else {
                                analytics.stopFPSMonitoring()
                            }
                        }
                    
                    VStack(alignment: .leading) {
                        Text("Tasks Per Page: \\(Int(maxTasksPerPage))")
                        Slider(value: $maxTasksPerPage, in: 20...100, step: 10)
                    }
                }
                
                Section("Data Management") {
                    Toggle("Enable Prefetching", isOn: $enablePrefetching)
                        .onChange(of: enablePrefetching) { enabled in
                            if !enabled {
                                PrefetchingManager.shared.cancelAllPrefetching()
                            }
                        }
                    
                    Toggle("Enable Image Caching", isOn: $enableImageCaching)
                        .onChange(of: enableImageCaching) { enabled in
                            if !enabled {
                                ImageCacheManager.shared.clearCache()
                            }
                        }
                    
                    Button("Clear All Caches") {
                        clearAllCaches()
                    }
                    .foregroundColor(.red)
                }
                
                Section("Battery Optimization") {
                    Toggle("Enable Battery Optimization", isOn: $enableBatteryOptimization)
                    
                    HStack {
                        Text("Battery Level")
                        Spacer()
                        Text("\\(Int(batteryManager.batteryLevel * 100))%")
                            .foregroundColor(batteryLevelColor)
                    }
                    
                    HStack {
                        Text("Low Power Mode")
                        Spacer()
                        Text(batteryManager.isLowPowerModeEnabled ? "Enabled" : "Disabled")
                            .foregroundColor(batteryManager.isLowPowerModeEnabled ? .orange : .secondary)
                    }
                }
                
                Section("Network Status") {
                    HStack {
                        Text("Connection")
                        Spacer()
                        Text(networkStatusText)
                            .foregroundColor(networkStatusColor)
                    }
                    
                    HStack {
                        Text("Low Data Mode")
                        Spacer()
                        Text(networkManager.isLowDataMode ? "Enabled" : "Disabled")
                            .foregroundColor(networkManager.isLowDataMode ? .orange : .secondary)
                    }
                }
                
                Section("Current Performance") {
                    HStack {
                        Text("FPS")
                        Spacer()
                        Text("\\(analytics.metrics.currentFPS, specifier: \"%.1f\")")
                            .foregroundColor(fpsColor)
                    }
                    
                    HStack {
                        Text("Memory Usage")
                        Spacer()
                        Text("\\(analytics.metrics.memoryUsageMB, specifier: \"%.1f\") MB")
                            .foregroundColor(memoryColor)
                    }
                    
                    HStack {
                        Text("Core Data Operations")
                        Spacer()
                        Text("\\(analytics.metrics.coreDataOperations)")
                    }
                }
                
                Section("Actions") {
                    Button("Force Memory Cleanup") {
                        performMemoryCleanup()
                    }
                    
                    Button("Generate Performance Report") {
                        sharePerformanceReport()
                    }
                }
            }
            .navigationTitle("Performance Settings")
        }
    }
    
    private var batteryLevelColor: Color {
        if batteryManager.batteryLevel > 0.5 { return .green }
        else if batteryManager.batteryLevel > 0.2 { return .orange }
        else { return .red }
    }
    
    private var networkStatusText: String {
        switch networkManager.networkStatus {
        case .wifi: return "WiFi"
        case .cellular: return "Cellular"
        case .offline: return "Offline"
        case .unknown: return "Unknown"
        }
    }
    
    private var networkStatusColor: Color {
        switch networkManager.networkStatus {
        case .wifi: return .green
        case .cellular: return .orange
        case .offline: return .red
        case .unknown: return .secondary
        }
    }
    
    private var fpsColor: Color {
        if analytics.metrics.currentFPS >= 55 { return .green }
        else if analytics.metrics.currentFPS >= 30 { return .orange }
        else { return .red }
    }
    
    private var memoryColor: Color {
        if analytics.metrics.memoryUsageMB < 100 { return .green }
        else if analytics.metrics.memoryUsageMB < 200 { return .orange }
        else { return .red }
    }
    
    private func clearAllCaches() {
        ImageCacheManager.shared.clearCache()
        TaskCacheManager.shared.clearCache()
        URLCache.shared.removeAllCachedResponses()
        
        // Show confirmation
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
    
    private func performMemoryCleanup() {
        // Force memory cleanup
        clearAllCaches()
        
        // Refresh Core Data contexts
        PerformanceOptimizedCoreDataStack.shared.persistentContainer.viewContext.refreshAllObjects()
        
        // Cancel prefetching
        PrefetchingManager.shared.cancelAllPrefetching()
        
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()
    }
    
    private func sharePerformanceReport() {
        let report = analytics.generatePerformanceReport()
        
        let activityVC = UIActivityViewController(
            activityItems: [report],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}