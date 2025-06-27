import Foundation

enum TaskSortOrder: String, CaseIterable, Identifiable {
    case createdDate = "createdAt"
    case dueDate = "dueDate"
    case priority = "priority"
    case title = "title"
    case completed = "isCompleted"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .createdDate:
            return "Created Date"
        case .dueDate:
            return "Due Date"
        case .priority:
            return "Priority"
        case .title:
            return "Title"
        case .completed:
            return "Completion Status"
        }
    }
    
    var systemImage: String {
        switch self {
        case .createdDate:
            return "calendar.badge.plus"
        case .dueDate:
            return "calendar.badge.exclamationmark"
        case .priority:
            return "exclamationmark.triangle"
        case .title:
            return "textformat.abc"
        case .completed:
            return "checkmark.circle"
        }
    }
}