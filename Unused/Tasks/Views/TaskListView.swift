import SwiftUI

struct TaskListView: View {
    @EnvironmentObject var container: DependencyContainer
    @StateObject private var viewModel = TaskListViewModelWrapper()
    @State private var showingAddTask = false
    @State private var showingFilters = false
    @State private var selectedTask: Task?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.systemGroupedBackground
                    .ignoresSafeArea()
                
                if viewModel.wrappedViewModel?.isLoading == true {
                    ProgressView("Loading tasks...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.wrappedViewModel?.filteredTasks.isEmpty == true {
                    EmptyStateView(
                        systemImage: "checklist",
                        title: "No Tasks",
                        subtitle: (viewModel.wrappedViewModel?.searchText.isEmpty == true) ? 
                            "Tap + to create your first task" : 
                            "No tasks match your search",
                        primaryButtonTitle: (viewModel.wrappedViewModel?.searchText.isEmpty == true) ? "Add Task" : nil,
                        primaryAction: (viewModel.wrappedViewModel?.searchText.isEmpty == true) ? { showingAddTask = true } : nil
                    )
                } else {
                    taskListContent
                }
            }
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingFilters = true }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddTask = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .searchable(text: .constant(viewModel.wrappedViewModel?.searchText ?? ""), prompt: "Search tasks...")
            .refreshable {
                viewModel.wrappedViewModel?.loadData()
            }
        }
        .sheet(isPresented: $showingAddTask) {
            NavigationView {
                TaskDetailView(viewModel: container.makeTaskDetailViewModel())
            }
        }
        .sheet(isPresented: $showingFilters) {
            if let vm = viewModel.wrappedViewModel {
                TaskFiltersView(viewModel: vm)
            }
        }
        .sheet(item: $selectedTask) { task in
            NavigationView {
                TaskDetailView(viewModel: container.makeTaskDetailViewModel(task: task))
            }
        }
        .onAppear {
            if viewModel.wrappedViewModel == nil {
                viewModel.wrappedViewModel = container.makeTaskListViewModel()
            }
        }
    }
    
    private var taskListContent: some View {
        List {
            if let vm = viewModel.wrappedViewModel {
                if !vm.overdueTasks.isEmpty {
                    Section("Overdue") {
                        ForEach(vm.overdueTasks) { task in
                            TaskRowView(
                                task: task,
                                onToggleCompletion: vm.toggleTaskCompletion,
                                onTap: { selectedTask = task }
                            )
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                vm.deleteTask(vm.overdueTasks[index])
                            }
                        }
                    }
                }
                
                if !vm.todayTasks.isEmpty {
                    Section("Today") {
                        ForEach(vm.todayTasks) { task in
                            TaskRowView(
                                task: task,
                                onToggleCompletion: vm.toggleTaskCompletion,
                                onTap: { selectedTask = task }
                            )
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                vm.deleteTask(vm.todayTasks[index])
                            }
                        }
                    }
                }
                
                if !vm.tomorrowTasks.isEmpty {
                    Section("Tomorrow") {
                        ForEach(vm.tomorrowTasks) { task in
                            TaskRowView(
                                task: task,
                                onToggleCompletion: vm.toggleTaskCompletion,
                                onTap: { selectedTask = task }
                            )
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                vm.deleteTask(vm.tomorrowTasks[index])
                            }
                        }
                    }
                }
                
                Section("All Tasks") {
                    ForEach(vm.filteredTasks) { task in
                        TaskRowView(
                            task: task,
                            onToggleCompletion: vm.toggleTaskCompletion,
                            onTap: { selectedTask = task }
                        )
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            vm.deleteTask(vm.filteredTasks[index])
                        }
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
}

// Wrapper class to handle optional TaskListViewModel
class TaskListViewModelWrapper: ObservableObject {
    @Published var wrappedViewModel: TaskListViewModel?
}

struct TaskListView_Previews: PreviewProvider {
    static var previews: some View {
        TaskListView()
            .environmentObject(DependencyContainer())
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}