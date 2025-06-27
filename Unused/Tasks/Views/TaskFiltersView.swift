import SwiftUI

struct TaskFiltersView: View {
    @ObservedObject var viewModel: TaskListViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                categoryFilterSection
                
                priorityFilterSection
                
                sortOrderSection
                
                displayOptionsSection
                
                actionsSection
            }
            .navigationTitle("Filters & Sorting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear All") {
                        viewModel.clearFilters()
                    }
                    .foregroundColor(.orange)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var categoryFilterSection: some View {
        Section("Filter by Category") {
            HStack {
                Text("Selected Category")
                Spacer()
                if let selectedCategory = viewModel.selectedCategory {
                    HStack {
                        Image(systemName: selectedCategory.icon ?? "folder")
                            .foregroundColor(selectedCategory.color)
                        Text(selectedCategory.name ?? "Unnamed")
                            .foregroundColor(.secondaryLabel)
                    }
                } else {
                    Text("All Categories")
                        .foregroundColor(.secondaryLabel)
                }
            }
            
            ForEach(viewModel.categories) { category in
                Button(action: {
                    if viewModel.selectedCategory == category {
                        viewModel.selectedCategory = nil
                    } else {
                        viewModel.selectedCategory = category
                    }
                }) {
                    HStack {
                        Image(systemName: category.icon ?? "folder")
                            .foregroundColor(category.color)
                        
                        Text(category.name ?? "Unnamed Category")
                            .foregroundColor(.label)
                        
                        Spacer()
                        
                        if viewModel.selectedCategory == category {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
    }
    
    private var priorityFilterSection: some View {
        Section("Filter by Priority") {
            ForEach(TaskPriority.allCases) { priority in
                Button(action: {
                    if viewModel.selectedPriorityFilter == priority {
                        viewModel.selectedPriorityFilter = nil
                    } else {
                        viewModel.selectedPriorityFilter = priority
                    }
                }) {
                    HStack {
                        Image(systemName: priority.systemImage)
                            .foregroundColor(priority.color)
                        
                        Text(priority.title)
                            .foregroundColor(.label)
                        
                        Spacer()
                        
                        if viewModel.selectedPriorityFilter == priority {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
    }
    
    private var sortOrderSection: some View {
        Section("Sort Order") {
            ForEach(TaskSortOrder.allCases) { sortOrder in
                Button(action: {
                    viewModel.sortOrder = sortOrder
                }) {
                    HStack {
                        Image(systemName: sortOrder.systemImage)
                            .foregroundColor(.blue)
                        
                        Text(sortOrder.title)
                            .foregroundColor(.label)
                        
                        Spacer()
                        
                        if viewModel.sortOrder == sortOrder {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
    }
    
    private var displayOptionsSection: some View {
        Section("Display Options") {
            Toggle("Show Completed Tasks", isOn: $viewModel.showCompletedTasks)
        }
    }
    
    private var actionsSection: some View {
        Section {
            Button("Reset to Default") {
                viewModel.sortOrder = .createdDate
                viewModel.showCompletedTasks = true
                viewModel.selectedCategory = nil
                viewModel.selectedPriorityFilter = nil
            }
            .foregroundColor(.blue)
        }
    }
}

struct TaskFiltersView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = TaskListViewModel(
            taskRepository: TaskRepository(persistenceController: PersistenceController.shared),
            categoryRepository: CategoryRepository(persistenceController: PersistenceController.shared),
            notificationManager: NotificationManager.shared,
            hapticManager: HapticManager()
        )
        
        TaskFiltersView(viewModel: viewModel)
    }
}