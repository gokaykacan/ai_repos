import XCTest
import Combine
@testable import ModernToDoApp

@MainActor
final class ViewModelTests: XCTestCase {
    
    var mockTaskRepository: MockTaskRepository!
    var mockCategoryRepository: MockCategoryRepository!
    var mockNotificationManager: MockNotificationManager!
    var mockHapticManager: MockHapticManager!
    var mockUserPreferences: MockUserPreferences!
    
    override func setUpWithError() throws {
        mockTaskRepository = MockTaskRepository()
        mockCategoryRepository = MockCategoryRepository()
        mockNotificationManager = MockNotificationManager()
        mockHapticManager = MockHapticManager()
        mockUserPreferences = MockUserPreferences()
    }
    
    override func tearDownWithError() throws {
        mockTaskRepository = nil
        mockCategoryRepository = nil
        mockNotificationManager = nil
        mockHapticManager = nil
        mockUserPreferences = nil
    }
    
    // MARK: - TaskListViewModel Tests
    
    func testTaskListViewModelInitialization() {
        // Given & When
        let viewModel = TaskListViewModel(
            taskRepository: mockTaskRepository,
            categoryRepository: mockCategoryRepository,
            notificationManager: mockNotificationManager,
            hapticManager: mockHapticManager
        )
        
        // Then
        XCTAssertTrue(viewModel.tasks.isEmpty)
        XCTAssertTrue(viewModel.categories.isEmpty)
        XCTAssertNil(viewModel.selectedCategory)
        XCTAssertEqual(viewModel.searchText, "")
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertTrue(viewModel.showCompletedTasks)
        XCTAssertEqual(viewModel.sortOrder, .createdDate)
    }
    
    func testTaskListViewModelToggleCompletion() {
        // Given
        let viewModel = TaskListViewModel(
            taskRepository: mockTaskRepository,
            categoryRepository: mockCategoryRepository,
            notificationManager: mockNotificationManager,
            hapticManager: mockHapticManager
        )
        
        let mockTask = createMockTask(title: "Test Task", isCompleted: false)
        
        // When
        viewModel.toggleTaskCompletion(mockTask)
        
        // Then
        XCTAssertTrue(mockTaskRepository.toggleCompletionCalled)
        XCTAssertTrue(mockHapticManager.playImpactCalled)
    }
    
    func testTaskListViewModelCreateTask() {
        // Given
        let viewModel = TaskListViewModel(
            taskRepository: mockTaskRepository,
            categoryRepository: mockCategoryRepository,
            notificationManager: mockNotificationManager,
            hapticManager: mockHapticManager
        )
        
        // When
        viewModel.createTask(title: "New Task", priority: .high)
        
        // Then
        XCTAssertTrue(mockTaskRepository.createTaskCalled)
        XCTAssertTrue(mockHapticManager.playImpactCalled)
    }
    
    // MARK: - TaskDetailViewModel Tests
    
    func testTaskDetailViewModelNewTask() {
        // Given & When
        let viewModel = TaskDetailViewModel(
            task: nil,
            taskRepository: mockTaskRepository,
            categoryRepository: mockCategoryRepository,
            notificationManager: mockNotificationManager,
            hapticManager: mockHapticManager
        )
        
        // Then
        XCTAssertFalse(viewModel.isEditing)
        XCTAssertEqual(viewModel.title, "")
        XCTAssertEqual(viewModel.notes, "")
        XCTAssertEqual(viewModel.priority, .medium)
        XCTAssertNil(viewModel.dueDate)
        XCTAssertFalse(viewModel.hasDueDate)
    }
    
    func testTaskDetailViewModelExistingTask() {
        // Given
        let mockTask = createMockTask(title: "Existing Task", isCompleted: false)
        mockTask.notes = "Test notes"
        mockTask.priority = 2 // High priority
        
        // When
        let viewModel = TaskDetailViewModel(
            task: mockTask,
            taskRepository: mockTaskRepository,
            categoryRepository: mockCategoryRepository,
            notificationManager: mockNotificationManager,
            hapticManager: mockHapticManager
        )
        
        // Then
        XCTAssertTrue(viewModel.isEditing)
        XCTAssertEqual(viewModel.title, "Existing Task")
        XCTAssertEqual(viewModel.notes, "Test notes")
        XCTAssertEqual(viewModel.priority, .high)
    }
    
