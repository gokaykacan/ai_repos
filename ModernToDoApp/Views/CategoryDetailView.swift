import SwiftUI
import CoreData
import Foundation

struct CategoryDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    @State private var selectedColor: Color
    @State private var selectedIcon: String
    @State private var showingColorPicker = false
    
    let category: TaskCategory?
    let isEditing: Bool
    
    private let predefinedColors = [
        "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7",
        "#DDA0DD", "#98D8C8", "#F7DC6F", "#BB8FCE", "#85C1E9",
        "#F8C471", "#82E0AA", "#F1948A", "#85C1E9", "#D7BDE2"
    ]
    
    private let categoryIcons = [
        "folder", "person", "house", "car", "briefcase",
        "heart", "star", "flag", "bookmark", "tag",
        "calendar", "clock", "location", "phone", "envelope"
    ]
    
    init(category: TaskCategory? = nil) {
        self.category = category
        self.isEditing = category != nil
        
        self._name = State(initialValue: category?.name ?? "")
        self._selectedColor = State(initialValue: Color(hex: category?.colorHex ?? "#007AFF"))
        self._selectedIcon = State(initialValue: category?.icon ?? "folder")
    }
    
    var body: some View {
        NavigationView {
            Form {
                nameSection
                colorSection
                iconSection
                if isEditing {
                    statsSection
                }
            }
            .navigationTitle(isEditing ? "Edit Category" : "New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveCategory()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    UIApplication.shared.dismissKeyboard()
                }
        )
    }
    
    private var nameSection: some View {
        Section("Name") {
            TextField("Enter category name", text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
    
    private var colorSection: some View {
        Section("Color") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                ForEach(predefinedColors, id: \.self) { colorHex in
                    Circle()
                        .fill(Color(hex: colorHex))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .stroke(selectedColor.hexString == colorHex ? Color.primary : Color.clear, lineWidth: 3)
                        )
                        .onTapGesture {
                            selectedColor = Color(hex: colorHex)
                        }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private var iconSection: some View {
        Section("Icon") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                ForEach(categoryIcons, id: \.self) { icon in
                    Circle()
                        .fill(selectedColor.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: icon)
                                .font(.title3)
                                .foregroundColor(selectedColor)
                        )
                        .overlay(
                            Circle()
                                .stroke(selectedIcon == icon ? Color.primary : Color.clear, lineWidth: 2)
                        )
                        .onTapGesture {
                            selectedIcon = icon
                        }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private var statsSection: some View {
        Section("Statistics") {
            if let category = category {
                HStack {
                    Text("Tasks")
                    Spacer()
                    Text("\(category.tasks?.count ?? 0)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Completed")
                    Spacer()
                    Text("\(completedTasksCount)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Created")
                    Spacer()
                    Text(DateFormatter.taskDate.string(from: category.createdAt ?? Date()))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var completedTasksCount: Int {
        guard let category = category,
              let tasks = category.tasks as? Set<Task> else { return 0 }
        return tasks.filter { $0.isCompleted }.count
    }
    
    private func saveCategory() {
        withAnimation {
            if let existingCategory = category {
                // Update existing category
                existingCategory.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                existingCategory.colorHex = selectedColor.hexString
                existingCategory.icon = selectedIcon
            } else {
                // Create new category
                let newCategory = TaskCategory(context: viewContext)
                newCategory.id = UUID()
                newCategory.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                newCategory.colorHex = selectedColor.hexString
                newCategory.icon = selectedIcon
                newCategory.createdAt = Date()
                newCategory.sortOrder = Int16(nextSortOrder())
            }
            
            do {
                try viewContext.save()
                dismiss()
            } catch {
                print("Error saving category: \(error)")
            }
        }
    }
    
    private func nextSortOrder() -> Int {
        let request: NSFetchRequest<TaskCategory> = TaskCategory.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TaskCategory.sortOrder, ascending: false)]
        request.fetchLimit = 1
        
        do {
            let categories = try viewContext.fetch(request)
            return Int(categories.first?.sortOrder ?? -1) + 1
        } catch {
            return 0
        }
    }
}

struct CategoryDetailView_Previews: PreviewProvider {
    static var previews: some View {
        CategoryDetailView()
            .environment(\.managedObjectContext, CoreDataStack.shared.container.viewContext)
    }
}