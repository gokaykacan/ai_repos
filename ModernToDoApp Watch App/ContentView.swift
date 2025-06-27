import SwiftUI
import WatchKit

struct ContentView: View {
    @StateObject private var viewModel = WatchTaskViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.tasks.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checklist")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                        
                        Text("No Tasks")
                            .font(.headline)
                        
                        Text("Add tasks on your iPhone")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    taskList
                }
            }
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.loadTasks()
            }
            .refreshable {
                viewModel.loadTasks()
            }
        }
    }
    
    private var taskList: some View {
        List {
            if !viewModel.todayTasks.isEmpty {
                Section("Today") {
                    ForEach(viewModel.todayTasks) { task in
                        WatchTaskRowView(
                            task: task,
                            onToggleCompletion: viewModel.toggleTaskCompletion
                        )
                    }
                }
            }
            
            if !viewModel.overdueTasks.isEmpty {
                Section("Overdue") {
                    ForEach(viewModel.overdueTasks) { task in
                        WatchTaskRowView(
                            task: task,
                            onToggleCompletion: viewModel.toggleTaskCompletion
                        )
                    }
                }
            }
            
            Section("All Tasks") {
                ForEach(viewModel.incompleteTasks) { task in
                    WatchTaskRowView(
                        task: task,
                        onToggleCompletion: viewModel.toggleTaskCompletion
                    )
                }
            }
        }
        .listStyle(.carousel)
    }
}

struct WatchTaskRowView: View {
    let task: WatchTaskData
    let onToggleCompletion: (WatchTaskData) -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Button(action: {
                onToggleCompletion(task)
                WKInterfaceDevice.current().play(.click)
            }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.isCompleted ? .green : .gray)
                    .font(.title3)
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                
                HStack(spacing: 4) {
                    if task.priority > 0 {
                        Circle()
                            .fill(task.priorityColor)
                            .frame(width: 4, height: 4)
                    }
                    
                    if let categoryName = task.categoryName {
                        Text(categoryName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if let dueDate = task.dueDate {
                        Text(DateFormatter.watchDate.string(from: dueDate))
                            .font(.caption2)
                            .foregroundColor(dueDate < Date() ? .red : .secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

struct WatchTaskData: Identifiable {
    let id: UUID
    let title: String
    let isCompleted: Bool
    let priority: Int
    let dueDate: Date?
    let categoryName: String?
    let categoryColor: String?
    
    var priorityColor: Color {
        switch priority {
        case 2: return .red
        case 1: return .orange
        default: return .green
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
}

@MainActor
class WatchTaskViewModel: ObservableObject {
    @Published var tasks: [WatchTaskData] = []
    @Published var isLoading = false
    
    var incompleteTasks: [WatchTaskData] {
        tasks.filter { !$0.isCompleted }
    }
    
    var overdueTasks: [WatchTaskData] {
        tasks.filter { $0.isOverdue }
    }
    
    var todayTasks: [WatchTaskData] {
        tasks.filter { $0.isDueToday && !$0.isCompleted }
    }
    
    func loadTasks() {
        isLoading = true
        
        // In a real implementation, this would sync with the phone app
        // using WatchConnectivity or CloudKit
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.tasks = self.sampleTasks
            self.isLoading = false
        }
    }
    
    func toggleTaskCompletion(_ task: WatchTaskData) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        
        // In a real implementation, this would sync the change
        // back to the main app via WatchConnectivity
        
        var updatedTask = task
        // Note: This is a simplified approach since WatchTaskData is a struct
        // In a real implementation, you'd need to handle this properly
        
        print("Toggling completion for task: \(task.title)")
    }
    
    private var sampleTasks: [WatchTaskData] {
        [
            WatchTaskData(
                id: UUID(),
                title: "Complete project proposal",
                isCompleted: false,
                priority: 2,
                dueDate: Date(),
                categoryName: "Work",
                categoryColor: "#007AFF"
            ),
            WatchTaskData(
                id: UUID(),
                title: "Buy groceries",
                isCompleted: false,
                priority: 1,
                dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
                categoryName: "Personal",
                categoryColor: "#FF6B6B"
            ),
            WatchTaskData(
                id: UUID(),
                title: "Call mom",
                isCompleted: true,
                priority: 0,
                dueDate: nil,
                categoryName: "Personal",
                categoryColor: "#FF6B6B"
            ),
            WatchTaskData(
                id: UUID(),
                title: "Review documents",
                isCompleted: false,
                priority: 1,
                dueDate: Calendar.current.date(byAdding: .hour, value: -2, to: Date()),
                categoryName: "Work",
                categoryColor: "#007AFF"
            )
        ]
    }
}

extension DateFormatter {
    static let watchDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}