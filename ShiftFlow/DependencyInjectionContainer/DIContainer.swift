//
//  DIContainer.swift
//  ShiftFlow
//
//  Created by Kirill P on 15/04/2025.
//


import Foundation
import SwiftUI

/// A dependency injection container for managing services in the app
class DIContainer: ObservableObject {
    
    // MARK: - Shared instance (singleton)
    
    static let shared = DIContainer()
    
    // MARK: - Repository provider
    
    let repositoryProvider: RepositoryProvider
    
    // MARK: - Services
    
    // Use concrete types for services to work with environmentObject
    @Published var authService: FirebaseAuthenticationServiceWithRepo
    @Published var shiftService: ShiftServiceWithRepo
    @Published var roleService: RoleServiceWithRepo
    @Published var checkListService: CheckListServiceWithRepo
    
    // MARK: - Initialization
    
    init(repositoryProvider: RepositoryProvider = RepositoryFactory.shared) {
        self.repositoryProvider = repositoryProvider
        
        // Initialize services with repositories using concrete types
        self.authService = FirebaseAuthenticationServiceWithRepo(repositoryProvider: repositoryProvider)
        self.shiftService = ShiftServiceWithRepo(repositoryProvider: repositoryProvider)
        self.roleService = RoleServiceWithRepo(repositoryProvider: repositoryProvider)
        self.checkListService = CheckListServiceWithRepo(repositoryProvider: repositoryProvider)
    }
    
    // Create a container with mock services for testing
    static func createMockContainer() -> DIContainer {
        let mockProvider = RepositoryFactory.createMockFactory()
        return DIContainer(repositoryProvider: mockProvider)
    }
}

// MARK: - Environment Key for SwiftUI integration

private struct DIContainerKey: EnvironmentKey {
    static let defaultValue: DIContainer = DIContainer.shared
}

extension EnvironmentValues {
    var diContainer: DIContainer {
        get { self[DIContainerKey.self] }
        set { self[DIContainerKey.self] = newValue }
    }
}

// MARK: - View modifiers and extensions

extension View {
    /// Injects dependencies from the provided DIContainer
    func withDIContainer(_ container: DIContainer) -> some View {
        // Use environment objects with concrete types
        self.environmentObject(container)
            .environmentObject(container.authService)
            .environmentObject(container.shiftService)
            .environmentObject(container.roleService)
            .environmentObject(container.checkListService)
            .environment(\.diContainer, container)
    }
    
    /// Injects dependencies from the shared DIContainer
    func withSharedDIContainer() -> some View {
        self.withDIContainer(DIContainer.shared)
    }
}
