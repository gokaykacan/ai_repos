import Foundation
import Combine

final class UserPreferences: ObservableObject, UserPreferencesProtocol {
    @Published var isDarkModeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isDarkModeEnabled, forKey: "isDarkModeEnabled")
        }
    }
    
    @Published var defaultPriority: TaskPriority {
        didSet {
            UserDefaults.standard.set(defaultPriority.rawValue, forKey: "defaultPriority")
        }
    }
    
    @Published var defaultDueDateOffset: Int {
        didSet {
            UserDefaults.standard.set(defaultDueDateOffset, forKey: "defaultDueDateOffset")
        }
    }
    
    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
        }
    }
    
    @Published var hapticFeedbackEnabled: Bool {
        didSet {
            UserDefaults.standard.set(hapticFeedbackEnabled, forKey: "hapticFeedbackEnabled")
        }
    }
    
    @Published var showCompletedTasks: Bool {
        didSet {
            UserDefaults.standard.set(showCompletedTasks, forKey: "showCompletedTasks")
        }
    }
    
    @Published var taskSortOrder: TaskSortOrder {
        didSet {
            UserDefaults.standard.set(taskSortOrder.rawValue, forKey: "taskSortOrder")
        }
    }
    
    init() {
        self.isDarkModeEnabled = UserDefaults.standard.bool(forKey: "isDarkModeEnabled")
        self.defaultPriority = TaskPriority(rawValue: UserDefaults.standard.integer(forKey: "defaultPriority")) ?? .medium
        self.defaultDueDateOffset = UserDefaults.standard.integer(forKey: "defaultDueDateOffset")
        self.notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        self.hapticFeedbackEnabled = UserDefaults.standard.bool(forKey: "hapticFeedbackEnabled")
        self.showCompletedTasks = UserDefaults.standard.bool(forKey: "showCompletedTasks")
        
        let sortOrderRaw = UserDefaults.standard.string(forKey: "taskSortOrder") ?? TaskSortOrder.createdDate.rawValue
        self.taskSortOrder = TaskSortOrder(rawValue: sortOrderRaw) ?? .createdDate
        
        if UserDefaults.standard.object(forKey: "notificationsEnabled") == nil {
            self.notificationsEnabled = true
        }
        
        if UserDefaults.standard.object(forKey: "hapticFeedbackEnabled") == nil {
            self.hapticFeedbackEnabled = true
        }
        
        if UserDefaults.standard.object(forKey: "showCompletedTasks") == nil {
            self.showCompletedTasks = true
        }
    }
}