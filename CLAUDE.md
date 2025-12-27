# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 🎉 PROJECT STATUS: FULLY FUNCTIONAL iOS TO-DO APP

ModernToDoApp is a production-ready iOS To-Do application built with SwiftUI and Core Data, featuring comprehensive task management, real-time notifications, and full Turkish-English localization.

## Quick Start

```bash
# Open in Xcode
open ModernToDoApp.xcodeproj

# Build for simulator
xcodebuild -project ModernToDoApp.xcodeproj -scheme ModernToDoApp -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run all tests
xcodebuild -project ModernToDoApp.xcodeproj -scheme ModernToDoApp test

# Run unit tests only
xcodebuild -project ModernToDoApp.xcodeproj -scheme ModernToDoApp test -only-testing:ModernToDoAppTests

# Run UI tests only
xcodebuild -project ModernToDoApp.xcodeproj -scheme ModernToDoApp test -only-testing:ModernToDoAppUITests
```

## Technology Stack

- **Platform**: iOS 15+, watchOS companion app
- **Framework**: SwiftUI for UI, Core Data for persistence
- **Architecture**: Direct Core Data integration (no MVVM/repositories in active code)
- **Data**: Core Data with CloudKit sync via NSPersistentCloudKitContainer
- **Notifications**: UNUserNotificationCenter with interactive actions
- **Localization**: Complete Turkish-English support via .lproj bundles
- **Testing**: XCTest for unit and UI tests

## Project Structure

```
ModernToDoApp/
├── ModernToDoApp/                 # Main iOS app
│   ├── Core/
│   │   ├── TaskModel.xcdatamodeld # Core Data model (Task, TaskCategory)
│   │   ├── PersistenceController.swift # CloudKit-enabled stack
│   │   ├── CoreDataStack.swift    # Main Core Data stack (used by app)
│   │   ├── Models/                # Entity extensions (Task+Extensions, TaskCategory+Extensions)
│   │   └── Services/              # NotificationManager, LanguageManager, Performance services
│   ├── Features/                  # Main UI (ContentView, TaskListView, etc.)
│   ├── Views/                     # Detail views (TaskDetailView, CategoryDetailView)
│   ├── Enums/                     # TaskPriority, RecurrenceType
│   ├── Extensions/                # Color+Extensions (hex support, keyboard dismissal)
│   ├── en.lproj/                  # English localization
│   ├── tr.lproj/                  # Turkish localization
│   └── ModernToDoAppApp.swift     # App entry with AppDelegate
├── ModernToDoApp Watch App/       # watchOS companion (placeholder)
├── ToDoWidget/                    # iOS widget extension (placeholder)
├── Share Extension/               # Share extension (placeholder)
├── ModernToDoAppTests/           # Unit tests
├── ModernToDoAppUITests/         # UI automation tests
└── Unused/                       # Archived MVVM implementation (not used)
```

## Architecture Overview

### Core Data Integration (Direct Pattern - No Repositories)

- **Entities**: `Task` and `TaskCategory` with CloudKit sync enabled
- **Stacks**:
  - `CoreDataStack.shared` - Main app stack (used everywhere)
  - `PersistenceController.shared` - CloudKit-enabled stack (available but not primary)
- **Entity Extensions**: Located in `Core/Models/`
  - `Task+Extensions.swift` - Computed properties (isOverdue, isDueToday, priorityEnum, etc.)
  - `TaskCategory+Extensions.swift` - Category helpers

### SwiftUI Pattern

- **Views use `@FetchRequest`** directly - No repository layer
- **State Management**: `@AppStorage` for persistence, `@State` for local state
- **Navigation**: Tab-based with sheet presentations
- **Custom Components**:
  - `ModernCheckboxView` - Animated checkbox with haptic feedback
  - `CompactPriorityIndicatorView` - Priority badges
  - `UltraMinimalistSearchBar` - Search UI component

### Key Services

