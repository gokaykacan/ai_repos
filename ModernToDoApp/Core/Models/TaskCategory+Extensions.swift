import Foundation
import CoreData
import SwiftUI

extension TaskCategory {
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(UUID(), forKey: "id")
        setPrimitiveValue(Date(), forKey: "createdAt")
        setPrimitiveValue("#007AFF", forKey: "colorHex")
        setPrimitiveValue("folder", forKey: "icon")
        setPrimitiveValue(0, forKey: "sortOrder")
    }
}

extension TaskCategory {
    var color: Color {
        Color(hex: colorHex ?? "#007AFF")
    }
    
    var taskArray: [Task] {
        let set = tasks as? Set<Task> ?? []
        return set.sorted { $0.createdAt ?? Date() < $1.createdAt ?? Date() }
    }
    
    var completedTasks: [Task] {
        taskArray.filter { $0.isCompleted }
    }
    
    var incompleteTasks: [Task] {
        taskArray.filter { !$0.isCompleted }
    }
    
    var taskCount: Int {
        taskArray.count
    }
    
    var completedTaskCount: Int {
        completedTasks.count
    }
    
    var completionPercentage: Double {
        guard taskCount > 0 else { return 0.0 }
        return Double(completedTaskCount) / Double(taskCount)
    }
}