import Foundation
import UIKit
import UserNotifications
import CoreData

/**
 * BadgeDiagnostic.swift
 * 
 * This file contains diagnostic functions to help troubleshoot notification badge issues
 * between iPhone 16 Pro simulator and iPhone 14 physical device.
 * 
 * Usage: Add these functions to your NotificationManager to help debug badge issues.
 */

extension NotificationManager {
    
    /// Comprehensive diagnostic check for badge functionality
    func runBadgeDiagnostic() {
        print("\n=== BADGE DIAGNOSTIC REPORT ===")
        
        // 1. Device and iOS version info
        checkDeviceInfo()
        
        // 2. Notification permissions
        checkNotificationPermissions()
        
        // 3. Current badge state
        checkCurrentBadgeState()
        
        // 4. Core Data state
        checkCoreDataState()
        
        // 5. Pending notifications
        checkPendingNotifications()
        
        // 6. Delivered notifications
        checkDeliveredNotifications()
        
        print("=== END DIAGNOSTIC REPORT ===\n")
    }
    
    private func checkDeviceInfo() {
        print("📱 DEVICE INFO:")
        print("  - Device Model: \(UIDevice.current.model)")
        print("  - Device Name: \(UIDevice.current.name)")
        print("  - iOS Version: \(UIDevice.current.systemVersion)")
        print("  - Is Simulator: \(isRunningOnSimulator())")
        print("")
    }
    
    private func checkNotificationPermissions() {
        print("🔔 NOTIFICATION PERMISSIONS:")
        
        let semaphore = DispatchSemaphore(value: 0)
        
        notificationCenter.getNotificationSettings { settings in
            print("  - Authorization Status: \(settings.authorizationStatus.rawValue) (\(self.authorizationStatusString(settings.authorizationStatus)))")
            print("  - Badge Setting: \(settings.badgeSetting.rawValue) (\(self.notificationSettingString(settings.badgeSetting)))")
            print("  - Alert Setting: \(settings.alertSetting.rawValue) (\(self.notificationSettingString(settings.alertSetting)))")
            print("  - Sound Setting: \(settings.soundSetting.rawValue) (\(self.notificationSettingString(settings.soundSetting)))")
            print("  - Critical Alert Setting: \(settings.criticalAlertSetting.rawValue) (\(self.notificationSettingString(settings.criticalAlertSetting)))")
            print("  - Announcement Setting: \(settings.announcementSetting.rawValue) (\(self.notificationSettingString(settings.announcementSetting)))")
            print("")
            semaphore.signal()
        }
        
        semaphore.wait()
    }
    
    private func checkCurrentBadgeState() {
        print("🏷️ BADGE STATE:")
        let currentBadge = UIApplication.shared.applicationIconBadgeNumber
        let calculatedBadge = getCurrentBadgeCount()
        
        print("  - Current App Badge: \(currentBadge)")
        print("  - Calculated Badge Count: \(calculatedBadge)")
        print("  - Badge Mismatch: \(currentBadge != calculatedBadge ? "YES ⚠️" : "NO ✅")")
        print("")
    }
    
    private func checkCoreDataState() {
        print("💾 CORE DATA STATE:")
        let context = CoreDataStack.shared.container.viewContext
        let fetchRequest: NSFetchRequest<Task> = Task.fetchRequest()
        
        do {
            let allTasks = try context.fetch(fetchRequest)
            let incompleteTasks = allTasks.filter { !$0.isCompleted }
            let overdueTasks = allTasks.filter { task in
                guard let dueDate = task.dueDate, !task.isCompleted else { return false }
                return dueDate < Date()
            }
            let tasksWithDueDates = allTasks.filter { $0.dueDate != nil }
            
            print("  - Total Tasks: \(allTasks.count)")
            print("  - Incomplete Tasks: \(incompleteTasks.count)")
            print("  - Overdue Tasks: \(overdueTasks.count)")
            print("  - Tasks with Due Dates: \(tasksWithDueDates.count)")
            
            // List overdue tasks for debugging
            if !overdueTasks.isEmpty {
                print("  - Overdue Task Details:")
                for task in overdueTasks.prefix(5) {
                    print("    • '\(task.title ?? "Untitled")' - Due: \(task.dueDate?.formatted() ?? "No Date")")
                }
            }
            
        } catch {
            print("  - Error fetching tasks: \(error.localizedDescription)")
        }
        print("")
    }
    
