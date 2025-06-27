import XCTest

final class ModernToDoAppUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Basic Navigation Tests
    
    func testTabBarNavigation() throws {
        // Test that all tab bar items are accessible
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists)
        
        // Test Tasks tab
        let tasksTab = tabBar.buttons["Tasks"]
        XCTAssertTrue(tasksTab.exists)
        tasksTab.tap()
        
        // Test Categories tab
        let categoriesTab = tabBar.buttons["Categories"]
        XCTAssertTrue(categoriesTab.exists)
        categoriesTab.tap()
        
        // Test Settings tab
        let settingsTab = tabBar.buttons["Settings"]
        XCTAssertTrue(settingsTab.exists)
        settingsTab.tap()
        
        // Return to Tasks tab
        tasksTab.tap()
    }
    
    // MARK: - Task Creation Tests
    
    func testCreateNewTask() throws {
        // Navigate to add task screen
        let addButton = app.navigationBars.buttons["Add"]
        if addButton.exists {
            addButton.tap()
        } else {
            // If no tasks exist, tap the primary action button
            let addTaskButton = app.buttons["Add Task"]
            if addTaskButton.exists {
                addTaskButton.tap()
            }
        }
        
        // Fill in task details
        let titleField = app.textFields["Task title"]
        XCTAssertTrue(titleField.exists)
        titleField.tap()
        titleField.typeText("UI Test Task")
        
        // Set priority to high
        let prioritySegment = app.segmentedControls.firstMatch
        if prioritySegment.exists {
            prioritySegment.buttons["High"].tap()
        }
        
        // Add notes
        let notesField = app.textViews.firstMatch
        if notesField.exists {
            notesField.tap()
            notesField.typeText("This is a test task created by UI tests")
        }
        
        // Save the task
        let saveButton = app.navigationBars.buttons["Save"]
        XCTAssertTrue(saveButton.exists)
        saveButton.tap()
        
        // Verify we're back to the task list
        let navigationTitle = app.navigationBars["Tasks"]
        XCTAssertTrue(navigationTitle.waitForExistence(timeout: 2))
    }
    
    // MARK: - Task List Tests
    
    func testTaskListDisplaysCorrectly() throws {
        // Check if the main navigation title exists
        let navigationBar = app.navigationBars["Tasks"]
        XCTAssertTrue(navigationBar.exists)
        
        // Check for the add button
        let addButton = app.navigationBars.buttons.matching(identifier: "Add").firstMatch
        XCTAssertTrue(addButton.exists)
        
        // Check for the filter button
        let filterButton = app.navigationBars.buttons.matching(NSPredicate(format: "label CONTAINS 'line.3.horizontal.decrease.circle'")).firstMatch
        XCTAssertTrue(filterButton.exists)
    }
    
    func testTaskCompletion() throws {
        // First create a task if none exist
        createTaskIfNeeded()
        
        // Find the first task's completion button
        let taskRows = app.collectionViews.cells
        if taskRows.count > 0 {
            let firstTask = taskRows.firstMatch
            let completionButton = firstTask.buttons.matching(NSPredicate(format: "label CONTAINS 'circle'")).firstMatch
            
            if completionButton.exists {
                completionButton.tap()
                
                // Verify the task state changed (this would depend on your UI implementation)
                // You might check for visual changes or state indicators
            }
        }
    }
    
    // MARK: - Search Tests
    
    func testSearchFunctionality() throws {
        // Create a task first if needed
        createTaskIfNeeded()
        
        // Access the search field
        let searchField = app.searchFields["Search tasks..."]
        if searchField.exists {
            searchField.tap()
            searchField.typeText("test")
            
            // Wait for search results
            sleep(1)
            
            // Clear search
            if searchField.buttons["Clear text"].exists {
                searchField.buttons["Clear text"].tap()
            }
        }
    }
    
    // MARK: - Categories Tests
    
    func testCategoriesTab() throws {
        // Navigate to categories tab
        let categoriesTab = app.tabBars.buttons["Categories"]
        categoriesTab.tap()
        
        // Check navigation title
        let navigationBar = app.navigationBars["Categories"]
        XCTAssertTrue(navigationBar.exists)
        
        // Check for add button
        let addButton = app.navigationBars.buttons["Add"]
        XCTAssertTrue(addButton.exists)
    }
    
    func testCreateCategory() throws {
        // Navigate to categories
        app.tabBars.buttons["Categories"].tap()
        
        // Tap add button
        let addButton = app.navigationBars.buttons["Add"]
        if addButton.exists {
            addButton.tap()
        } else {
            // If no categories exist, tap the primary action button
            let addCategoryButton = app.buttons["Add Category"]
            if addCategoryButton.exists {
                addCategoryButton.tap()
            }
        }
        
        // Fill in category name
        let nameField = app.textFields["Category name"]
        if nameField.exists {
            nameField.tap()
            nameField.typeText("UI Test Category")
        }
        
        // Select a color (tap one of the color circles)
        let colorButtons = app.buttons.matching(NSPredicate(format: "identifier LIKE 'color_*'"))
        if colorButtons.count > 0 {
            colorButtons.firstMatch.tap()
        }
        
        // Save the category
        let saveButton = app.navigationBars.buttons["Save"]
        if saveButton.exists {
            saveButton.tap()
        }
    }
    
    // MARK: - Settings Tests
    
    func testSettingsTab() throws {
        // Navigate to settings tab
        let settingsTab = app.tabBars.buttons["Settings"]
        settingsTab.tap()
        
        // Check navigation title
        let navigationBar = app.navigationBars["Settings"]
        XCTAssertTrue(navigationBar.exists)
        
        // Test some toggle switches
        let darkModeToggle = app.switches["Dark Mode"]
        if darkModeToggle.exists {
            let initialValue = darkModeToggle.value as? String
            darkModeToggle.tap()
            
            // Verify the toggle changed
            let newValue = darkModeToggle.value as? String
            XCTAssertNotEqual(initialValue, newValue)
        }
        
        let hapticToggle = app.switches["Haptic Feedback"]
        if hapticToggle.exists {
            hapticToggle.tap()
        }
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibilityLabels() throws {
        // Check that main UI elements have proper accessibility labels
        let tasksTab = app.tabBars.buttons["Tasks"]
        XCTAssertTrue(tasksTab.isHittable)
        
        let categoriesTab = app.tabBars.buttons["Categories"]
        XCTAssertTrue(categoriesTab.isHittable)
        
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.isHittable)
        
        // Test navigation buttons
        let addButton = app.navigationBars.buttons["Add"]
        if addButton.exists {
            XCTAssertTrue(addButton.isHittable)
        }
    }
    
    // MARK: - Performance Tests
    
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTaskIfNeeded() {
        // Check if tasks exist, if not create one
        let taskList = app.collectionViews.firstMatch
        
        if !taskList.cells.firstMatch.exists {
            // No tasks exist, create one
            let addTaskButton = app.buttons["Add Task"]
            if addTaskButton.exists {
                addTaskButton.tap()
                
                // Fill basic info
                let titleField = app.textFields["Task title"]
                if titleField.exists {
                    titleField.tap()
                    titleField.typeText("Test Task")
                    
                    // Save
                    let saveButton = app.navigationBars.buttons["Save"]
                    saveButton.tap()
                }
            }
        }
    }
}