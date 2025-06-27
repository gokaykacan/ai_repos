import Foundation
import Combine

final class DependencyContainer: ObservableObject {
    
    // MARK: - Repositories
    lazy var taskRepository: TaskRepositoryProtocol = TaskRepository(
        persistenceController: PersistenceController.shared
    )
    
    lazy var categoryRepository: CategoryRepositoryProtocol = CategoryRepository(
        persistenceController: PersistenceController.shared
    )
    
    // MARK: - Services
    lazy var notificationManager: NotificationManagerProtocol = NotificationManager.shared
    lazy var hapticManager: HapticManagerProtocol = HapticManager()
    lazy var userPreferences: UserPreferencesProtocol = UserPreferences()
    
    // MARK: - ViewModels
    func makeTaskListViewModel() -> TaskListViewModel {
        TaskListViewModel(
            taskRepository: taskRepository,
            categoryRepository: categoryRepository,
            notificationManager: notificationManager,
            hapticManager: hapticManager
        )
    }
    
    func makeTaskDetailViewModel(task: Task? = nil) -> TaskDetailViewModel {
        TaskDetailViewModel(
            task: task,
            taskRepository: taskRepository,
            categoryRepository: categoryRepository,
            notificationManager: notificationManager,
            hapticManager: hapticManager
        )
    }
    
    func makeCategoriesViewModel() -> CategoriesViewModel {
        CategoriesViewModel(
            categoryRepository: categoryRepository,
            hapticManager: hapticManager
        )
    }
    
    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            userPreferences: userPreferences,
            notificationManager: notificationManager
        )
    }
    
    // MARK: - Initialization
    init() {
        setupDefaultCategories()
    }
    
    private func setupDefaultCategories() {
        Task {
            await createDefaultCategoriesIfNeeded()
        }
    }
    
    @MainActor
    private func createDefaultCategoriesIfNeeded() async {
        let categories = await categoryRepository.fetchCategories()
        
        if categories.isEmpty {
            let defaultCategories = [
                ("Personal", "#FF6B6B", "person"),
                ("Work", "#4ECDC4", "briefcase"),
                ("Shopping", "#45B7D1", "cart"),
                ("Health", "#96CEB4", "heart"),
                ("Learning", "#FFEAA7", "book")
            ]
            
            for (name, color, icon) in defaultCategories {
                await categoryRepository.createCategory(
                    name: name,
                    colorHex: color,
                    icon: icon
                )
            }
        }
    }
}