import Foundation
import UserNotifications

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    private init() {}
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("Notification permission granted")
                } else if let error = error {
                    print("Notification permission error: \(error.localizedDescription)")
                } else {
                    print("Notification permission denied")
                }
            }
        }
    }
    
    func scheduleNotification(for task: Task) {
        guard let dueDate = task.dueDate,
              let title = task.title,
              let taskId = task.id else { return }
        
        // Don't schedule if the due date is in the past
        guard dueDate > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Task Due: \(title)"
        
        if let notes = task.notes, !notes.isEmpty {
            content.body = notes
        } else {
            content.body = "Your task is due now"
        }
        
        content.sound = .default
        content.badge = 1
        
        // Set category based on priority
        switch task.priorityEnum {
        case .high:
            content.categoryIdentifier = "HIGH_PRIORITY_TASK"
        case .medium:
            content.categoryIdentifier = "MEDIUM_PRIORITY_TASK"
        case .low:
            content.categoryIdentifier = "LOW_PRIORITY_TASK"
        }
        
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
}