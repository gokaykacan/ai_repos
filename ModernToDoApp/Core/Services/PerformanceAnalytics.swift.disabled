import Foundation
import Combine
import UIKit
import SwiftUI

// MARK: - Performance Analytics Manager

class PerformanceAnalytics: ObservableObject {
    static let shared = PerformanceAnalytics()
    
    @Published var metrics: PerformanceMetrics = PerformanceMetrics()
    
    private var displayLink: CADisplayLink?
    private var frameTimeStamps: [CFTimeInterval] = []
    private var memoryObserver: NSObjectProtocol?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    private init() {
        setupPerformanceMonitoring()
        setupMemoryMonitoring()
        setupBackgroundTaskHandling()
    }
    
    deinit {
        stopFPSMonitoring()
        if let observer = memoryObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - FPS Monitoring
    
    func startFPSMonitoring() {
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkTick))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    func stopFPSMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func displayLinkTick(_ displayLink: CADisplayLink) {
        frameTimeStamps.append(displayLink.timestamp)
        
        // Keep only the last second of frame timestamps
        let cutoffTime = displayLink.timestamp - 1.0
        frameTimeStamps.removeAll { $0 < cutoffTime }
        
        DispatchQueue.main.async {
            self.metrics.currentFPS = Double(self.frameTimeStamps.count)
            self.metrics.averageFPS = self.calculateAverageFPS()
        }
    }
    
    private func calculateAverageFPS() -> Double {
        guard frameTimeStamps.count > 1 else { return 0 }
        
        let timeSpan = frameTimeStamps.last! - frameTimeStamps.first!
        return Double(frameTimeStamps.count - 1) / timeSpan
    }
    
    // MARK: - Memory Monitoring
    
    private func setupMemoryMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateMemoryUsage()
        }
        
        memoryObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.metrics.memoryWarningCount += 1
            self?.handleMemoryWarning()
        }
    }
    
    private func updateMemoryUsage() {
        let memoryInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &memoryInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let memoryUsageMB = Double(memoryInfo.resident_size) / 1024 / 1024
            DispatchQueue.main.async {
                self.metrics.memoryUsageMB = memoryUsageMB
                if memoryUsageMB > self.metrics.peakMemoryUsageMB {
                    self.metrics.peakMemoryUsageMB = memoryUsageMB
                }
            }
        }
    }
    
    private func handleMemoryWarning() {
        // Clear caches
        ImageCacheManager.shared.clearCache()
        TaskCacheManager.shared.clearCache()
        
        // Force garbage collection
        DispatchQueue.global(qos: .utility).async {
            autoreleasepool {
                // This will help release any autoreleased objects
            }
        }
    }
    
    // MARK: - Performance Monitoring Setup
    
    private func setupPerformanceMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            self.collectPerformanceMetrics()
        }
    }
    
    private func collectPerformanceMetrics() {
        // Collect Core Data metrics
        let coreDataMetrics = CoreDataPerformanceMonitor.shared.getPerformanceMetrics()
        
        DispatchQueue.main.async {
            self.metrics.coreDataOperations = coreDataMetrics.count
            self.metrics.averageCoreDataTime = coreDataMetrics.values.reduce(0, +) / Double(max(coreDataMetrics.count, 1))
            
            // Check for slow operations
            let slowOperations = coreDataMetrics.filter { $0.value > 0.1 }
            self.metrics.slowOperationsCount = slowOperations.count
        }
        
        // Collect battery usage
        updateBatteryUsage()
    }
    
    private func updateBatteryUsage() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel = UIDevice.current.batteryLevel
        let batteryState = UIDevice.current.batteryState
        
        DispatchQueue.main.async {
            self.metrics.batteryLevel = Double(batteryLevel)
            self.metrics.batteryState = batteryState
        }
    }
    
    // MARK: - Background Task Handling
    
    private func setupBackgroundTaskHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "PerformanceCleanup") {
            self.endBackgroundTask()
        }
        
        // Perform cleanup
        ImageCacheManager.shared.clearCache()
        CoreDataPerformanceMonitor.shared.clearMetrics()
    }
    
    @objc private func appWillEnterForeground() {
        endBackgroundTask()
        startFPSMonitoring()
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
    
    // MARK: - Network Optimization
    
    func optimizeNetworkRequests() {
        URLCache.shared.memoryCapacity = 10 * 1024 * 1024 // 10MB
        URLCache.shared.diskCapacity = 50 * 1024 * 1024   // 50MB
    }
    
    // MARK: - Metrics Export
    
    func exportMetrics() -> [String: Any] {
        return [
            "currentFPS": metrics.currentFPS,
            "averageFPS": metrics.averageFPS,
            "memoryUsageMB": metrics.memoryUsageMB,
            "peakMemoryUsageMB": metrics.peakMemoryUsageMB,
            "memoryWarningCount": metrics.memoryWarningCount,
            "coreDataOperations": metrics.coreDataOperations,
            "averageCoreDataTime": metrics.averageCoreDataTime,
            "slowOperationsCount": metrics.slowOperationsCount,
            "batteryLevel": metrics.batteryLevel,
            "batteryState": metrics.batteryState.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ]
    }
    
    func generatePerformanceReport() -> String {
        let report = """
        📊 Performance Report
        ====================
        
        🎮 Frame Rate:
        • Current FPS: \(String(format: "%.1f", metrics.currentFPS))
        • Average FPS: \(String(format: "%.1f", metrics.averageFPS))
        
        💾 Memory Usage:
        • Current: \(String(format: "%.1f MB", metrics.memoryUsageMB))
        • Peak: \(String(format: "%.1f MB", metrics.peakMemoryUsageMB))
        • Memory Warnings: \(metrics.memoryWarningCount)
        
        🗄️ Core Data Performance:
        • Operations: \(metrics.coreDataOperations)
        • Average Time: \(String(format: "%.3fs", metrics.averageCoreDataTime))
        • Slow Operations: \(metrics.slowOperationsCount)
        
        🔋 Battery:
        • Level: \(String(format: "%.0f%%", metrics.batteryLevel * 100))
        • State: \(batteryStateDescription)
        
        📱 Device Info:
        • Model: \(UIDevice.current.model)
        • iOS Version: \(UIDevice.current.systemVersion)
        """
        
        return report
    }
    
    private var batteryStateDescription: String {
        switch metrics.batteryState {
        case .unknown: return "Unknown"
        case .unplugged: return "Unplugged"
        case .charging: return "Charging"
        case .full: return "Full"
        @unknown default: return "Unknown"
        }
    }
}

