import Foundation
import Combine
import SwiftUI

@MainActor
final class TaskListViewModel: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var categories: [TaskCategory] = []
    @Published var selectedCategory: TaskCategory?
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var showCompletedTasks = true
    @Published var sortOrder: TaskSortOrder = .createdDate
    @Published var selectedPriorityFilter: TaskPriority?
    
    private let taskRepository: TaskRepositoryProtocol
    private let categoryRepository: CategoryRepositoryProtocol
    private let notificationManager: NotificationManagerProtocol
    private let hapticManager: HapticManagerProtocol
    
    private var cancellables = Set<AnyCancellable>()
    
    var filteredTasks: [Task] {
        var filtered = tasks
        
        if !searchText.isEmpty {
            filtered = filtered.filter { task in
                task.title?.localizedCaseInsensitiveContains(searchText) == true ||
                task.notes?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        if let selectedCategory = selectedCategory {
            filtered = filtered.filter { $0.category == selectedCategory }
        }
        
        if let priorityFilter = selectedPriorityFilter {
            filtered = filtered.filter { $0.priorityEnum == priorityFilter }
        }
        
        if !showCompletedTasks {
            filtered = filtered.filter { !$0.isCompleted }
        }
        
        return sortTasks(filtered)
    }
    
    var tasksByCategory: [TaskCategory: [Task]] {
        Dictionary(grouping: filteredTasks) { $0.category ?? TaskCategory() }
    }
    
    var overdueTasks: [Task] {
        tasks.filter { $0.isOverdue }
    }
    
    var todayTasks: [Task] {
        tasks.filter { $0.isDueToday }
    }
    
    var tomorrowTasks: [Task] {
        tasks.filter { $0.isDueTomorrow }
    }
    
    init(
        taskRepository: TaskRepositoryProtocol,
        categoryRepository: CategoryRepositoryProtocol,
        notificationManager: NotificationManagerProtocol,
        hapticManager: HapticManagerProtocol
    ) {
        self.taskRepository = taskRepository
        self.categoryRepository = categoryRepository
        self.notificationManager = notificationManager
        self.hapticManager = hapticManager
        
        setupBindings()
        loadData()
    }
    
    private func setupBindings() {
        taskRepository.createTaskPublisher()
            .receive(on: DispatchQueue.main)
            .assign(to: \.tasks, on: self)
            .store(in: &cancellables)
        
        categoryRepository.createCategoryPublisher()
            .receive(on: DispatchQueue.main)
            .assign(to: \.categories, on: self)
            .store(in: &cancellables)
    }
    
    func loadData() {
        isLoading = true
        
        Task {
            async let tasksResult = taskRepository.fetchTasks()
            async let categoriesResult = categoryRepository.fetchCategories()
            
            let (fetchedTasks, fetchedCategories) = await (tasksResult, categoriesResult)
            
            await MainActor.run {
                self.tasks = fetchedTasks
                self.categories = fetchedCategories
                self.isLoading = false
            }
        }
    }
    
    func toggleTaskCompletion(_ task: Task) {
        hapticManager.playImpact(style: .light)
        
        Task {
            await taskRepository.toggleTaskCompletion(task)
            
            if task.isCompleted {
                await notificationManager.cancelNotification(for: task)
                hapticManager.playNotification(type: .success)
            } else if let dueDate = task.dueDate, dueDate > Date() {
                await notificationManager.scheduleNotification(for: task)
            }
        }
    }
    
    func deleteTask(_ task: Task) {
        hapticManager.playImpact(style: .medium)
        
        Task {
            await notificationManager.cancelNotification(for: task)
            await taskRepository.deleteTask(task)
        }
    }
    
    func createTask(
        title: String,
        notes: String? = nil,
        priority: TaskPriority = .medium,
        dueDate: Date? = nil,
        category: TaskCategory? = nil
    ) {
        hapticManager.playImpact(style: .light)
        
        Task {
            let newTask = await taskRepository.createTask(
                title: title,
                notes: notes,
                priority: priority,
                dueDate: dueDate,
                category: category
            )
            
            if let dueDate = dueDate, dueDate > Date() {
                await notificationManager.scheduleNotification(for: newTask)
            }
        }
    }
    
    func searchTasks() {
        guard !searchText.isEmpty else {
            loadData()
            return
        }
        
        Task {
            let searchResults = await taskRepository.searchTasks(query: searchText)
            await MainActor.run {
                self.tasks = searchResults
            }
        }
    }
    
    func clearFilters() {
        selectedCategory = nil
        selectedPriorityFilter = nil
        searchText = ""
        loadData()
    }
    
    private func sortTasks(_ tasks: [Task]) -> [Task] {
        switch sortOrder {
        case .createdDate:
            return tasks.sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
        case .dueDate:
            return tasks.sorted { task1, task2 in
                switch (task1.dueDate, task2.dueDate) {
                case (.some(let date1), .some(let date2)):
                    return date1 < date2
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    return (task1.createdAt ?? Date.distantPast) > (task2.createdAt ?? Date.distantPast)
                }
            }
        case .priority:
            return tasks.sorted { $0.priorityEnum.sortOrder < $1.priorityEnum.sortOrder }
        case .title:
            return tasks.sorted { ($0.title ?? "") < ($1.title ?? "") }
        case .completed:
            return tasks.sorted { !$0.isCompleted && $1.isCompleted }
        }
    }
}