import SwiftUI
import UniformTypeIdentifiers

struct DragAndDropModifier: ViewModifier {
    let task: Task
    let onDrop: (Task, Task) -> Void
    
    func body(content: Content) -> some View {
        content
            .onDrag {
                NSItemProvider(object: TaskDragItem(task: task))
            }
            .onDrop(of: [UTType.text], delegate: TaskDropDelegate(
                task: task,
                onDrop: onDrop
            ))
    }
}

class TaskDragItem: NSObject, NSItemProviderWriting {
    let task: Task
    
    init(task: Task) {
        self.task = task
    }
    
    static var writableTypeIdentifiersForItemProvider: [String] {
        [UTType.text.identifier]
    }
    
    func loadData(withTypeIdentifier typeIdentifier: String, forItemProviderCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void) -> Progress? {
        let data = task.id?.uuidString.data(using: .utf8)
        completionHandler(data, nil)
        return nil
    }
}

struct TaskDropDelegate: DropDelegate {
    let task: Task
    let onDrop: (Task, Task) -> Void
    
    func performDrop(info: DropInfo) -> Bool {
        guard let item = info.itemProviders(for: [UTType.text]).first else {
            return false
        }
        
        item.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { data, error in
            if let data = data as? Data,
               let uuidString = String(data: data, encoding: .utf8),
               let draggedTaskId = UUID(uuidString: uuidString) {
                
                // Find the dragged task (this would need access to the repository)
                // For now, we'll just print the IDs
                print("Dropped task \(draggedTaskId) onto \(task.id?.uuidString ?? "unknown")")
            }
        }
        
        return true
    }
    
    func dropEntered(info: DropInfo) {
        // Visual feedback when drag enters
    }
    
    func dropExited(info: DropInfo) {
        // Remove visual feedback when drag exits
    }
}

extension View {
    func taskDragAndDrop(
        task: Task,
        onDrop: @escaping (Task, Task) -> Void
    ) -> some View {
        self.modifier(DragAndDropModifier(task: task, onDrop: onDrop))
    }
}