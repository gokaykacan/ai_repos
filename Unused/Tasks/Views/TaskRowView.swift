import SwiftUI

struct TaskRowView: View {
    let task: Task
    let onToggleCompletion: (Task) -> Void
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 12) {
            completionButton
            
            VStack(alignment: .leading, spacing: 4) {
                titleSection
                
                if let notes = task.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondaryLabel)
                        .lineLimit(2)
                }
                
                metadataSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .trailing, spacing: 4) {
                priorityIndicator
                
                if task.subtaskArray.count > 0 {
                    subtaskProgress
                }
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(task.isCompleted ? Color.secondarySystemBackground : Color.systemBackground)
                .shadow(
                    color: .black.opacity(0.05),
                    radius: isPressed ? 8 : 2,
                    x: 0,
                    y: isPressed ? 4 : 1
                )
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.1, maximumDistance: 50) {
            // Long press completed
        } onPressingChanged: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive) {
                // Delete handled by parent
            }
            .tint(.red)
            
            Button("Edit") {
                onTap()
            }
            .tint(.blue)
        }
        .swipeActions(edge: .leading) {
            Button {
                onToggleCompletion(task)
            } label: {
                Label(task.isCompleted ? "Incomplete" : "Complete", 
                      systemImage: task.isCompleted ? "xmark.circle" : "checkmark.circle")
            }
            .tint(task.isCompleted ? .orange : .green)
        }
    }
    
    private var completionButton: some View {
        Button(action: { onToggleCompletion(task) }) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundColor(task.isCompleted ? .green : .gray)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var titleSection: some View {
        HStack {
            Text(task.title ?? "Untitled Task")
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(task.isCompleted ? .secondaryLabel : .label)
                .strikethrough(task.isCompleted)
            
            if let category = task.category {
                CategoryTagView(category: category)
            }
        }
    }
    
    private var metadataSection: some View {
        HStack(spacing: 8) {
            if let dueDate = task.dueDate {
                dueDateView(dueDate)
            }
            
            if task.isOverdue {
                Label("Overdue", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
    }
    
    private func dueDateView(_ dueDate: Date) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "calendar")
                .font(.caption2)
            
            Text(DateFormatter.taskDueDate.string(from: dueDate))
                .font(.caption2)
        }
        .foregroundColor(task.isOverdue ? .red : .secondaryLabel)
    }
    
    private var priorityIndicator: some View {
        Image(systemName: task.priorityEnum.systemImage)
            .font(.caption)
            .foregroundColor(task.priorityEnum.color)
    }
    
    private var subtaskProgress: some View {
        VStack(spacing: 2) {
            Text("\(task.completedSubtasks.count)/\(task.subtaskArray.count)")
                .font(.caption2)
                .foregroundColor(.secondaryLabel)
            
            ProgressView(value: task.completionPercentage)
                .frame(width: 30)
                .scaleEffect(0.8)
        }
    }
}

struct CategoryTagView: View {
    let category: TaskCategory
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.icon ?? "folder")
                .font(.caption2)
            
            Text(category.name ?? "Category")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(category.color.opacity(0.2))
        .foregroundColor(category.color)
        .cornerRadius(4)
    }
}

extension DateFormatter {
    static let taskDueDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()
}

struct TaskRowView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let task = Task(context: context)
        task.title = "Sample Task"
        task.notes = "This is a sample task with some notes"
        task.priority = 2
        task.dueDate = Date()
        
        return TaskRowView(
            task: task,
            onToggleCompletion: { _ in },
            onTap: { }
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}