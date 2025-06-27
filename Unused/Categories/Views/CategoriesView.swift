import SwiftUI

struct CategoriesView: View {
    @EnvironmentObject var container: DependencyContainer
    @StateObject private var viewModel = CategoriesViewModelWrapper()
    @State private var selectedCategory: TaskCategory?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.systemGroupedBackground
                    .ignoresSafeArea()
                
                if viewModel.wrappedViewModel?.isLoading == true {
                    ProgressView("Loading categories...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.wrappedViewModel?.categories.isEmpty == true {
                    EmptyStateView(
                        systemImage: "folder.badge.plus",
                        title: "No Categories",
                        subtitle: "Create categories to organize your tasks better",
                        primaryButtonTitle: "Add Category",
                        primaryAction: { viewModel.wrappedViewModel?.showingAddCategory = true }
                    )
                } else {
                    categoriesList
                }
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.wrappedViewModel?.showingAddCategory = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: .constant(viewModel.wrappedViewModel?.showingAddCategory == true)) {
            if let vm = viewModel.wrappedViewModel {
                CategoryEditView(viewModel: vm)
            }
        }
        .sheet(item: .constant(viewModel.wrappedViewModel?.editingCategory)) { category in
            if let vm = viewModel.wrappedViewModel {
                CategoryEditView(viewModel: vm, category: category)
            }
        }
        .sheet(item: $selectedCategory) { category in
            CategoryDetailView(category: category)
        }
        .onAppear {
            if viewModel.wrappedViewModel == nil {
                viewModel.wrappedViewModel = container.makeCategoriesViewModel()
            }
        }
    }
    
    private var categoriesList: some View {
        List {
            if let vm = viewModel.wrappedViewModel {
                ForEach(vm.categories) { category in
                    CategoryRowView(
                        category: category,
                        onTap: { selectedCategory = category },
                        onEdit: { vm.editingCategory = category }
                    )
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        vm.deleteCategory(vm.categories[index])
                    }
                }
                .onMove(perform: vm.moveCategories)
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
}

struct CategoryRowView: View {
    let category: TaskCategory
    let onTap: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Circle()
                    .fill(category.color)
                    .frame(width: 12, height: 12)
                
                Image(systemName: category.icon ?? "folder")
                    .font(.title2)
                    .foregroundColor(category.color)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name ?? "Unnamed Category")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.label)
                    
                    Text("\(category.taskCount) tasks")
                        .font(.caption)
                        .foregroundColor(.secondaryLabel)
                }
                
                Spacer()
                
                if category.taskCount > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(category.completedTaskCount)/\(category.taskCount)")
                            .font(.caption2)
                            .foregroundColor(.secondaryLabel)
                        
                        ProgressView(value: category.completionPercentage)
                            .frame(width: 60)
                            .scaleEffect(0.8)
                            .tint(category.color)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.tertiaryLabel)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive) {
                // Handled by parent
            }
            
            Button("Edit") {
                onEdit()
            }
            .tint(.blue)
        }
    }
}

struct CategoryDetailView: View {
    let category: TaskCategory
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Image(systemName: category.icon ?? "folder")
                        .font(.system(size: 64))
                        .foregroundColor(category.color)
                    
                    Text(category.name ?? "Unnamed Category")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                
                HStack(spacing: 40) {
                    VStack {
                        Text("\(category.taskCount)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(category.color)
                        Text("Total Tasks")
                            .font(.caption)
                            .foregroundColor(.secondaryLabel)
                    }
                    
                    VStack {
                        Text("\(category.completedTaskCount)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        Text("Completed")
                            .font(.caption)
                            .foregroundColor(.secondaryLabel)
                    }
                    
                    VStack {
                        Text("\(category.incompleteTasks.count)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        Text("Remaining")
                            .font(.caption)
                            .foregroundColor(.secondaryLabel)
                    }
                }
                
                if category.taskCount > 0 {
                    VStack(spacing: 8) {
                        Text("Progress")
                            .font(.headline)
                        
                        ProgressView(value: category.completionPercentage)
                            .tint(category.color)
                        
                        Text("\(Int(category.completionPercentage * 100))% Complete")
                            .font(.caption)
                            .foregroundColor(.secondaryLabel)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Category Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Wrapper class to handle optional CategoriesViewModel
class CategoriesViewModelWrapper: ObservableObject {
    @Published var wrappedViewModel: CategoriesViewModel?
}

struct CategoriesView_Previews: PreviewProvider {
    static var previews: some View {
        CategoriesView()
            .environmentObject(DependencyContainer())
    }
}