**NotificationManager** (`Core/Services/NotificationManager.swift`):
- Singleton pattern: `NotificationManager.shared`
- Must call `.initialize()` on app launch (done in `ModernToDoAppApp.init()`)
- Uses `UNTimeIntervalNotificationTrigger` for reliability
- Badge count = overdue tasks only (past due date)
- 30-second timer for real-time badge updates
- Convenience methods: `handleTaskCompletion()`, `handleTaskDeletion()`, `handleTaskStateChange()`

**LanguageManager** (`Core/Services/LanguageManager.swift`):
- Handles Turkish-English switching
- Requires app restart for full effect

## Core Features

### Task Management
- Create, edit, delete with title, notes, priority (high/medium/low)
- Due dates with notifications
- Subtasks and hierarchical relationships (parent/child tasks)
- Task completion with automatic parent task updates
- Search and category filtering
- Swipe actions: Complete (leading), Edit/Delete/Postpone (trailing)
- **Real-time section updates**: Tasks move between Overdue/Today/Tomorrow/Upcoming sections automatically via 30-second timer

### Categories
- Color-coded with custom SF Symbol icons
- Category filtering in task list
- Swipe actions on categories:
  - **Trailing**: Edit → Delete Completed → Delete All Tasks
  - **Leading**: Delete Category
- Task count display with progress indicators

### Notifications
- Interactive actions: Complete, Postpone (1 hour), View
- Priority-based styling: 🔴 High (critical sound), 🟡 Medium, 🟢 Low
- Foreground presentation enabled
- Badge count shows overdue tasks only
- Auto-clear when app becomes active

### UI/UX
- Dark/light mode with persistence across launches
- Smart keyboard dismissal (tap outside text fields)
- Modern checkbox with animations (bounce, glow, rotation)
- Priority indicators on left side of task cards
- Haptic feedback throughout
- 60fps animations

## Code Patterns & Best Practices

### SwiftUI + Core Data
```swift
// Views use @FetchRequest directly
@FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Task.createdAt, ascending: false)])
private var tasks: FetchedResults<Task>

// Access managed object context
@Environment(\.managedObjectContext) private var viewContext

// Save changes
do {
    try viewContext.save()
} catch {
    print("Error: \(error)")
}
```

### Notification Scheduling
```swift
// Always check before scheduling
if notificationsEnabled && task.dueDate != nil {
    NotificationManager.shared.scheduleNotification(for: task)
}

// Cancel when task completed or deleted
NotificationManager.shared.cancelNotification(for: task)

// Update badge after changes
NotificationManager.shared.handleTaskCompletion()
```

### Localization
```swift
// Use .localized extension
Text("task.title".localized)

// With parameters
Text("alert.delete_task_message".localized(with: task.title ?? ""))
```

### Sheet Management (Important Pattern)
```swift
// Use unified enum for multiple sheet types (prevents SwiftUI gesture conflicts)
enum TaskSheetType: Identifiable {
    case detail(Task)
    case edit(Task)
    case postpone(Task, Date)

    var id: String { /* unique id */ }
}

@State private var activeSheet: TaskSheetType?

// Single sheet modifier with switch
.sheet(item: $activeSheet) { sheetType in
    switch sheetType {
    case .detail(let task): SimpleTaskDetailView(task: task)
    case .edit(let task): TaskDetailView(task: task)
    case .postpone(let task, let date): PostponeTaskView(...)
    }
}
```

### Real-time Date Updates
```swift
// Use refresh trigger + timer for time-based UI updates
@State private var refreshTrigger = Date()

// Timer updates every 30 seconds
Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
    DispatchQueue.main.async {
        self.refreshTrigger = Date()
    }
}

// Use refreshTrigger in computed properties to force re-evaluation
let now = refreshTrigger // Forces SwiftUI to recalculate when changed
```

## Important Implementation Details

### Dark Mode Persistence
- On first launch, detects system appearance
- User preference stored in `@AppStorage("isDarkMode")`
- Applied on app startup via `.onAppear` in ContentView
- Reapplied when app returns from background

### Badge Count Logic
- Badge = overdue tasks only (due date < now AND not completed)
- Updated every 30 seconds by timer
- Updated immediately on task changes
- Cleared when app becomes active

