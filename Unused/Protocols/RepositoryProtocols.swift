import Foundation
import Combine
import CoreData

// MARK: - Task Repository Protocol
protocol TaskRepositoryProtocol {
    func fetchTasks() async -> [Task]
    func fetchTasks(for category: TaskCategory) async -> [Task]
    func fetchTasks(predicate: NSPredicate) async -> [Task]
    func fetchCompletedTasks() async -> [Task]
    func fetchIncompleteTasks() async -> [Task]
    func fetchOverdueTasks() async -> [Task]
    func fetchTasksDueToday() async -> [Task]
    func fetchTasksDueTomorrow() async -> [Task]
    func searchTasks(query: String) async -> [Task]
    
    func createTask(
        title: String,
        notes: String?,
        priority: TaskPriority,
        dueDate: Date?,
        category: TaskCategory?,
        parentTask: Task?
    ) async -> Task
    
    func updateTask(_ task: Task) async
    func deleteTask(_ task: Task) async
    func toggleTaskCompletion(_ task: Task) async
    
    func createTaskPublisher() -> AnyPublisher<[Task], Never>
}

// MARK: - Category Repository Protocol
protocol CategoryRepositoryProtocol {
    func fetchCategories() async -> [TaskCategory]
    func createCategory(name: String, colorHex: String, icon: String) async -> TaskCategory
    func updateCategory(_ category: TaskCategory) async
    func deleteCategory(_ category: TaskCategory) async
    func createCategoryPublisher() -> AnyPublisher<[TaskCategory], Never>
}

// MARK: - Notification Manager Protocol
protocol NotificationManagerProtocol {
    func requestPermission()
    func scheduleNotification(for task: Task) async
    func cancelNotification(for task: Task) async
    func cancelAllPendingNotifications() async
    func getPendingNotifications() async -> [String]
}

// MARK: - Haptic Manager Protocol
protocol HapticManagerProtocol {
    func playSelection()
    func playImpact(style: UIImpactFeedbackGenerator.FeedbackStyle)
    func playNotification(type: UINotificationFeedbackGenerator.FeedbackType)
}

// MARK: - User Preferences Protocol
protocol UserPreferencesProtocol: ObservableObject {
    var isDarkModeEnabled: Bool { get set }
    var defaultPriority: TaskPriority { get set }
    var defaultDueDateOffset: Int { get set }
    var notificationsEnabled: Bool { get set }
    var hapticFeedbackEnabled: Bool { get set }
    var showCompletedTasks: Bool { get set }
    var taskSortOrder: TaskSortOrder { get set }
}