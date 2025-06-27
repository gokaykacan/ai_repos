import Foundation
import Combine
import SwiftUI

@MainActor
final class TaskDetailViewModel: ObservableObject {
    @Published var title = ""
    @Published var notes = ""
    @Published var priority: TaskPriority = .medium
    @Published var dueDate: Date?
    @Published var selectedCategory: TaskCategory?
    @Published var isLoading = false
    @Published var showingDatePicker = false
    @Published var showingCategoryPicker = false
    @Published var hasDueDate = false
    
    @Published var subtasks: [Task] = []
    @Published var newSubtaskTitle = ""
    
    private let task: Task?
    private let taskRepository: TaskRepositoryProtocol
    private let categoryRepository: CategoryRepositoryProtocol
    private let notificationManager: NotificationManagerProtocol
    private let hapticManager: HapticManagerProtocol
    
    @Published var categories: [TaskCategory] = []
    
    var isEditing: Bool {
        task != nil
    }
    
    var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    init(
        task: Task? = nil,
        taskRepository: TaskRepositoryProtocol,
        categoryRepository: CategoryRepositoryProtocol,
        notificationManager: NotificationManagerProtocol,
        hapticManager: HapticManagerProtocol
    ) {
        self.task = task
        self.taskRepository = taskRepository
        self.categoryRepository = categoryRepository
        self.notificationManager = notificationManager
        self.hapticManager = hapticManager
        
        loadCategories()
        
        if let task = task {
            populateFields(from: task)
        }
    }
    
    private func populateFields(from task: Task) {
        title = task.title ?? ""
        notes = task.notes ?? ""
        priority = task.priorityEnum
        dueDate = task.dueDate
        hasDueDate = task.dueDate != nil
        selectedCategory = task.category
        subtasks = task.subtaskArray
    }
    
    private func loadCategories() {
        Task {
            let fetchedCategories = await categoryRepository.fetchCategories()
            await MainActor.run {
                self.categories = fetchedCategories
            }
        }
    }
    
    func save() async -> Bool {
        guard canSave else { return false }
        
        isLoading = true
        hapticManager.playImpact(style: .medium)
        
        let success: Bool
        
        if let existingTask = task {
            success = await updateExistingTask(existingTask)
        } else {
            success = await createNewTask()
        }
        
        isLoading = false
        
        if success {
            hapticManager.playNotification(type: .success)
        } else {
            hapticManager.playNotification(type: .error)
        }
        
        return success
    }
    
    private func updateExistingTask(_ task: Task) async -> Bool {
        task.title = title
        task.notes = notes.isEmpty ? nil : notes
        task.priorityEnum = priority
        task.dueDate = hasDueDate ? dueDate : nil
        task.category = selectedCategory
        
        await taskRepository.updateTask(task)
        
        await notificationManager.cancelNotification(for: task)
        
        if let dueDate = task.dueDate, dueDate > Date(), !task.isCompleted {
            await notificationManager.scheduleNotification(for: task)
        }
        
        return true
    }
    
    private func createNewTask() async -> Bool {
        let newTask = await taskRepository.createTask(
            title: title,
            notes: notes.isEmpty ? nil : notes,
            priority: priority,
            dueDate: hasDueDate ? dueDate : nil,
            category: selectedCategory
        )
        
        if let dueDate = newTask.dueDate, dueDate > Date() {
            await notificationManager.scheduleNotification(for: newTask)
        }
        
        return true
    }
    
    func addSubtask() {
        guard !newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let parentTask = task else { return }
        
        hapticManager.playImpact(style: .light)
        
        Task {
            let subtask = await taskRepository.createTask(
                title: newSubtaskTitle,
                notes: nil,
                priority: .medium,
                dueDate: nil,
                category: parentTask.category,
                parentTask: parentTask
            )
            
            await MainActor.run {
                self.subtasks.append(subtask)
                self.newSubtaskTitle = ""
            }
        }
    }
    
    func toggleSubtaskCompletion(_ subtask: Task) {
        hapticManager.playImpact(style: .light)
        
        Task {
            await taskRepository.toggleTaskCompletion(subtask)
            
            await MainActor.run {
                if let index = self.subtasks.firstIndex(of: subtask) {
                    self.subtasks[index] = subtask
                }
            }
        }
    }
    
    func deleteSubtask(_ subtask: Task) {
        hapticManager.playImpact(style: .medium)
        
        Task {
            await taskRepository.deleteTask(subtask)
            
            await MainActor.run {
                self.subtasks.removeAll { $0 == subtask }
            }
        }
    }
    
    func toggleDueDate() {
        hasDueDate.toggle()
        if !hasDueDate {
            dueDate = nil
        } else if dueDate == nil {
            dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        }
        hapticManager.playSelection()
    }
    
    func reset() {
        title = ""
        notes = ""
        priority = .medium
        dueDate = nil
        hasDueDate = false
        selectedCategory = nil
        subtasks = []
        newSubtaskTitle = ""
    }
}