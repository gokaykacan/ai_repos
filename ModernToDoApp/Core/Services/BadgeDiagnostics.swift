import Foundation
import UserNotifications
import UIKit
import CoreData

class BadgeDiagnostics {
    static let shared = BadgeDiagnostics()
    private init() {}
    
    func runFullDiagnostic() {
        print("\n🔍 ===== BADGE DIAGNOSTIC REPORT =====")
        
        // Device Information
        checkDeviceInfo()
        
        // Permission Status
        checkPermissions()
        
        // App Badge Status
        checkBadgeStatus()
        
        // Task Count Analysis
        checkTaskCounts()
        
        // Notification Queue
        checkNotificationQueue()
        
        print("🔍 ===== END DIAGNOSTIC REPORT =====\n")
    }
    
    private func checkDeviceInfo() {
        print("\n📱 DEVICE INFORMATION:")
        print("   Model: \(UIDevice.current.model)")
        print("   System: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
        print("   Name: \(UIDevice.current.name)")
        
        // Check if running on simulator
        #if targetEnvironment(simulator)
        print("   Environment: SIMULATOR")
        #else
        print("   Environment: PHYSICAL DEVICE")
        #endif
        
        // iOS Version compatibility
        if #available(iOS 17.0, *) {
            print("   iOS 17+ Features: AVAILABLE")
        } else {
            print("   iOS 17+ Features: NOT AVAILABLE")
        }
    }
    
    private func checkPermissions() {
        print("\n🔔 NOTIFICATION PERMISSIONS:")
        
        let semaphore = DispatchSemaphore(value: 0)
        
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("   Authorization Status: \(settings.authorizationStatus.description)")
            print("   Badge Setting: \(settings.badgeSetting.description)")
            print("   Alert Setting: \(settings.alertSetting.description)")
            print("   Sound Setting: \(settings.soundSetting.description)")
            print("   Critical Alert Setting: \(settings.criticalAlertSetting.description)")
            print("   Notification Center Setting: \(settings.notificationCenterSetting.description)")
            print("   Lock Screen Setting: \(settings.lockScreenSetting.description)")
            print("   Car Play Setting: \(settings.carPlaySetting.description)")
            
            // Critical compatibility check
            let isFullyAuthorized = settings.authorizationStatus == .authorized
            let canShowBadge = settings.badgeSetting == .enabled
            
            print("   ✅ FULLY AUTHORIZED: \(isFullyAuthorized)")
            print("   🏷️ CAN SHOW BADGE: \(canShowBadge)")
            print("   🔥 CRITICAL ISSUE: \(!canShowBadge && isFullyAuthorized ? "Badge disabled despite notification permission!" : "None")")
            
            semaphore.signal()
        }
        
        semaphore.wait()
    }
    
    private func checkBadgeStatus() {
        print("\n🏷️ BADGE STATUS:")
        
        let currentBadge = UIApplication.shared.applicationIconBadgeNumber
        print("   Current Badge Number: \(currentBadge)")
        
        // Test badge setting
        UIApplication.shared.applicationIconBadgeNumber = 99
        let testBadge = UIApplication.shared.applicationIconBadgeNumber
        print("   Test Badge Set (99): \(testBadge)")
        
        if testBadge != 99 {
            print("   🚨 CRITICAL: Badge setting failed - permission likely denied")
        }
        
        // Reset to original
        UIApplication.shared.applicationIconBadgeNumber = currentBadge
    }
    
    private func checkTaskCounts() {
        print("\n📋 TASK ANALYSIS:")
        
        let context = CoreDataStack.shared.container.viewContext
        let fetchRequest: NSFetchRequest<Task> = Task.fetchRequest()
        
        do {
            // Total tasks
            let allTasks = try context.fetch(fetchRequest)
            print("   Total Tasks: \(allTasks.count)")
            
            // Completed tasks
            fetchRequest.predicate = NSPredicate(format: "isCompleted == YES")
            let completedTasks = try context.fetch(fetchRequest)
            print("   Completed Tasks: \(completedTasks.count)")
            
            // Tasks with due dates
            fetchRequest.predicate = NSPredicate(format: "dueDate != nil")
            let tasksWithDueDates = try context.fetch(fetchRequest)
            print("   Tasks with Due Dates: \(tasksWithDueDates.count)")
            
            // Overdue tasks (current badge calculation)
            let now = Date()
            fetchRequest.predicate = NSPredicate(format: "isCompleted == NO AND dueDate != nil AND dueDate < %@", now as NSDate)
            let overdueTasks = try context.fetch(fetchRequest)
            print("   Overdue Tasks (Badge Count): \(overdueTasks.count)")
            
            // Due today
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: now)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            fetchRequest.predicate = NSPredicate(format: "isCompleted == NO AND dueDate >= %@ AND dueDate < %@", startOfDay as NSDate, endOfDay as NSDate)
            let dueTodayTasks = try context.fetch(fetchRequest)
            print("   Due Today Tasks: \(dueTodayTasks.count)")
            
            print("   📊 Expected Badge: \(overdueTasks.count)")
            
        } catch {
            print("   ❌ Core Data Error: \(error.localizedDescription)")
        }
    }
    
    private func checkNotificationQueue() {
        print("\n🔔 NOTIFICATION QUEUE:")
        
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("   Pending Notifications: \(requests.count)")
            
            for (index, request) in requests.enumerated() {
                if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                    let fireDate = Date().addingTimeInterval(trigger.timeInterval)
                    print("   [\(index + 1)] \(request.content.title) - fires at \(fireDate)")
                }
            }
        }
        
        UNUserNotificationCenter.current().getDeliveredNotifications { delivered in
            print("   Delivered Notifications: \(delivered.count)")
            
            for (index, notification) in delivered.enumerated() {
                print("   [\(index + 1)] \(notification.request.content.title)")
            }
        }
    }
}

// Extensions for better logging
extension UNAuthorizationStatus {
    var description: String {
        switch self {
        case .notDetermined: return "Not Determined"
        case .denied: return "DENIED"
        case .authorized: return "Authorized"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        @unknown default: return "Unknown"
        }
    }
}

extension UNNotificationSetting {
    var description: String {
        switch self {
        case .notSupported: return "Not Supported"
        case .disabled: return "DISABLED"
        case .enabled: return "Enabled"
        @unknown default: return "Unknown"
        }
    }
}