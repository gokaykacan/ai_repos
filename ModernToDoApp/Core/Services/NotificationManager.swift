import Foundation
import UserNotifications
import UIKit
import CoreData

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    private init() {}
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("Notification permission granted")
                    self.setupNotificationCategories()
                } else if let error = error {
                    print("Notification permission error: \(error.localizedDescription)")
                } else {
                    print("Notification permission denied")
                }
            }
        }
    }
    
    private func setupNotificationCategories() {
        // Create notification actions for better UX
        let completeAction = UNNotificationAction(
            identifier: "COMPLETE_ACTION",
            title: "✅ " + "action.complete".localized,
            options: [.foreground]
        )
        
        let postponeAction = UNNotificationAction(
            identifier: "POSTPONE_ACTION", 
            title: "⏰ " + "action.postpone".localized,
            options: [.foreground]
        )
        
        let viewAction = UNNotificationAction(
            identifier: "VIEW_ACTION",
            title: "👁️ " + "action.view".localized,
            options: [.foreground]
        )
        
        // Define notification categories with actions and visual indicators
        let highPriorityCategory = UNNotificationCategory(
            identifier: "HIGH_PRIORITY_TASK",
            actions: [completeAction, postponeAction, viewAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        let mediumPriorityCategory = UNNotificationCategory(
            identifier: "MEDIUM_PRIORITY_TASK", 
            actions: [completeAction, postponeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        let lowPriorityCategory = UNNotificationCategory(
            identifier: "LOW_PRIORITY_TASK",
            actions: [completeAction, viewAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Register categories with the notification center
        UNUserNotificationCenter.current().setNotificationCategories([
            highPriorityCategory,
            mediumPriorityCategory, 
            lowPriorityCategory
        ])
        
        print("Notification categories with actions registered")
    }
    
    func scheduleNotification(for task: Task) {
        guard let dueDate = task.dueDate,
              let title = task.title,
              let taskId = task.id else { return }
        
        // Don't schedule if the due date is in the past
        guard dueDate > Date() else { return }
        
        // Get total notification count (delivered + pending) to determine badge number
        getTaskNotificationCount { totalCount in
            let content = UNMutableNotificationContent()
            
            // Add priority-based emojis and formatting
            let priorityEmoji: String
            let urgencyText: String
            
            switch task.priorityEnum {
            case .high:
                priorityEmoji = "🔴"
                urgencyText = "🚨 " + "priority.high".localized.uppercased()
                content.categoryIdentifier = "HIGH_PRIORITY_TASK"
                content.sound = .defaultCritical
            case .medium:
                priorityEmoji = "🟡"
                urgencyText = "⚠️ " + "priority.medium".localized
                content.categoryIdentifier = "MEDIUM_PRIORITY_TASK"
                content.sound = .default
            case .low:
                priorityEmoji = "🟢"
                urgencyText = "ℹ️ " + "priority.low".localized
                content.categoryIdentifier = "LOW_PRIORITY_TASK"
                content.sound = .default
            }
            
            // Enhanced title with visual priority indicators
            content.title = "\(priorityEmoji) " + "notification.task_due_title".localized(with: title)
            
            // Enhanced body with urgency and notes
            var bodyText = urgencyText + "\n"
            if let notes = task.notes, !notes.isEmpty {
                bodyText += "📝 " + notes
            } else {
                bodyText += "📋 " + "notification.task_due_body".localized
            }
            
            // Add category info if available
            if let category = task.category {
                bodyText += "\n📁 " + (category.name ?? "category.unnamed".localized)
            }
            
            content.body = bodyText
            
            // Set badge count for this new notification
            content.badge = NSNumber(value: totalCount + 1)
            
            // Add thread identifier for grouping notifications
            content.threadIdentifier = "task-notifications"
            
            // Create trigger for the exact due date
            let calendar = Calendar.current
            let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            
            let request = UNNotificationRequest(
                identifier: taskId.uuidString,
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling notification: \(error.localizedDescription)")
                } else {
                    print("Notification scheduled for task: \(title)")
                }
            }
        }
    }
    
    func cancelNotification(for task: Task) {
        guard let taskId = task.id else { return }
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [taskId.uuidString])
        print("Cancelled notification for task: \(task.title ?? "Unknown")")
    }
    
    func updateNotification(for task: Task) {
        // Cancel existing notification and schedule new one
        cancelNotification(for: task)
        
        // Only reschedule if task is not completed and has a due date
        if !task.isCompleted && task.dueDate != nil {
            scheduleNotification(for: task)
        }
    }
    
    func checkNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional:
                    print("Notifications authorized")
                case .denied:
                    print("Notifications denied - user should enable in Settings")
                case .notDetermined:
                    print("Notification permission not determined")
                case .ephemeral:
                    print("Ephemeral notification authorization")
                @unknown default:
                    print("Unknown notification authorization status")
                }
            }
        }
    }
    
    func clearAppBadge() {
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
        // Clear delivered notifications to reset the badge count for future notifications
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
    func updateApplicationBadgeNumber() {
        let context = CoreDataStack.shared.container.viewContext
        let fetchRequest: NSFetchRequest<Task> = Task.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isCompleted == NO AND (dueDate <= %@ OR dueDate == nil)", Date() as NSDate)

        do {
            let incompleteAndDueTasks = try context.fetch(fetchRequest)
            let badgeCount = incompleteAndDueTasks.filter { task in
                // Only count tasks that are overdue or due today
                if let dueDate = task.dueDate {
                    return Calendar.current.isDateInToday(dueDate) || dueDate < Date()
                }
                return false // Don't count tasks without a due date for badge
            }.count
            DispatchQueue.main.async {
                UIApplication.shared.applicationIconBadgeNumber = badgeCount
                print("Updated application badge number to: \(badgeCount)")
            }
        } catch {
            print("Error fetching tasks for badge update: \(error.localizedDescription)")
        }
    }
    
    private func getTaskNotificationCount(completion: @escaping (Int) -> Void) {
        let group = DispatchGroup()
        var deliveredCount = 0
        var pendingCount = 0
        
        // Get delivered notifications count (only count task notifications)
        group.enter()
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            // Filter to only count notifications that start with "Task Due:"
            deliveredCount = notifications.filter { notification in
                notification.request.content.title.hasPrefix("Task Due:")
            }.count
            group.leave()
        }
        
        // Get pending notifications count (only count task notifications)
        group.enter()
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            // Filter to only count notifications that start with "Task Due:"
            pendingCount = requests.filter { request in
                request.content.title.hasPrefix("Task Due:")
            }.count
            group.leave()
        }
        
        // When both complete, return total
        group.notify(queue: .main) {
            completion(deliveredCount + pendingCount)
        }
    }
}
