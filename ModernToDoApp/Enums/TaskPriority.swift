import Foundation
import SwiftUI

enum RecurrenceType: String, CaseIterable, Identifiable {
    case none = "none"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .none:
            return "No Repeat"
        case .daily:
            return "Daily"
        case .weekly:
            return "Weekly"
        case .monthly:
            return "Monthly"
        case .yearly:
            return "Yearly"
        }
    }
    
    var description: String {
        switch self {
        case .none:
            return "Does not repeat"
        case .daily:
            return "Every day"
        case .weekly:
            return "Every week"
        case .monthly:
            return "Every month"
        case .yearly:
            return "Every year"
        }
    }
    
    var systemImage: String {
        switch self {
        case .none:
            return "minus.circle"
        case .daily:
            return "sun.max"
        case .weekly:
            return "calendar.day.timeline.leading"
        case .monthly:
            return "calendar"
        case .yearly:
            return "calendar.badge.clock"
        }
    }
    
    var color: Color {
        switch self {
        case .none:
            return .gray
        case .daily:
            return .orange
        case .weekly:
            return .blue
        case .monthly:
            return .green
        case .yearly:
            return .purple
        }
    }
    
    /// Calculate the next due date based on the recurrence type
    func nextDueDate(from currentDueDate: Date) -> Date {
        let calendar = Calendar.current
        
        switch self {
        case .none:
            return currentDueDate
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: currentDueDate) ?? currentDueDate
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: currentDueDate) ?? currentDueDate
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: currentDueDate) ?? currentDueDate
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: currentDueDate) ?? currentDueDate
        }
    }
    
    /// Get the appropriate next date handling edge cases
    func safeNextDueDate(from currentDueDate: Date) -> Date {
        let calendar = Calendar.current
        let tentativeDate = nextDueDate(from: currentDueDate)
        
        switch self {
        case .none, .daily, .weekly:
            return tentativeDate
        case .monthly:
            // Handle month-end edge cases
            let originalDay = calendar.component(.day, from: currentDueDate)
            let tentativeMonth = calendar.component(.month, from: tentativeDate)
            let tentativeYear = calendar.component(.year, from: tentativeDate)
            
            guard let range = calendar.range(of: .day, in: .month, for: tentativeDate) else {
                return tentativeDate
            }
            
            let maxDayInMonth = range.count
            let targetDay = min(originalDay, maxDayInMonth)
            
            return calendar.date(from: DateComponents(
                year: tentativeYear,
                month: tentativeMonth,
                day: targetDay,
                hour: calendar.component(.hour, from: currentDueDate),
                minute: calendar.component(.minute, from: currentDueDate)
            )) ?? tentativeDate
            
        case .yearly:
            // Handle leap year edge case
            let originalComponents = calendar.dateComponents([.month, .day, .hour, .minute], from: currentDueDate)
            let tentativeYear = calendar.component(.year, from: tentativeDate)
            
            // Special handling for Feb 29 on non-leap years
            if originalComponents.month == 2 && originalComponents.day == 29 {
                let isLeapYear = calendar.date(from: DateComponents(year: tentativeYear, month: 2, day: 29)) != nil
                if !isLeapYear {
                    return calendar.date(from: DateComponents(
                        year: tentativeYear,
                        month: 2,
                        day: 28,
                        hour: originalComponents.hour,
                        minute: originalComponents.minute
                    )) ?? tentativeDate
                }
            }
            
            return calendar.date(from: DateComponents(
                year: tentativeYear,
                month: originalComponents.month,
                day: originalComponents.day,
                hour: originalComponents.hour,
                minute: originalComponents.minute
            )) ?? tentativeDate
        }
    }
}

enum TaskPriority: Int, CaseIterable, Identifiable {
    case low = 0
    case medium = 1
    case high = 2
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        }
    }
    
    var color: Color {
        switch self {
        case .low:
            return .green
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }
    
    var systemImage: String {
        switch self {
        case .low:
            return "arrow.down.circle.fill"
        case .medium:
            return "minus.circle.fill"
        case .high:
            return "arrow.up.circle.fill"
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .high:
            return 0
        case .medium:
            return 1
        case .low:
            return 2
        }
    }
}