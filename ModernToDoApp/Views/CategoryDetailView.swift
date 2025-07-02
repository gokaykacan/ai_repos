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
    
    // Modern, accessible color palette with vibrant, distinct colors
    private let predefinedColors = [
        // Primary vibrant colors
        "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7",
        "#DDA0DD", "#FF8A65", "#81C784", "#64B5F6", "#FFB74D",
        
        // Secondary rich colors  
        "#E57373", "#4DB6AC", "#7986CB", "#AED581", "#FFD54F",
        "#F06292", "#FF7043", "#26A69A", "#42A5F5", "#FFA726",
        
        // Deep accent colors
        "#8E24AA", "#D32F2F", "#1976D2", "#388E3C", "#F57C00",
        "#C2185B", "#5D4037", "#455A64", "#512DA8", "#00796B"
    ]
    
    // Comprehensive, meaningful SF Symbol icons optimized for categories
    private let allCategoryIcons = [
        // Work & Professional
        "briefcase.fill", "building.2.fill", "laptopcomputer", "doc.text.fill", "chart.bar.fill",
        
        // Personal & Life
        "person.fill", "heart.fill", "house.fill", "car.fill", "airplane",
        
        // Activities & Hobbies  
        "sportscourt.fill", "book.fill", "music.note", "camera.fill", "gamecontroller.fill",
        
        // Organization & Planning
        "folder.fill", "calendar", "clock.fill", "flag.fill", "star.fill",
        
        // Communication & Social
        "phone.fill", "envelope.fill", "message.fill", "person.2.fill", "globe",
        
        // Health & Wellness
        "cross.case.fill", "leaf.fill", "dumbbell.fill", "bed.double.fill", "fork.knife",
        
        // Shopping & Finance
        "cart.fill", "creditcard.fill", "banknote", "bag.fill", "gift.fill",
        
        // Education & Learning
        "graduationcap.fill", "pencil", "book.closed.fill", "lightbulb.fill", "studentdesk",
        
        // Technology & Digital
        "desktopcomputer", "iphone", "wifi", "cloud.fill", "externaldrive.fill"
    ]
    
    // Filtered icons that are actually available in the current iOS version
    private var categoryIcons: [String] {
        return allCategoryIcons.filter { iconName in
            // Check if the SF Symbol exists in the current iOS version
            UIImage(systemName: iconName) != nil
        }
    }
    
    init(category: TaskCategory? = nil) {
        self.category = category
        self.isEditing = category != nil
        
        self._name = State(initialValue: category?.name ?? "")
        self._selectedColor = State(initialValue: Color(hex: category?.colorHex ?? "#007AFF"))
        self._selectedIcon = State(initialValue: category?.icon ?? "folder.fill")
    }
    
    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                Form {
                    nameSection
                    colorSection
                    iconSection
                    if isEditing {
                        statsSection
                    }
                }
                .navigationTitle(isEditing ? "nav.edit_category".localized : "nav.new_category".localized)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("action.cancel".localized) {
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("action.save".localized) {
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
        } else {
            NavigationView {
                Form {
                    nameSection
                    colorSection
                    iconSection
                    if isEditing {
                        statsSection
                    }
                }
                .navigationTitle(isEditing ? "nav.edit_category".localized : "nav.new_category".localized)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("action.cancel".localized) {
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("action.save".localized) {
                            saveCategory()
                        }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .navigationViewStyle(StackNavigationViewStyle())
            }
            .simultaneousGesture(
                TapGesture()
                    .onEnded { _ in
                        UIApplication.shared.dismissKeyboard()
                    }
            )
        }
    }
    
    private var nameSection: some View {
        Section("category.name_section".localized) {
            TextField("category.name_placeholder".localized, text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
    
    private var colorSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                // Color preview with live icon demonstration
                HStack(spacing: 12) {
                    Text("category.color".localized)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Live preview of selected color with icon
                    HStack(spacing: 8) {
                        Circle()
                            .fill(selectedColor)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Image(systemName: selectedIcon)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                            )
                        
                        Text("category.preview".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Enhanced color grid with better spacing and feedback
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 12) {
                    ForEach(predefinedColors, id: \.self) { colorHex in
                        let color = Color(hex: colorHex)
                        let isSelected = selectedColor.hexString == colorHex
                        
                        Circle()
                            .fill(color)
                            .frame(width: 44, height: 44)
                            .overlay(
                                // Selection indicator with checkmark
                                Circle()
                                    .stroke(Color.primary, lineWidth: isSelected ? 3 : 0)
                                    .animation(.easeInOut(duration: 0.2), value: isSelected)
                            )
                            .overlay(
                                // Checkmark for selected color
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .opacity(isSelected ? 1 : 0)
                                    .scaleEffect(isSelected ? 1.0 : 0.5)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                            )
                            .scaleEffect(isSelected ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                            .onTapGesture {
                                // Haptic feedback
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                                
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedColor = color
                                }
                            }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private var iconSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                Text("category.icon".localized)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // Enhanced icon grid with responsive columns and better visual hierarchy
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: adaptiveColumnCount), spacing: 16) {
                    ForEach(categoryIcons, id: \.self) { icon in
                        let isSelected = selectedIcon == icon
                        
                        VStack(spacing: 4) {
                            // Icon container with modern design
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isSelected ? selectedColor : selectedColor.opacity(0.15))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: icon)
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(isSelected ? .white : selectedColor)
                                        .animation(.easeInOut(duration: 0.2), value: isSelected)
                                )
                                .overlay(
                                    // Selection border with rounded rectangle
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.primary, lineWidth: isSelected ? 2.5 : 0)
                                        .animation(.easeInOut(duration: 0.2), value: isSelected)
                                )
                                .scaleEffect(isSelected ? 1.05 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                            
                            // Icon accessibility label (optional, can be hidden for cleaner look)
                            if isSelected {
                                Circle()
                                    .fill(selectedColor)
                                    .frame(width: 6, height: 6)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .onTapGesture {
                            // Haptic feedback for icon selection
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedIcon = icon
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // Fixed column count to prevent layout feedback loops
    private var adaptiveColumnCount: Int {
        // Use fixed column count to prevent recursive layout on iPad
        return 5
    }
    
    private var statsSection: some View {
        Section("category.statistics".localized) {
            if let category = category {
                HStack {
                    Text("stats.tasks".localized)
                    Spacer()
                    Text("\(category.tasks?.count ?? 0)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("stats.completed".localized)
                    Spacer()
                    Text("\(completedTasksCount)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("stats.created".localized)
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