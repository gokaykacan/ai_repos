import Foundation
import UserNotifications
import UIKit

final class NotificationManager: NSObject, NotificationManagerProtocol {
    static let shared = NotificationManager()
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    private override init() {
        super.init()
        notificationCenter.delegate = self
    }
    
    func requestPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
            
            DispatchQueue.main.async {
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    func scheduleNotification(for task: Task) async {
        guard let dueDate = task.dueDate,
              let taskId = task.id,
              let title = task.title,
              dueDate > Date() else { return }
        
        await cancelNotification(for: task)
        
        let content = UNMutableNotificationContent()
        content.title = "Task Due"
        content.body = title
        content.sound = .default
        content.badge = await getBadgeCount() + 1
        
        if let notes = task.notes, !notes.isEmpty {
            content.subtitle = notes
        }
        
        content.userInfo = [
            "taskId": taskId.uuidString,
            "taskTitle": title
        ]
        
        content.categoryIdentifier = "TASK_REMINDER"
        
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: taskId.uuidString,
            content: content,
            trigger: trigger
        )
        
        do {
            try await notificationCenter.add(request)
            print("Scheduled notification for task: \(title) at \(dueDate)")
        } catch {
            print("Error scheduling notification: \(error)")
        }
    }
    
    func cancelNotification(for task: Task) async {
        guard let taskId = task.id else { return }
        
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [taskId.uuidString])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [taskId.uuidString])
        
        print("Cancelled notification for task: \(task.title ?? "Unknown")")
    }
    
    func cancelAllPendingNotifications() async {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
        
        await MainActor.run {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
        
        print("Cancelled all pending notifications")
    }
    
    func getPendingNotifications() async -> [String] {
        let requests = await notificationCenter.pendingNotificationRequests()
        return requests.map { $0.identifier }
    }
    
    private func getBadgeCount() async -> NSNumber {
        let requests = await notificationCenter.pendingNotificationRequests()
        return NSNumber(value: requests.count)
    }
    
    private func setupNotificationCategories() {
        let completeAction = UNNotificationAction(
            identifier: "COMPLETE_TASK",
            title: "Mark Complete",
            options: [.foreground]
        )
        
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_TASK",
            title: "Snooze 1 Hour",
            options: []
        )
        
        let category = UNNotificationCategory(
            identifier: "TASK_REMINDER",
            actions: [completeAction, snoozeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        notificationCenter.setNotificationCategories([category])
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        guard let taskIdString = userInfo["taskId"] as? String,
              let taskId = UUID(uuidString: taskIdString) else {
            completionHandler()
            return
        }
        
        switch response.actionIdentifier {
        case "COMPLETE_TASK":
            handleCompleteTask(taskId: taskId)
        case "SNOOZE_TASK":
            handleSnoozeTask(taskId: taskId)
        case UNNotificationDefaultActionIdentifier:
            handleOpenTask(taskId: taskId)
        default:
            break
        }
        
        completionHandler()
    }
    
    private func handleCompleteTask(taskId: UUID) {
        Task {
            // Find and complete the task
            // This would require access to the task repository
            print("Completing task with ID: \(taskId)")
        }
    }
    
    private func handleSnoozeTask(taskId: UUID) {
        Task {
            // Reschedule notification for 1 hour later
            print("Snoozing task with ID: \(taskId)")
        }
    }
    
    private func handleOpenTask(taskId: UUID) {
        // Open the app to the specific task
        print("Opening task with ID: \(taskId)")
        
        NotificationCenter.default.post(
            name: Notification.Name("OpenTask"),
            object: nil,
            userInfo: ["taskId": taskId]
        )
    }
}