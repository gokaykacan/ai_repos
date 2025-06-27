import Foundation
import Combine
import SwiftUI

@MainActor
final class CategoriesViewModel: ObservableObject {
    @Published var categories: [TaskCategory] = []
    @Published var isLoading = false
    @Published var showingAddCategory = false
    @Published var editingCategory: TaskCategory?
    
    private let categoryRepository: CategoryRepositoryProtocol
    private let hapticManager: HapticManagerProtocol
    
    private var cancellables = Set<AnyCancellable>()
    
    init(
        categoryRepository: CategoryRepositoryProtocol,
        hapticManager: HapticManagerProtocol
    ) {
        self.categoryRepository = categoryRepository
        self.hapticManager = hapticManager
        
        setupBindings()
        loadCategories()
    }
    
    private func setupBindings() {
        categoryRepository.createCategoryPublisher()
            .receive(on: DispatchQueue.main)
            .assign(to: \.categories, on: self)
            .store(in: &cancellables)
    }
    
    func loadCategories() {
        isLoading = true
        
        Task {
            let fetchedCategories = await categoryRepository.fetchCategories()
            await MainActor.run {
                self.categories = fetchedCategories
                self.isLoading = false
            }
        }
    }
    
    func createCategory(name: String, colorHex: String, icon: String) {
        hapticManager.playImpact(style: .medium)
        
        Task {
            await categoryRepository.createCategory(
                name: name,
                colorHex: colorHex,
                icon: icon
            )
            
            await MainActor.run {
                self.showingAddCategory = false
            }
        }
    }
    
    func updateCategory(_ category: TaskCategory) {
        hapticManager.playImpact(style: .medium)
        
        Task {
            await categoryRepository.updateCategory(category)
            
            await MainActor.run {
                self.editingCategory = nil
            }
        }
    }
    
    func deleteCategory(_ category: TaskCategory) {
        hapticManager.playImpact(style: .heavy)
        
        Task {
            await categoryRepository.deleteCategory(category)
        }
    }
    
    func moveCategories(from source: IndexSet, to destination: Int) {
        var updatedCategories = categories
        updatedCategories.move(fromOffsets: source, toOffset: destination)
        
        for (index, category) in updatedCategories.enumerated() {
            category.sortOrder = Int16(index)
        }
        
        hapticManager.playSelection()
        
        Task {
            for category in updatedCategories {
                await categoryRepository.updateCategory(category)
            }
        }
    }
}