### Task Completion Flow
1. User swipes left or taps checkbox
2. Task marked completed with `handleTaskCompletion(in: context)`
3. Notification cancelled via `NotificationManager.shared.cancelNotification()`
4. Context saved
5. Badge updated via `NotificationManager.shared.handleTaskCompletion()`
6. UI automatically updates (SwiftUI @FetchRequest reactivity)

### Gesture Isolation (Checkboxes vs Navigation)
```swift
// Checkbox with isolated tap area
ModernCheckboxView(isCompleted: task.isCompleted) {
    toggleTaskCompletion()
}
.zIndex(1) // Priority over content area

// Content area with separate tap gesture
VStack { /* task content */ }
.contentShape(Rectangle())
.onTapGesture { /* navigate to detail */ }
```

## Testing

Run tests before committing:
```bash
# All tests
xcodebuild -project ModernToDoApp.xcodeproj -scheme ModernToDoApp test

# Specific test class
xcodebuild -project ModernToDoApp.xcodeproj -scheme ModernToDoApp test -only-testing:ModernToDoAppTests/ModernToDoAppTests
```

Test coverage includes:
- Core Data operations (in-memory stores)
- Entity relationships (Task ↔ Category, parent/child tasks)
- Repository pattern tests (in `ModernToDoAppTests/` even though app doesn't use repositories)
- Performance tests for task creation
- UI automation tests

## Performance Optimizations Available

The project includes advanced performance services (not currently used by main app):
- `PerformanceOptimizedCoreDataStack.swift` - Batch operations, background contexts
- `PaginatedTaskRepository.swift` - Lazy loading with caching
- `PerformanceAnalytics.swift` - FPS monitoring, memory tracking
- `AdvancedOptimizations.swift` - Network/battery optimizations
- `OptimizedTaskListView.swift` - Virtualized lists

These are available for future use if performance becomes an issue with large datasets (1000+ tasks).

## Common Tasks

### Adding New Localized String
1. Add to `en.lproj/Localizable.strings`
2. Add to `tr.lproj/Localizable.strings`
3. Use in code: `"your.key".localized`

### Adding New Task Property
1. Update `TaskModel.xcdatamodeld` Core Data model
2. Add computed property in `Task+Extensions.swift` if needed
3. Update UI components to display/edit new property
4. Update notification content if relevant

### Modifying Notification Behavior
1. Edit `NotificationManager.swift`
2. Test with tasks due 1-2 minutes in future
3. Check badge updates via `getCurrentBadgeCount()`
4. Verify notification actions in AppDelegate

### Adding New UI Component
1. Create in `Features/` directory
2. Follow existing patterns (SwiftUI, @FetchRequest if needed)
3. Add localization for text
4. Include haptic feedback for interactions
5. Test dark/light mode appearance

## Known Limitations

- Widget extension is placeholder (not implemented)
- Apple Watch app is placeholder (not implemented)
- Share Extension is placeholder (not implemented)
- CloudKit sync enabled but not extensively tested
- Performance optimizations exist but not integrated into main app

## Debugging Tips

**Notifications not working:**
- Check `NotificationManager.shared.checkNotificationSettings()` return value
- Verify due date is in future
- Check Xcode console for "✅" or "❌" log messages
- Ensure `NotificationManager.shared.initialize()` called in app init

**Badge count wrong:**
- Check `getCurrentBadgeCount()` logic in NotificationManager
- Verify badge update timer is running
- Check Core Data fetch predicate for overdue tasks

**Tasks not moving to Overdue section:**
- Verify 30-second timer is running in TaskListView
- Check `refreshTrigger` being updated
- Ensure `groupedTasks` uses `refreshTrigger` not static `Date()`

**Dark mode not persisting:**
- Check `applyStoredDarkModePreference()` called in ContentView.onAppear
- Verify `@AppStorage("isDarkMode")` binding
- Check scene phase change handler

## Version History

- **v2.2** - Notification system overhaul with real-time badges
- **v2.1** - App icons, enhanced notifications, Turkish localization
- **v2.0** - Modern UI overhaul with checkbox system
- **v1.0** - Initial release

---

**For detailed change history, see README.md or git log**
