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
}