import XCTest
import CoreData
@testable import ModernToDoApp

final class ModernToDoAppTests: XCTestCase {
    
    var persistenceController: PersistenceController!
    var taskRepository: TaskRepository!
    var categoryRepository: CategoryRepository!
    
    override func setUpWithError() throws {
        persistenceController = createInMemoryPersistenceController()
        taskRepository = TaskRepository(persistenceController: persistenceController)
        categoryRepository = CategoryRepository(persistenceController: persistenceController)
    }
    
    override func tearDownWithError() throws {
        persistenceController = nil
        taskRepository = nil
        categoryRepository = nil
    }
    
    // MARK: - Helper Methods
    
    private func createInMemoryPersistenceController() -> PersistenceController {
        let controller = PersistenceController()
        
        // Override with in-memory store for testing
        let description = NSPersistentStoreDescription()
        description.url = URL(fileURLWithPath: "/dev/null")
        description.type = NSInMemoryStoreType
        
        controller.container.persistentStoreDescriptions = [description]
        controller.container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load test store: \(error)")
            }
        }
        
        return controller
    }
    
    // MARK: - Task Repository Tests
    
    func testCreateTask() async throws {
        // Given
        let title = "Test Task"
        let notes = "Test notes"
        let priority = TaskPriority.high
        
        // When
        let task = await taskRepository.createTask(
            title: title,
            notes: notes,
            priority: priority,
            dueDate: nil,
            category: nil
        )
        
        // Then
        XCTAssertEqual(task.title, title)
        XCTAssertEqual(task.notes, notes)
        XCTAssertEqual(task.priorityEnum, priority)
        XCTAssertFalse(task.isCompleted)
        XCTAssertNotNil(task.id)
        XCTAssertNotNil(task.createdAt)
    }
    
    func testFetchTasks() async throws {
        // Given
        await taskRepository.createTask(title: "Task 1", notes: nil, priority: .medium, dueDate: nil, category: nil)
        await taskRepository.createTask(title: "Task 2", notes: nil, priority: .high, dueDate: nil, category: nil)
        
        // When
        let tasks = await taskRepository.fetchTasks()
        
        // Then
        XCTAssertEqual(tasks.count, 2)
        XCTAssertTrue(tasks.contains { $0.title == "Task 1" })
        XCTAssertTrue(tasks.contains { $0.title == "Task 2" })
    }
    
    func testToggleTaskCompletion() async throws {
        // Given
        let task = await taskRepository.createTask(title: "Test Task", notes: nil, priority: .medium, dueDate: nil, category: nil)
        XCTAssertFalse(task.isCompleted)
        
        // When
        await taskRepository.toggleTaskCompletion(task)
        
        // Then
        XCTAssertTrue(task.isCompleted)
        
        // When toggled again
        await taskRepository.toggleTaskCompletion(task)
        
        // Then
        XCTAssertFalse(task.isCompleted)
    }
    
    func testDeleteTask() async throws {
        // Given
        let task = await taskRepository.createTask(title: "Task to Delete", notes: nil, priority: .medium, dueDate: nil, category: nil)
        var tasks = await taskRepository.fetchTasks()
        XCTAssertEqual(tasks.count, 1)
        
        // When
        await taskRepository.deleteTask(task)
        
        // Then
        tasks = await taskRepository.fetchTasks()
        XCTAssertEqual(tasks.count, 0)
    }
    
    func testFetchOverdueTasks() async throws {
        // Given
        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let futureDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        
        await taskRepository.createTask(title: "Overdue Task", notes: nil, priority: .medium, dueDate: pastDate, category: nil)
        await taskRepository.createTask(title: "Future Task", notes: nil, priority: .medium, dueDate: futureDate, category: nil)
        
        // When
        let overdueTasks = await taskRepository.fetchOverdueTasks()
        
        // Then
        XCTAssertEqual(overdueTasks.count, 1)
        XCTAssertEqual(overdueTasks.first?.title, "Overdue Task")
    }
    
    func testSearchTasks() async throws {
        // Given
        await taskRepository.createTask(title: "Buy groceries", notes: "Milk and bread", priority: .medium, dueDate: nil, category: nil)
        await taskRepository.createTask(title: "Complete project", notes: "Finish the mobile app", priority: .high, dueDate: nil, category: nil)
        await taskRepository.createTask(title: "Call dentist", notes: nil, priority: .low, dueDate: nil, category: nil)
        
        // When
        let searchResults = await taskRepository.searchTasks(query: "project")
        
        // Then
        XCTAssertEqual(searchResults.count, 1)
        XCTAssertEqual(searchResults.first?.title, "Complete project")
    }
    
    // MARK: - Category Repository Tests
    
    func testCreateCategory() async throws {
        // Given
        let name = "Work"
        let colorHex = "#007AFF"
        let icon = "briefcase"
        
        // When
        let category = await categoryRepository.createCategory(name: name, colorHex: colorHex, icon: icon)
        
        // Then
        XCTAssertEqual(category.name, name)
        XCTAssertEqual(category.colorHex, colorHex)
        XCTAssertEqual(category.icon, icon)
        XCTAssertNotNil(category.id)
        XCTAssertNotNil(category.createdAt)
    }
    
    func testFetchCategories() async throws {
        // Given
        await categoryRepository.createCategory(name: "Work", colorHex: "#007AFF", icon: "briefcase")
        await categoryRepository.createCategory(name: "Personal", colorHex: "#FF6B6B", icon: "person")
        
        // When
        let categories = await categoryRepository.fetchCategories()
        
        // Then
        XCTAssertEqual(categories.count, 2)
        XCTAssertTrue(categories.contains { $0.name == "Work" })
        XCTAssertTrue(categories.contains { $0.name == "Personal" })
    }
    
    func testDeleteCategory() async throws {
        // Given
        let category = await categoryRepository.createCategory(name: "Test Category", colorHex: "#007AFF", icon: "folder")
        var categories = await categoryRepository.fetchCategories()
        XCTAssertEqual(categories.count, 1)
        
        // When
        await categoryRepository.deleteCategory(category)
        
        // Then
        categories = await categoryRepository.fetchCategories()
        XCTAssertEqual(categories.count, 0)
    }
    
    // MARK: - Task Priority Tests
    
    func testTaskPriorityEnum() {
        // Test priority enum values
        XCTAssertEqual(TaskPriority.low.rawValue, 0)
        XCTAssertEqual(TaskPriority.medium.rawValue, 1)
        XCTAssertEqual(TaskPriority.high.rawValue, 2)
        
        // Test priority colors
        XCTAssertEqual(TaskPriority.low.color, .green)
        XCTAssertEqual(TaskPriority.medium.color, .orange)
        XCTAssertEqual(TaskPriority.high.color, .red)
        
        // Test sort order
        XCTAssertEqual(TaskPriority.high.sortOrder, 0)
        XCTAssertEqual(TaskPriority.medium.sortOrder, 1)
        XCTAssertEqual(TaskPriority.low.sortOrder, 2)
    }
    
    // MARK: - Task Entity Tests
    
    func testTaskSubtaskRelationship() async throws {
        // Given
        let parentTask = await taskRepository.createTask(title: "Parent Task", notes: nil, priority: .medium, dueDate: nil, category: nil)
        let subtask1 = await taskRepository.createTask(title: "Subtask 1", notes: nil, priority: .medium, dueDate: nil, category: nil, parentTask: parentTask)
        let subtask2 = await taskRepository.createTask(title: "Subtask 2", notes: nil, priority: .medium, dueDate: nil, category: nil, parentTask: parentTask)
        
        // When
        let subtasks = parentTask.subtaskArray
        
        // Then
        XCTAssertEqual(subtasks.count, 2)
        XCTAssertTrue(subtasks.contains(subtask1))
        XCTAssertTrue(subtasks.contains(subtask2))
        XCTAssertEqual(subtask1.parentTask, parentTask)
        XCTAssertEqual(subtask2.parentTask, parentTask)
    }
    
    func testTaskCompletionPercentage() async throws {
        // Given
        let parentTask = await taskRepository.createTask(title: "Parent Task", notes: nil, priority: .medium, dueDate: nil, category: nil)
        let subtask1 = await taskRepository.createTask(title: "Subtask 1", notes: nil, priority: .medium, dueDate: nil, category: nil, parentTask: parentTask)
        let subtask2 = await taskRepository.createTask(title: "Subtask 2", notes: nil, priority: .medium, dueDate: nil, category: nil, parentTask: parentTask)
        
        // When - no subtasks completed
        var completionPercentage = parentTask.completionPercentage
        
        // Then
        XCTAssertEqual(completionPercentage, 0.0, accuracy: 0.01)
        
        // When - one subtask completed
        await taskRepository.toggleTaskCompletion(subtask1)
        completionPercentage = parentTask.completionPercentage
        
        // Then
        XCTAssertEqual(completionPercentage, 0.5, accuracy: 0.01)
        
        // When - all subtasks completed
        await taskRepository.toggleTaskCompletion(subtask2)
        completionPercentage = parentTask.completionPercentage
        
        // Then
        XCTAssertEqual(completionPercentage, 1.0, accuracy: 0.01)
    }
    
    // MARK: - Performance Tests
    
    func testTaskCreationPerformance() {
        measure {
            Task {
                for i in 1...100 {
                    await taskRepository.createTask(
                        title: "Task \(i)",
                        notes: "Notes for task \(i)",
                        priority: .medium,
                        dueDate: nil,
                        category: nil
                    )
                }
            }
        }
    }
}