    private func checkPendingNotifications() {
        print("⏳ PENDING NOTIFICATIONS:")
        
        let semaphore = DispatchSemaphore(value: 0)
        
        notificationCenter.getPendingNotificationRequests { requests in
            print("  - Count: \(requests.count)")
            
            if !requests.isEmpty {
                print("  - Details:")
                for (index, request) in requests.enumerated().prefix(5) {
                    let badge = request.content.badge?.intValue ?? 0
                    var triggerInfo = "Unknown trigger"
                    
                    if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                        let fireDate = Date().addingTimeInterval(trigger.timeInterval)
                        triggerInfo = "Time: \(fireDate.formatted())"
                    } else if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                        triggerInfo = "Calendar: \(trigger.dateComponents)"
                    }
                    
                    print("    \(index + 1). '\(request.content.title)' - Badge: \(badge) - \(triggerInfo)")
                }
            }
            print("")
            semaphore.signal()
        }
        
        semaphore.wait()
    }
    
    private func checkDeliveredNotifications() {
        print("📬 DELIVERED NOTIFICATIONS:")
        
        let semaphore = DispatchSemaphore(value: 0)
        
        notificationCenter.getDeliveredNotifications { notifications in
            print("  - Count: \(notifications.count)")
            
            if !notifications.isEmpty {
                print("  - Details:")
                for (index, notification) in notifications.enumerated().prefix(5) {
                    let badge = notification.request.content.badge?.intValue ?? 0
                    let deliveryDate = notification.date
                    
                    print("    \(index + 1). '\(notification.request.content.title)' - Badge: \(badge) - Delivered: \(deliveryDate.formatted())")
                }
            }
            print("")
            semaphore.signal()
        }
        
        semaphore.wait()
    }
    
    // MARK: - Helper Methods
    
    private func isRunningOnSimulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    private func authorizationStatusString(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "Not Determined"
        case .denied: return "Denied"
        case .authorized: return "Authorized"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        @unknown default: return "Unknown"
        }
    }
    
    private func notificationSettingString(_ setting: UNNotificationSetting) -> String {
        switch setting {
        case .notSupported: return "Not Supported"
        case .disabled: return "Disabled"
        case .enabled: return "Enabled"
        @unknown default: return "Unknown"
        }
    }
    
    /// Force badge update with detailed logging
    func forceBadgeUpdate() {
        print("🔄 FORCING BADGE UPDATE...")
        
        let calculatedCount = getCurrentBadgeCount()
        let currentCount = UIApplication.shared.applicationIconBadgeNumber
        
        print("  - Current Badge: \(currentCount)")
        print("  - Calculated Count: \(calculatedCount)")
        
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = calculatedCount
            print("  - Set Badge To: \(calculatedCount)")
            print("  - New Badge Value: \(UIApplication.shared.applicationIconBadgeNumber)")
        }
    }
    
    /// Test badge setting with incremental values
    func testBadgeSettings() {
        print("🧪 TESTING BADGE SETTINGS...")
        
        let testValues = [0, 1, 5, 10, 99]
        
        for (index, value) in testValues.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 2.0) {
                UIApplication.shared.applicationIconBadgeNumber = value
                print("  - Set badge to \(value): Success = \(UIApplication.shared.applicationIconBadgeNumber == value)")
            }
        }
        
        // Reset to actual count after tests
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(testValues.count) * 2.0 + 1.0) {
            let actualCount = self.getCurrentBadgeCount()
            UIApplication.shared.applicationIconBadgeNumber = actualCount
            print("  - Reset badge to actual count: \(actualCount)")
        }
    }
}

// MARK: - Settings View Integration

/**
 * Add this to your SettingsView to provide easy access to diagnostics:
 
 Section("Debug") {
     Button("Run Badge Diagnostic") {
         NotificationManager.shared.runBadgeDiagnostic()
     }
     
     Button("Force Badge Update") {
         NotificationManager.shared.forceBadgeUpdate()
     }
     
     Button("Test Badge Settings") {
         NotificationManager.shared.testBadgeSettings()
     }
 }
 */