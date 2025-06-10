
# Repository Pattern Implementation Guide

## Introduction

This document outlines the implementation of the Repository Pattern in the ShiftFlow iOS app. The Repository Pattern is a design pattern that abstracts the data access logic from the rest of the application, making the code more maintainable, testable, and flexible.

## Architecture Overview

Our implementation follows these key principles:

1. **Separation of Concerns**: Data access logic is separated from business logic and UI
2. **Protocol-Oriented Design**: All repositories implement protocols that define their capabilities
3. **Dependency Injection**: Services depend on repository interfaces, not concrete implementations
4. **Swift Concurrency**: Repositories use async/await for better readability and performance
5. **Thread Safety**: Actors are used to ensure thread safety in repositories

## Repository Layer Structure

### Core Protocols

- `Repository`: Base protocol defining the entity type
- `ReadableRepository`: Protocol for read operations
- `WritableRepository`: Protocol for write operations
- `CRUDRepository`: Combined protocol for entities supporting all operations
- `ListenableRepository`: Protocol for repositories that can listen to real-time updates
- `PaginatedRepository`: Protocol for repositories supporting pagination
- `QueryableRepository`: Protocol for repositories that can be queried with filters

### Domain-Specific Repositories

- `UserRepository`: Manages user data
- `ShiftRepository`: Manages shift data
- `RoleRepository`: Manages role data
- `CheckListRepository`: Manages checklist data

### Repository Factory

The `RepositoryFactory` provides access to repositories and follows the Factory pattern:

- `RepositoryFactory.shared`: Singleton instance for production use
- `RepositoryFactory.createMockFactory()`: Creates mock repositories for testing

## How to Use Repositories

### Directly Using Repositories

```swift
let userRepository = RepositoryFactory.shared.userRepository()

// Using async/await
Task {
    do {
        let users = try await userRepository.getAll()
        // Handle users
    } catch {
        // Handle error
    }
}
```

### Using Services with Repositories

For most cases, you should use the service layer instead of repositories directly:

```swift
let authService = FirebaseAuthenticationServiceWithRepo()

authService.fetchTeamMembers(companyId: "company-id") { result in
    switch result {
    case .success(let users):
        // Handle users
    case .failure(let error):
        // Handle error
    }
}
```

### Using the DI Container

The `DIContainer` provides a centralized way to access all services:

```swift
// In a SwiftUI view:
@EnvironmentObject var authService: FirebaseAuthenticationServiceWithRepo
@EnvironmentObject var shiftService: ShiftServiceWithRepo

// Or directly access the container:
@Environment(\.diContainer) var diContainer

// Then in your view:
var body: some View {
    Text("Current user: \(authService.currentUser?.name ?? "None")")
    // or
    Text("Shifts count: \(diContainer.shiftService.shifts.count)")
}
```

## Implementing New Repositories

To implement a new repository:

1. Define a protocol extending `Repository` and any other needed protocols
2. Create a concrete implementation using Firestore or another data source
3. Add a mock implementation for testing
4. Add the repository to the `RepositoryFactory`
5. Create or update the corresponding service to use the repository

Example:

```swift
// 1. Define protocol
protocol ProductRepository: CRUDRepository where Model == Product, ID == String {
    func getProductsForCategory(categoryId: String) async throws -> [Product]
}

// 2. Create implementation
actor FirestoreProductRepository: ProductRepository {
    // Implementation details...
}

// 3. Create mock
class MockProductRepository: ProductRepository {
    // Mock implementation...
}

// 4. Add to factory
extension RepositoryFactory {
    func productRepository() -> any ProductRepository {
        return _productRepository
    }
}

// 5. Create service
class ProductService {
    private let productRepository: any ProductRepository
    
    init(repositoryProvider: RepositoryProvider = RepositoryFactory.shared) {
        self.productRepository = repositoryProvider.productRepository()
    }
    
    // Service methods...
}
```

## Testing with Repositories

The repository pattern makes testing easier by allowing you to inject mock repositories:

```swift
// Setup test repositories
let mockUserRepository = MockUserRepository()
let mockProvider = RepositoryFactory.createMockFactory(
    userRepository: mockUserRepository
)

// Create service with mock repositories
let authService = FirebaseAuthenticationServiceWithRepo(repositoryProvider: mockProvider)

// Test the service
func testFetchTeamMembers() {
    // Arrange
    let testUser = User(/* ... */)
    mockUserRepository.users = [testUser]
    
    // Act & Assert
    authService.fetchTeamMembers(companyId: "test-id") { result in
        switch result {
        case .success(let users):
            XCTAssertEqual(users.count, 1)
            XCTAssertEqual(users[0].uid, testUser.uid)
        case .failure:
            XCTFail("Should not fail")
        }
    }
}
```

## Error Handling

Repositories use the `RepositoryError` enum for consistent error handling:

```swift
enum RepositoryError: Error, LocalizedError {
    case documentNotFound
    case decodingFailed
    case encodingFailed
    case networkError(Error)
    case permissionDenied
    case unexpectedError(Error?)
    case invalidData
    case operationFailed(String)
}
```

Handle these errors appropriately in your services and UI.

## Threading Model

- All Firestore repositories are implemented as actors to ensure thread safety
- Repository methods are async and should be called from a Task or other async context
- Services handle dispatching results to the main thread for UI updates

## Repository vs. Service Layer

- **Repositories**: Handle data access, CRUD operations, and persistence
- **Services**: Handle business logic, coordinate between repositories, and provide a higher-level API

When deciding where to put code:
- If it involves data access or persistence → Repository
- If it involves business rules or coordination → Service
- If it involves UI state or presentation → ViewModel

## Migration Guide

To migrate existing code to use the repository pattern:

1. Identify the entity being managed (User, Shift, etc.)
2. Use the corresponding repository via the service layer
3. Replace direct Firestore calls with service method calls
4. Update UI components to use the new services via the DIContainer

Example migration:

```swift
// Before:
db.collection("users").document(userId).getDocument { document, error in
    // Handle document
}

// After:
authService.fetchTeamMembers(companyId: companyId) { result in
    // Handle result
}
```

## Best Practices

1. **Don't mix patterns**: Avoid using direct Firestore calls alongside repositories
2. **Use appropriate protocols**: Only include the protocols your repository needs
3. **Handle errors consistently**: Map domain-specific errors to user-friendly messages
4. **Test with mocks**: Use mock repositories for unit testing
5. **Use async/await**: Prefer async/await over completion handlers where possible
6. **Add pagination**: For collections that might grow large, implement pagination
7. **Document public APIs**: Add clear documentation to repository protocols

## Future Improvements

Potential improvements to the repository implementation:

1. **Caching Layer**: Add a caching layer for frequently accessed data
2. **Offline Support**: Enhanced offline capabilities using Firestore persistence
3. **Synchronization**: Better handling of conflicts during synchronization
4. **Performance Monitoring**: Track repository performance metrics
5. **Query Building**: More sophisticated query building API
6. **Reactive Repositories**: Extended Combine integration for reactive programming
