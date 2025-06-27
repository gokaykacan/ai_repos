import SwiftUI

struct CategoryEditView: View {
    @ObservedObject var viewModel: CategoriesViewModel
    let category: TaskCategory?
    
    @State private var name = ""
    @State private var selectedColor = Color.blue
    @State private var selectedIcon = "folder"
    @Environment(\.dismiss) private var dismiss
    
    private let availableColors: [Color] = [
        .red, .orange, .yellow, .green, .mint, .teal,
        .cyan, .blue, .indigo, .purple, .pink, .brown
    ]
    
    private let availableIcons = [
        "folder", "briefcase", "house", "car", "airplane",
        "book", "pencil", "paintbrush", "music.note", "heart",
        "star", "bell", "camera", "phone", "envelope",
        "cart", "bag", "gift", "gamecontroller", "tv"
    ]
    
    var isEditing: Bool {
        category != nil
    }
    
    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    init(viewModel: CategoriesViewModel, category: TaskCategory? = nil) {
        self.viewModel = viewModel
        self.category = category
        
        if let category = category {
            self._name = State(initialValue: category.name ?? "")
            self._selectedColor = State(initialValue: category.color)
            self._selectedIcon = State(initialValue: category.icon ?? "folder")
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                previewSection
                
                basicInfoSection
                
                colorSection
                
                iconSection
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
                    .disabled(!canSave)
                }
            }
        }
    }
    
    private var previewSection: some View {
        Section {
            HStack {
                Spacer()
                
                VStack(spacing: 12) {
                    Image(systemName: selectedIcon)
                        .font(.system(size: 48))
                        .foregroundColor(selectedColor)
                    
                    Text(name.isEmpty ? "Category Name" : name)
                        .font(.headline)
                        .foregroundColor(.label)
                }
                
                Spacer()
            }
            .padding(.vertical)
        }
    }
    
    private var basicInfoSection: some View {
        Section("Details") {
            TextField("Category name", text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
    
    private var colorSection: some View {
        Section("Color") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                ForEach(availableColors, id: \.self) { color in
                    Button(action: {
                        selectedColor = color
                    }) {
                        Circle()
                            .fill(color)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary, lineWidth: selectedColor == color ? 3 : 0)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private var iconSection: some View {
        Section("Icon") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                ForEach(availableIcons, id: \.self) { icon in
                    Button(action: {
                        selectedIcon = icon
                    }) {
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundColor(selectedIcon == icon ? selectedColor : .secondaryLabel)
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedIcon == icon ? selectedColor.opacity(0.2) : Color.clear)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private func saveCategory() {
        if let category = category {
            category.name = name
            category.colorHex = selectedColor.hexString
            category.icon = selectedIcon
            viewModel.updateCategory(category)
        } else {
            viewModel.createCategory(
                name: name,
                colorHex: selectedColor.hexString,
                icon: selectedIcon
            )
        }
        
        dismiss()
    }
}

struct CategoryEditView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = CategoriesViewModel(
            categoryRepository: CategoryRepository(persistenceController: PersistenceController.shared),
            hapticManager: HapticManager()
        )
        
        CategoryEditView(viewModel: viewModel)
    }
}