    func testTaskDetailViewModelCanSave() {
        // Given
        let viewModel = TaskDetailViewModel(
            task: nil,
            taskRepository: mockTaskRepository,
            categoryRepository: mockCategoryRepository,
            notificationManager: mockNotificationManager,
            hapticManager: mockHapticManager
        )
        
        // When - empty title
        viewModel.title = ""
        
        // Then
        XCTAssertFalse(viewModel.canSave)
        
        // When - valid title
        viewModel.title = "Valid Task"
        
        // Then
        XCTAssertTrue(viewModel.canSave)
        
        // When - whitespace only title
        viewModel.title = "   "
        
        // Then
        XCTAssertFalse(viewModel.canSave)
    }
    
    // MARK: - CategoriesViewModel Tests
    
    func testCategoriesViewModelInitialization() {
        // Given & When
        let viewModel = CategoriesViewModel(
            categoryRepository: mockCategoryRepository,
            hapticManager: mockHapticManager
        )
        
        // Then
        XCTAssertTrue(viewModel.categories.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.showingAddCategory)
        XCTAssertNil(viewModel.editingCategory)
    }
    
    func testCategoriesViewModelCreateCategory() {
        // Given
        let viewModel = CategoriesViewModel(
            categoryRepository: mockCategoryRepository,
            hapticManager: mockHapticManager
        )
        
        // When
        viewModel.createCategory(name: "New Category", colorHex: "#FF0000", icon: "folder")
        
        // Then
        XCTAssertTrue(mockCategoryRepository.createCategoryCalled)
        XCTAssertTrue(mockHapticManager.playImpactCalled)
    }
    
    // MARK: - SettingsViewModel Tests
    
    func testSettingsViewModelInitialization() {
        // Given & When
        let viewModel = SettingsViewModel(
            userPreferences: mockUserPreferences,
            notificationManager: mockNotificationManager
        )
        
        // Then
        XCTAssertEqual(viewModel.isDarkModeEnabled, mockUserPreferences.isDarkModeEnabled)
        XCTAssertEqual(viewModel.defaultPriority, mockUserPreferences.defaultPriority)
        XCTAssertEqual(viewModel.notificationsEnabled, mockUserPreferences.notificationsEnabled)
    }
    
    func testSettingsViewModelResetAllSettings() {
        // Given
        let viewModel = SettingsViewModel(
            userPreferences: mockUserPreferences,
            notificationManager: mockNotificationManager
        )
        
        // When
        viewModel.resetAllSettings()
        
        // Then
        XCTAssertFalse(viewModel.isDarkModeEnabled)
        XCTAssertEqual(viewModel.defaultPriority, .medium)
        XCTAssertTrue(viewModel.notificationsEnabled)
        XCTAssertTrue(viewModel.hapticFeedbackEnabled)
        XCTAssertTrue(viewModel.showCompletedTasks)
        XCTAssertEqual(viewModel.taskSortOrder, .createdDate)
    }
    
    // MARK: - Helper Methods
    
    private func createMockTask(title: String, isCompleted: Bool) -> Task {
        let context = PersistenceController.preview.container.viewContext
        let task = Task(context: context)
        task.id = UUID()
        task.title = title
        task.isCompleted = isCompleted
        task.createdAt = Date()
        task.updatedAt = Date()
        task.priority = 1
        return task
    }
}

// MARK: - Mock Classes

class MockTaskRepository: TaskRepositoryProtocol {
    var fetchTasksCalled = false
    var createTaskCalled = false
    var updateTaskCalled = false
    var deleteTaskCalled = false
    var toggleCompletionCalled = false
    
    var tasks: [Task] = []
    
    func fetchTasks() async -> [Task] {
        fetchTasksCalled = true
        return tasks
    }
    
    func fetchTasks(for category: TaskCategory) async -> [Task] {
        return tasks.filter { $0.category == category }
    }
    
    func fetchTasks(predicate: NSPredicate) async -> [Task] {
        return tasks
    }
    
    func fetchCompletedTasks() async -> [Task] {
        return tasks.filter { $0.isCompleted }
    }
    