// MARK: - Performance Metrics Model

struct PerformanceMetrics {
    var currentFPS: Double = 0
    var averageFPS: Double = 0
    var memoryUsageMB: Double = 0
    var peakMemoryUsageMB: Double = 0
    var memoryWarningCount: Int = 0
    var coreDataOperations: Int = 0
    var averageCoreDataTime: Double = 0
    var slowOperationsCount: Int = 0
    var batteryLevel: Double = 0
    var batteryState: UIDevice.BatteryState = .unknown
}

// MARK: - Performance View

struct PerformanceMonitorView: View {
    @StateObject private var analytics = PerformanceAnalytics.shared
    @State private var showingReport = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Frame Rate") {
                    HStack {
                        Text("Current FPS")
                        Spacer()
                        Text("\(analytics.metrics.currentFPS, specifier: "%.1f")")
                            .foregroundColor(fpsColor(analytics.metrics.currentFPS))
                    }
                    
                    HStack {
                        Text("Average FPS")
                        Spacer()
                        Text("\(analytics.metrics.averageFPS, specifier: "%.1f")")
                            .foregroundColor(fpsColor(analytics.metrics.averageFPS))
                    }
                }
                
                Section("Memory") {
                    HStack {
                        Text("Current Usage")
                        Spacer()
                        Text("\(analytics.metrics.memoryUsageMB, specifier: "%.1f") MB")
                            .foregroundColor(memoryColor(analytics.metrics.memoryUsageMB))
                    }
                    
                    HStack {
                        Text("Peak Usage")
                        Spacer()
                        Text("\(analytics.metrics.peakMemoryUsageMB, specifier: "%.1f") MB")
                    }
                    
                    HStack {
                        Text("Memory Warnings")
                        Spacer()
                        Text("\(analytics.metrics.memoryWarningCount)")
                            .foregroundColor(analytics.metrics.memoryWarningCount > 0 ? .red : .green)
                    }
                }
                
                Section("Core Data") {
                    HStack {
                        Text("Operations Count")
                        Spacer()
                        Text("\(analytics.metrics.coreDataOperations)")
                    }
                    
                    HStack {
                        Text("Average Time")
                        Spacer()
                        Text("\(analytics.metrics.averageCoreDataTime, specifier: "%.3f")s")
                    }
                    
                    HStack {
                        Text("Slow Operations")
                        Spacer()
                        Text("\(analytics.metrics.slowOperationsCount)")
                            .foregroundColor(analytics.metrics.slowOperationsCount > 0 ? .orange : .green)
                    }
                }
                
                Section("Battery") {
                    HStack {
                        Text("Level")
                        Spacer()
                        Text("\(analytics.metrics.batteryLevel * 100, specifier: "%.0f")%")
                    }
                    
                    HStack {
                        Text("State")
                        Spacer()
                        Text(batteryStateText)
                    }
                }
            }
            .navigationTitle("Performance")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Report") {
                        showingReport = true
                    }
                }
            }
            .sheet(isPresented: $showingReport) {
                NavigationView {
                    ScrollView {
                        Text(analytics.generatePerformanceReport())
                            .font(.system(.body, design: .monospaced))
                            .padding()
                    }
                    .navigationTitle("Performance Report")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingReport = false
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            analytics.startFPSMonitoring()
        }
        .onDisappear {
            analytics.stopFPSMonitoring()
        }
    }
    
    private func fpsColor(_ fps: Double) -> Color {
        if fps >= 55 { return .green }
        else if fps >= 30 { return .orange }
        else { return .red }
    }
    
    private func memoryColor(_ memory: Double) -> Color {
        if memory < 100 { return .green }
        else if memory < 200 { return .orange }
        else { return .red }
    }
    
    private var batteryStateText: String {
        switch analytics.metrics.batteryState {
        case .unknown: return "Unknown"
        case .unplugged: return "Unplugged"
        case .charging: return "Charging"
        case .full: return "Full"
        @unknown default: return "Unknown"
        }
    }
}