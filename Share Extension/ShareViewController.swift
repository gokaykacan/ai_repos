import UIKit
import Social
import CoreData
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var titleTextField: UITextField!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    private var sharedText: String?
    private var sharedURL: URL?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        extractSharedContent()
    }
    
    private func setupUI() {
        title = "Add Task"
        
        // Style the save button
        saveButton.backgroundColor = .systemBlue
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.layer.cornerRadius = 8
        saveButton.addTarget(self, action: #selector(saveTask), for: .touchUpInside)
        
        // Style the cancel button
        cancelButton.setTitleColor(.systemBlue, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelShare), for: .touchUpInside)
        
        // Style text fields
        titleTextField.borderStyle = .roundedRect
        titleTextField.placeholder = "Task title"
        
        textView.layer.borderColor = UIColor.systemGray4.cgColor
        textView.layer.borderWidth = 1
        textView.layer.cornerRadius = 8
    }
    
    private func extractSharedContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            return
        }
        
        // Handle text content
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
            itemProvider.loadItem(forTypeIdentifier: UTType.text.identifier) { [weak self] item, error in
                if let text = item as? String {
                    DispatchQueue.main.async {
                        self?.sharedText = text
                        self?.populateFields()
                    }
                }
            }
        }
        
        // Handle URL content
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            itemProvider.loadItem(forTypeIdentifier: UTType.url.identifier) { [weak self] item, error in
                if let url = item as? URL {
                    DispatchQueue.main.async {
                        self?.sharedURL = url
                        self?.populateFields()
                    }
                }
            }
        }
        
        // Handle plain text (for Safari and other apps)
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            itemProvider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { [weak self] item, error in
                if let text = item as? String {
                    DispatchQueue.main.async {
                        self?.sharedText = text
                        self?.populateFields()
                    }
                }
            }
        }
    }
    
    private func populateFields() {
        var title = ""
        var notes = ""
        
        if let url = sharedURL {
            title = url.absoluteString
            notes = "Shared from: \(url.host ?? "Unknown")"
        } else if let text = sharedText {
            // Try to extract a meaningful title from the text
            let lines = text.components(separatedBy: .newlines)
            if let firstLine = lines.first, !firstLine.isEmpty {
                title = String(firstLine.prefix(100)) // Limit title length
                if lines.count > 1 {
                    notes = lines.dropFirst().joined(separator: "\n")
                }
            } else {
                title = String(text.prefix(100))
            }
        }
        
        titleTextField.text = title
        textView.text = notes
    }
    
    @objc private func saveTask() {
        guard let taskTitle = titleTextField.text, !taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showAlert(message: "Please enter a task title")
            return
        }
        
        let notes = textView.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Save to Core Data
        saveTaskToCoreData(title: taskTitle, notes: notes) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                } else {
                    self?.showAlert(message: "Failed to save task. Please try again.")
                }
            }
        }
    }
    
    @objc private func cancelShare() {
        extensionContext?.cancelRequest(withError: NSError(domain: "ShareExtension", code: 0, userInfo: [NSLocalizedDescriptionKey: "User cancelled"]))
    }
    
    private func saveTaskToCoreData(title: String, notes: String?, completion: @escaping (Bool) -> Void) {
        // Get the shared Core Data stack
        guard let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.moderntodoapp.shared") else {
            completion(false)
            return
        }
        
        let storeURL = appGroupURL.appendingPathComponent("ModernToDoApp.sqlite")
        
        // Create a separate Core Data stack for the extension
        let container = NSPersistentContainer(name: "TaskModel")
        let storeDescription = NSPersistentStoreDescription(url: storeURL)
        storeDescription.configuration = "Default"
        container.persistentStoreDescriptions = [storeDescription]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                print("Share extension Core Data error: \(error)")
                completion(false)
                return
            }
            
            let context = container.viewContext
            
            // Create the task
            let task = Task(entity: Task.entity(), insertInto: context)
            task.id = UUID()
            task.title = title
            task.notes = notes
            task.createdAt = Date()
            task.updatedAt = Date()
            task.isCompleted = false
            task.priority = 1 // Medium priority as default
            
            do {
                try context.save()
                completion(true)
            } catch {
                print("Failed to save task in share extension: \(error)")
                completion(false)
            }
        }
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Storyboard Setup
extension ShareViewController {
    override func loadView() {
        // Create the view programmatically since we're not using a storyboard
        view = UIView()
        view.backgroundColor = .systemBackground
        
        // Create UI elements
        titleTextField = UITextField()
        textView = UITextView()
        saveButton = UIButton(type: .system)
        cancelButton = UIButton(type: .system)
        
        // Configure constraints
        setupConstraints()
    }
    
    private func setupConstraints() {
        titleTextField.translatesAutoresizingMaskIntoConstraints = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(titleTextField)
        view.addSubview(textView)
        view.addSubview(saveButton)
        view.addSubview(cancelButton)
        
        saveButton.setTitle("Save Task", for: .normal)
        cancelButton.setTitle("Cancel", for: .normal)
        
        NSLayoutConstraint.activate([
            // Title field
            titleTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            titleTextField.heightAnchor.constraint(equalToConstant: 44),
            
            // Text view
            textView.topAnchor.constraint(equalTo: titleTextField.bottomAnchor, constant: 16),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            textView.heightAnchor.constraint(equalToConstant: 120),
            
            // Buttons
            cancelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            cancelButton.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.4),
            cancelButton.heightAnchor.constraint(equalToConstant: 44),
            
            saveButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            saveButton.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.4),
            saveButton.heightAnchor.constraint(equalToConstant: 44),
        ])
    }
}