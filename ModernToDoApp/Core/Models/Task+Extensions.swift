import Foundation
import CoreData
import SwiftUI

extension Task {
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(UUID(), forKey: "id")
        setPrimitiveValue(Date(), forKey: "createdAt")
        setPrimitiveValue(Date(), forKey: "updatedAt")
        setPrimitiveValue(false, forKey: "isCompleted")
        setPrimitiveValue(false, forKey: "isRecurring")
        setPrimitiveValue("none", forKey: "recurrenceType")
        setPrimitiveValue(1, forKey: "priority")
    }
    
    // willSave method removed to prevent recursive Core Data save issues
}

extension Task {
    var priorityEnum: TaskPriority {
        get {
            TaskPriority(rawValue: Int(priority)) ?? .medium
        }
        set {
            priority = Int16(newValue.rawValue)
        }
    }
    
    var isOverdue: Bool {
        guard let dueDate = dueDate, !isCompleted else { return false }
        return dueDate < Date()
    }
    
    var isDueToday: Bool {
        guard let dueDate = dueDate else { return false }
        return Calendar.current.isDateInToday(dueDate)
    }
    
    var isDueTomorrow: Bool {
        guard let dueDate = dueDate else { return false }
        return Calendar.current.isDateInTomorrow(dueDate)
    }
    
    var subtaskArray: [Task] {
        let set = subtasks as? Set<Task> ?? []
        return set.sorted { $0.createdAt ?? Date() < $1.createdAt ?? Date() }
    }
    
    var completedSubtasks: [Task] {
        subtaskArray.filter { $0.isCompleted }
    }
    
    var incompleteSubtasks: [Task] {
        subtaskArray.filter { !$0.isCompleted }
    }
    
    var completionPercentage: Double {
        let totalSubtasks = subtaskArray.count
        guard totalSubtasks > 0 else { return isCompleted ? 1.0 : 0.0 }
        
        let completedCount = completedSubtasks.count
        return Double(completedCount) / Double(totalSubtasks)
    }
    
    // Auto-complete parent task when all subtasks are completed
    func updateParentCompletionIfNeeded() {
        guard let parentTask = parentTask else { return }
        
        // Check if all subtasks of parent are completed
        let allSubtasksCompleted = parentTask.subtaskArray.allSatisfy { $0.isCompleted }
        
        // Auto-complete parent if all subtasks are done and parent is not completed
        if allSubtasksCompleted && !parentTask.isCompleted {
            parentTask.isCompleted = true
            parentTask.updatedAt = Date()
        }
        // Auto-incomplete parent if any subtask becomes incomplete and parent was auto-completed
        else if !allSubtasksCompleted && parentTask.isCompleted && parentTask.subtaskArray.count > 0 {
            parentTask.isCompleted = false
            parentTask.updatedAt = Date()
        }
    }
    
    // MARK: - Recurrence Properties
    var recurrenceTypeEnum: RecurrenceType {
        get {
            RecurrenceType(rawValue: recurrenceType ?? "none") ?? .none
        }
        set {
            recurrenceType = newValue.rawValue
            isRecurring = newValue != .none
        }
    }
    
    var hasRecurrence: Bool {
        return isRecurring && recurrenceTypeEnum != .none
    }
    
    var nextRecurrenceDate: Date? {
        guard hasRecurrence, let dueDate = dueDate else { return nil }
        return recurrenceTypeEnum.safeNextDueDate(from: dueDate)
    }
    
    // MARK: - Recurrence Methods
    
    /// Creates a new recurring task when the current task is completed
    func createNextRecurringTask(in context: NSManagedObjectContext) -> Task? {
        guard hasRecurrence, let nextDate = nextRecurrenceDate else { return nil }
        
        // Prevent duplicate creation by checking if a task with same original ID and due date already exists
        let fetchRequest: NSFetchRequest<Task> = Task.fetchRequest()
        let recurringId = originalRecurringTaskId ?? id ?? UUID()
        fetchRequest.predicate = NSPredicate(
            format: "originalRecurringTaskId == %@ AND dueDate == %@",
            recurringId as CVarArg,
            nextDate as NSDate
        )
        
        do {
            let existingTasks = try context.fetch(fetchRequest)
            if !existingTasks.isEmpty {
                // Task already exists, don't create duplicate
                return nil
            }
        } catch {
            print("Error checking for existing recurring task: \(error)")
            return nil
        }
        
        // Create new recurring task
        let newTask = Task(context: context)
        newTask.id = UUID()
        newTask.title = self.title
        newTask.notes = self.notes
        newTask.priority = self.priority
        newTask.category = self.category
        newTask.dueDate = nextDate
        newTask.isCompleted = false
        newTask.isRecurring = true
        newTask.recurrenceType = self.recurrenceType
        newTask.originalRecurringTaskId = self.originalRecurringTaskId ?? self.id
        newTask.createdAt = Date()
        newTask.updatedAt = Date()
        
        return newTask
    }
    
    /// Handle task completion for recurring tasks
    func handleTaskCompletion(in context: NSManagedObjectContext) {
        // Update completion status
        isCompleted = true
        updatedAt = Date()
        
        // Create next recurring task if applicable
        if hasRecurrence {
            _ = createNextRecurringTask(in: context)
        }
        
        // Handle parent task completion if needed
        updateParentCompletionIfNeeded()
    }
    
    /// Check if this task is part of a recurring series
    var isPartOfRecurringSeries: Bool {
        return originalRecurringTaskId != nil || hasRecurrence
    }
    
    /// Get the original recurring task ID (either self.id or originalRecurringTaskId)
    var recurringSeriesId: UUID? {
        return originalRecurringTaskId ?? (hasRecurrence ? id : nil)
    }
}