    func fetchIncompleteTasks() async -> [Task] {
        return tasks.filter { !$0.isCompleted }
    }
    
    func fetchOverdueTasks() async -> [Task] {
        return tasks.filter { $0.isOverdue }
    }
    
    func fetchTasksDueToday() async -> [Task] {
        return tasks.filter { $0.isDueToday }
    }
    
    func fetchTasksDueTomorrow() async -> [Task] {
        return tasks.filter { $0.isDueTomorrow }
    }
    
    func searchTasks(query: String) async -> [Task] {
        return tasks.filter { task in
            task.title?.localizedCaseInsensitiveContains(query) == true ||
            task.notes?.localizedCaseInsensitiveContains(query) == true
        }
    }
    
    func createTask(title: String, notes: String?, priority: TaskPriority, dueDate: Date?, category: TaskCategory?, parentTask: Task?) async -> Task {
        createTaskCalled = true
        let context = PersistenceController.preview.container.viewContext
        let task = Task(context: context)
        task.title = title
        task.notes = notes
        task.priorityEnum = priority
        task.dueDate = dueDate
        task.category = category
        task.parentTask = parentTask
        tasks.append(task)
        return task
    }
    
    func updateTask(_ task: Task) async {
        updateTaskCalled = true
    }
    
    func deleteTask(_ task: Task) async {
        deleteTaskCalled = true
        tasks.removeAll { $0 == task }
    }
    
    func toggleTaskCompletion(_ task: Task) async {
        toggleCompletionCalled = true
        task.isCompleted.toggle()
    }
    
    func createTaskPublisher() -> AnyPublisher<[Task], Never> {
        Just(tasks).eraseToAnyPublisher()
    }
}

class MockCategoryRepository: CategoryRepositoryProtocol {
    var createCategoryCalled = false
    var updateCategoryCalled = false
    var deleteCategoryCalled = false
    
    var categories: [TaskCategory] = []
    
    func fetchCategories() async -> [TaskCategory] {
        return categories
    }
    
    func createCategory(name: String, colorHex: String, icon: String) async -> TaskCategory {
        createCategoryCalled = true
        let context = PersistenceController.preview.container.viewContext
        let category = TaskCategory(context: context)
        category.name = name
        category.colorHex = colorHex
        category.icon = icon
        categories.append(category)
        return category
    }
    
    func updateCategory(_ category: TaskCategory) async {
        updateCategoryCalled = true
    }
    
    func deleteCategory(_ category: TaskCategory) async {
        deleteCategoryCalled = true
        categories.removeAll { $0 == category }
    }
    
    func createCategoryPublisher() -> AnyPublisher<[TaskCategory], Never> {
        Just(categories).eraseToAnyPublisher()
    }
}

class MockNotificationManager: NotificationManagerProtocol {
    var requestPermissionCalled = false
    var scheduleNotificationCalled = false
    var cancelNotificationCalled = false
    var cancelAllPendingCalled = false
    
    func requestPermission() {
        requestPermissionCalled = true
    }
    
    func scheduleNotification(for task: Task) async {
        scheduleNotificationCalled = true
    }
    
    func cancelNotification(for task: Task) async {
        cancelNotificationCalled = true
    }
    
    func cancelAllPendingNotifications() async {
        cancelAllPendingCalled = true
    }
    
    func getPendingNotifications() async -> [String] {
        return []
    }
}

class MockHapticManager: HapticManagerProtocol {
    var playSelectionCalled = false
    var playImpactCalled = false
    var playNotificationCalled = false
    
    func playSelection() {
        playSelectionCalled = true
    }
    
    func playImpact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        playImpactCalled = true
    }
    
    func playNotification(type: UINotificationFeedbackGenerator.FeedbackType) {
        playNotificationCalled = true
    }
}

class MockUserPreferences: ObservableObject, UserPreferencesProtocol {
    @Published var isDarkModeEnabled: Bool = false
    @Published var defaultPriority: TaskPriority = .medium
    @Published var defaultDueDateOffset: Int = 0
    @Published var notificationsEnabled: Bool = true
    @Published var hapticFeedbackEnabled: Bool = true
    @Published var showCompletedTasks: Bool = true
    @Published var taskSortOrder: TaskSortOrder = .createdDate
}