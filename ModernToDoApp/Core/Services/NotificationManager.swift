import Foundation
import UserNotifications
import UIKit
import CoreData

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    // MARK: - Private Properties
    private let notificationCenter = UNUserNotificationCenter.current()
    private var badgeUpdateTimer: Timer?
    private var isInitialized = false
    
    private init() {
        setupNotificationObservers()
    }
    
    // MARK: - Initialization
    
    func initialize() {
        guard !isInitialized else { return }
        isInitialized = true
        
        requestPermission()
        startBadgeUpdateTimer()
        
        print("NotificationManager initialized")
    }
    
    private func setupNotificationObservers() {
        // Listen for app lifecycle changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    @objc private func appDidBecomeActive() {
        print("App became active - updating badge")
        clearDeliveredNotifications()
        updateBadgeCount()
    }
    
    @objc private func appDidEnterBackground() {
        print("App entered background - final badge update")
        updateBadgeCount()
    }
    
    // MARK: - Permission Management
    
    func requestPermission() {
        // Remove .criticalAlert for broader device compatibility
        notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("✅ Notification permission granted")
                    self?.setupNotificationCategories()
                    self?.updateBadgeCount()
                } else if let error = error {
                    print("❌ Notification permission error: \(error.localizedDescription)")
                } else {
                    print("❌ Notification permission denied")
                }
            }
        }
    }
    
    
    func checkNotificationSettings() -> Bool {
        var isAuthorized = false
        var canShowBadge = false
        let semaphore = DispatchSemaphore(value: 0)
        
        notificationCenter.getNotificationSettings { settings in
            isAuthorized = settings.authorizationStatus == .authorized
            canShowBadge = settings.badgeSetting == .enabled
            
            // Enhanced logging for debugging device differences
            print("📊 Authorization: \(settings.authorizationStatus.rawValue)")
            print("🏷️ Badge setting: \(settings.badgeSetting.rawValue)")
            print("📱 Device: \(UIDevice.current.model)")
            print("🍎 iOS: \(UIDevice.current.systemVersion)")
            
            semaphore.signal()
        }
        
        semaphore.wait()
        
        // Both authorization and badge permission must be granted
        let result = isAuthorized && canShowBadge
        print("✅ Final permission check: \(result) (auth: \(isAuthorized), badge: \(canShowBadge))")
        return result
    }
    
    private func setupNotificationCategories() {
        // Create notification actions
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
        
        // Create notification categories
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
        
        // Register categories
        notificationCenter.setNotificationCategories([
            highPriorityCategory,
            mediumPriorityCategory,
            lowPriorityCategory
        ])
        
        print("✅ Notification categories registered")
    }
    
    // MARK: - Notification Scheduling
    
    func scheduleNotification(for task: Task) {
        guard let dueDate = task.dueDate,
              let title = task.title,
              let taskId = task.id else {
            print("❌ Cannot schedule notification - missing required fields")
            return
        }
        
        // Validate due date
        let now = Date()
        guard dueDate > now else {
            print("❌ Cannot schedule notification - due date is in the past: \(dueDate)")
            return
        }
        
        // Check if notification is authorized
        guard checkNotificationSettings() else {
            print("❌ Cannot schedule notification - not authorized")
            return
        }
        
        // Cancel any existing notification for this task
        cancelNotification(for: task)
        
        // Create notification content
        let content = createNotificationContent(for: task)
        
        // Create reliable trigger with multiple fallbacks
        let trigger = createNotificationTrigger(for: dueDate)
        
        // Create and schedule request
        let request = UNNotificationRequest(
            identifier: taskId.uuidString,
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Failed to schedule notification for '\(title)': \(error.localizedDescription)")
                } else {
                    print("✅ Scheduled notification for '\(title)' at \(dueDate)")
                    self?.updateBadgeCount()
                }
            }
        }
    }
    
    private func createNotificationContent(for task: Task) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        
        // Priority-based configuration
        let (emoji, categoryId, sound) = getNotificationStyle(for: task.priorityEnum)
        
        // Simple, clean title with just task name
        content.title = task.title ?? "Task"
        
        // Simple body with just emoji indicator
        var bodyText = "\(emoji) " + "notification.task_due_body".localized
        
        // Add notes only if they exist and are short
        if let notes = task.notes, !notes.isEmpty && notes.count <= 50 {
            bodyText = notes
        }
        
        content.body = bodyText
        content.categoryIdentifier = categoryId
        content.sound = sound
        content.threadIdentifier = "task-notifications"
        
        // Set badge to current overdue count + 1
        let currentBadgeCount = getCurrentBadgeCount()
        content.badge = NSNumber(value: currentBadgeCount + 1)
        
        return content
    }
    
    private func getNotificationStyle(for priority: TaskPriority) -> (emoji: String, categoryId: String, sound: UNNotificationSound) {
        switch priority {
        case .high:
            return ("🔴", "HIGH_PRIORITY_TASK", .defaultCritical)
        case .medium:
            return ("🟡", "MEDIUM_PRIORITY_TASK", .default)
        case .low:
            return ("🟢", "LOW_PRIORITY_TASK", .default)
        }
    }
    
    private func createNotificationTrigger(for dueDate: Date) -> UNNotificationTrigger {
        // Use time-based trigger for more reliability
        let timeInterval = dueDate.timeIntervalSinceNow
        
        // Minimum 1 second for immediate testing, actual time for real scheduling
        let interval = max(1.0, timeInterval)
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        
        print("📅 Created trigger for \(interval) seconds from now (due: \(dueDate))")
        return trigger
    }
    
    // MARK: - Notification Management
    
    func cancelNotification(for task: Task) {
        guard let taskId = task.id else { return }
        
        let identifier = taskId.uuidString
        
        // Remove both pending and delivered notifications
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier])
        
        print("✅ Cancelled notification for task: \(task.title ?? "Unknown")")
        
        // Update badge immediately
        DispatchQueue.main.async { [weak self] in
            self?.updateBadgeCount()
        }
    }
    
    func updateNotification(for task: Task) {
        print("🔄 Updating notification for task: \(task.title ?? "Unknown")")
        
        // Cancel existing
        cancelNotification(for: task)
        
        // Reschedule if needed
        if !task.isCompleted && task.dueDate != nil {
            scheduleNotification(for: task)
        }
    }
    
    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
        clearAppBadge()
        print("✅ Cancelled all notifications")
    }
    
    // MARK: - Badge Management
    
    private func startBadgeUpdateTimer() {
        // Update badge every 30 seconds for real-time accuracy
        badgeUpdateTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.updateBadgeCount()
        }
    }
    
    func updateBadgeCount() {
        let badgeCount = getCurrentBadgeCount()
        
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = badgeCount
            print("🏷️ Updated app badge to: \(badgeCount)")
        }
    }
    
    private func getCurrentBadgeCount() -> Int {
        let context = CoreDataStack.shared.container.viewContext
        let fetchRequest: NSFetchRequest<Task> = Task.fetchRequest()
        
        // Count ONLY overdue tasks (not due today, only past due)
        let now = Date()
        
        fetchRequest.predicate = NSPredicate(
            format: "isCompleted == NO AND dueDate != nil AND dueDate < %@",
            now as NSDate
        )
        
        do {
            let overdueTasks = try context.fetch(fetchRequest)
            let count = overdueTasks.count
            print("📊 Current badge count calculation: \(count) overdue tasks only")
            return count
        } catch {
            print("❌ Error calculating badge count: \(error.localizedDescription)")
            return 0
        }
    }
    
    func clearAppBadge() {
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = 0
            print("✅ Cleared app badge")
        }
    }
    
    private func clearDeliveredNotifications() {
        notificationCenter.removeAllDeliveredNotifications()
        print("✅ Cleared delivered notifications")
    }
    
    // MARK: - Utility Methods
    
    
    func rescheduleAllTaskNotifications() {
        print("🔄 Rescheduling all task notifications")
        
        // Cancel all existing notifications
        cancelAllNotifications()
        
        // Fetch all incomplete tasks with due dates
        let context = CoreDataStack.shared.container.viewContext
        let fetchRequest: NSFetchRequest<Task> = Task.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isCompleted == NO AND dueDate != nil")
        
        do {
            let tasks = try context.fetch(fetchRequest)
            print("📅 Rescheduling \(tasks.count) tasks")
            
            for task in tasks {
                scheduleNotification(for: task)
            }
        } catch {
            print("❌ Error fetching tasks for rescheduling: \(error.localizedDescription)")
        }
    }
    
    deinit {
        badgeUpdateTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Convenient Badge Update Methods

extension NotificationManager {
    /// Call this after any task state change for immediate badge update
    func handleTaskStateChange() {
        DispatchQueue.main.async { [weak self] in
            self?.updateBadgeCount()
        }
    }
    
    /// Call this when user completes/uncompletes a task
    func handleTaskCompletion() {
        DispatchQueue.main.async { [weak self] in
            self?.updateBadgeCount()
        }
    }
    
    /// Call this when tasks are deleted
    func handleTaskDeletion() {
        DispatchQueue.main.async { [weak self] in
            self?.updateBadgeCount()
        }
    }
}