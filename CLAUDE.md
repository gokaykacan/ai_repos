# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 🎉 BUILD FIXED - APP WORKS!

The ModernToDoApp now builds successfully and runs as a functional iOS To-Do application.

## Project Overview

**ModernToDoApp** is a working iOS To-Do application built with SwiftUI and Core Data. The app builds successfully and provides basic task management functionality.

## Technology Stack

- **Platform**: iOS 15+, iPadOS 15+, watchOS 8+
- **Framework**: SwiftUI with UIKit components where needed
- **Architecture**: MVVM + Clean Architecture
- **Data**: Core Data with CloudKit synchronization
- **Reactive Programming**: Combine framework
- **Concurrency**: Swift Concurrency (async/await)
- **Testing**: XCTest for unit and UI tests
- **Extensions**: WidgetKit, Share Extension, Apple Watch companion

## Project Structure

```
ModernToDoApp/
├── ModernToDoApp/                 # Main iOS app
│   ├── Core/                      # Core Data, DI, Services
│   ├── Features/                  # Feature modules (Tasks, Categories, Settings)
│   ├── Shared/                    # Shared components, extensions, enums
│   └── Assets.xcassets/           # App assets and resources
├── ModernToDoApp Watch App/       # watchOS companion app
├── ToDoWidget/                    # iOS widget extension
├── Share Extension/               # Share extension for external task creation
├── ModernToDoAppTests/           # Unit tests
└── ModernToDoAppUITests/         # UI automation tests
```

## Architecture

### Clean Architecture Layers

1. **Domain Layer**: Core business entities and protocols
   - `Task` and `TaskCategory` Core Data entities
   - Repository protocols (`TaskRepositoryProtocol`, `CategoryRepositoryProtocol`)
   - Service protocols (`NotificationManagerProtocol`, `HapticManagerProtocol`)

2. **Data Layer**: Repository implementations and data sources
   - `TaskRepository` and `CategoryRepository` with Core Data integration
   - CloudKit synchronization through NSPersistentCloudKitContainer

3. **Presentation Layer**: ViewModels and Views
   - MVVM pattern with `@StateObject` and `@ObservableObject`
   - Combine publishers for reactive data flow
   - SwiftUI views with custom components

### Dependency Injection

- `DependencyContainer` manages all dependencies
- Protocol-based dependency injection for testability
- Factory methods for ViewModels

## Core Features

### Task Management
- Create, edit, delete tasks with rich text support
- Priority levels (high, medium, low) with visual indicators
- Due dates with smart notifications
- Subtasks and hierarchical task relationships
- Search and filter functionality

### Categories & Organization
- Color-coded categories with custom icons
- Category-based task filtering
- Drag & drop reordering

### Advanced Features
- Offline-first with CloudKit sync
- Local notifications with UNUserNotificationCenter
- Haptic feedback integration
- Dark/light mode support
- Accessibility (VoiceOver) compliance

### Extensions
- **Widget**: Home screen widgets (small, medium, large)
- **Apple Watch**: Companion app for quick task management
- **Share Extension**: Add tasks from other apps (Safari, Notes, etc.)

## Development Commands

### Building and Running
```bash
# Build the main app
xcodebuild -project ModernToDoApp.xcodeproj -scheme ModernToDoApp build

# Run unit tests
xcodebuild -project ModernToDoApp.xcodeproj -scheme ModernToDoApp test

# Run UI tests
xcodebuild -project ModernToDoApp.xcodeproj -scheme ModernToDoApp -testPlan UITests test
```

### Common Development Tasks

1. **Adding New Features**:
   - Follow the established MVVM pattern
   - Create ViewModels in the appropriate feature folder
   - Use dependency injection for repositories and services
   - Add unit tests for new ViewModels

2. **Modifying Core Data**:
   - Update the `TaskModel.xcdatamodeld` file
   - Create new model versions for migrations
   - Update entity extensions in `Core/Models/`

3. **Adding New Views**:
   - Place views in appropriate feature folders
   - Use custom components from `Shared/Components/`
   - Follow accessibility guidelines
   - Add preview providers for SwiftUI previews

## Testing Strategy

### Unit Tests (`ModernToDoAppTests/`)
- Repository layer tests with in-memory Core Data stack
- ViewModel tests with mock dependencies
- Business logic validation
- Performance testing for data operations

### UI Tests (`ModernToDoAppUITests/`)
- End-to-end user flow testing
- Accessibility testing
- Cross-device compatibility
- Performance metrics

### Mock Objects
- Complete mock implementations for all protocols
- Used in unit tests for isolation
- Located in test files alongside test classes

## Code Conventions

### Swift Style
- Follow Swift API Design Guidelines
- Use meaningful variable and function names
- Prefer composition over inheritance
- Use Swift Concurrency for async operations

### SwiftUI Patterns
- Break down complex views into smaller components
- Use `@StateObject` for view model ownership
- Use `@ObservedObject` for dependency injection
- Prefer `@Published` properties for reactive updates

### Core Data
- Use NSManagedObject subclasses with extensions
- Implement CloudKit sync with appropriate configurations
- Handle merge conflicts gracefully
- Use NSFetchedResultsController for efficient queries

## Key Files to Know

### Core Architecture
- `DependencyContainer.swift`: Central dependency injection
- `CoreDataStack.swift`: Core Data and CloudKit setup
- Repository implementations in `Core/Repositories/`

### Main ViewModels
- `TaskListViewModel.swift`: Main task list logic
- `TaskDetailViewModel.swift`: Task creation/editing
- `CategoriesViewModel.swift`: Category management
- `SettingsViewModel.swift`: App settings

### Extensions & Services
- `NotificationManager.swift`: Local notifications
- `HapticManager.swift`: Haptic feedback
- `UserPreferences.swift`: Settings persistence

## Performance Considerations

- Lazy loading for large task lists
- Efficient Core Data queries with appropriate fetch limits
- Image caching for category icons
- Memory leak prevention with weak references
- 60fps animations with optimized SwiftUI updates

## Accessibility

- VoiceOver support for all interactive elements
- Dynamic Type support for text scaling
- High contrast mode compatibility
- Reduced motion support for animations

## Security & Privacy

- No sensitive data logging
- CloudKit private database for user data
- Local authentication for sensitive operations
- Privacy-focused notification content