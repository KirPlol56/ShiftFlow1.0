//
//  RepositoryFactoryTests.swift
//  ShiftFlowTests
//
//  Created by Kirill P on 24/06/2025.
//

//
//  RepositoryFactoryTests.swift
//  ShiftFlowTests
//
//  Created by Kirill P on 24/06/2025.
//

import XCTest
@testable import ShiftFlow

@MainActor
final class RepositoryFactoryTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var repositoryFactory: RepositoryFactory!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        repositoryFactory = RepositoryFactory.shared
    }
    
    override func tearDown() {
        repositoryFactory = nil
        super.tearDown()
    }
    
    // MARK: - Dependency Injection Tests
    
    func testRepositoryFactoryDependencyInjection() {
        // Test that all repositories are properly injected and accessible
        let userRepo = repositoryFactory.userRepository()
        let shiftRepo = repositoryFactory.shiftRepository()
        let roleRepo = repositoryFactory.roleRepository()
        let checkListRepo = repositoryFactory.checkListRepository()
        
        XCTAssertNotNil(userRepo, "User repository should be injected")
        XCTAssertNotNil(shiftRepo, "Shift repository should be injected")
        XCTAssertNotNil(roleRepo, "Role repository should be injected")
        XCTAssertNotNil(checkListRepo, "CheckList repository should be injected")
        
        // Test that repositories are the correct types
        XCTAssertTrue(userRepo is FirestoreUserRepository, "User repository should be FirestoreUserRepository")
        XCTAssertTrue(shiftRepo is FirestoreShiftRepository, "Shift repository should be FirestoreShiftRepository")
        XCTAssertTrue(roleRepo is FirestoreRoleRepository, "Role repository should be FirestoreRoleRepository")
        XCTAssertTrue(checkListRepo is FirestoreCheckListRepository, "CheckList repository should be FirestoreCheckListRepository")
    }
    
    func testRepositoryFactorySingleton() {
        // Test that the factory maintains singleton behavior
        let factory1 = RepositoryFactory.shared
        let factory2 = RepositoryFactory.shared
        
        XCTAssertTrue(factory1 === factory2, "Factory should be a singleton")
    }
    
    func testRepositoryInstanceReuse() {
        // Test that repositories are reused (lazy initialization)
        let userRepo1 = repositoryFactory.userRepository()
        let userRepo2 = repositoryFactory.userRepository()
        
        XCTAssertTrue(userRepo1 === userRepo2, "User repository instances should be reused")
        
        let shiftRepo1 = repositoryFactory.shiftRepository()
        let shiftRepo2 = repositoryFactory.shiftRepository()
        
        XCTAssertTrue(shiftRepo1 === shiftRepo2, "Shift repository instances should be reused")
    }
    
    func testMockFactoryCreation() {
        // Test that mock factory can be created with custom repositories
        let mockUserRepo = MockUserRepository()
        let mockShiftRepo = MockShiftRepository()
        let mockRoleRepo = MockRoleRepository()
        let mockCheckListRepo = MockCheckListRepository()
        
        let mockFactory = RepositoryFactory.createMockFactory(
            userRepository: mockUserRepo,
            shiftRepository: mockShiftRepo,
            roleRepository: mockRoleRepo,
            checkListRepository: mockCheckListRepo
        )
        
        XCTAssertTrue(mockFactory.userRepository() === mockUserRepo, "Mock factory should return provided user repository")
        XCTAssertTrue(mockFactory.shiftRepository() === mockShiftRepo, "Mock factory should return provided shift repository")
        XCTAssertTrue(mockFactory.roleRepository() === mockRoleRepo, "Mock factory should return provided role repository")
        XCTAssertTrue(mockFactory.checkListRepository() === mockCheckListRepo, "Mock factory should return provided checklist repository")
    }
    
    func testDIContainerIntegration() {
        // Test that DIContainer properly uses the repository factory
        let diContainer = DIContainer.shared
        
        XCTAssertNotNil(diContainer.repositoryProvider, "DI container should have repository provider")
        XCTAssertTrue(diContainer.repositoryProvider is RepositoryFactory, "Repository provider should be RepositoryFactory")
        
        // Test mock container creation
        let mockContainer = DIContainer.createMockContainer()
        XCTAssertNotNil(mockContainer.repositoryProvider, "Mock container should have repository provider")
    }
}

// MARK: - Mock Repositories for Testing

class MockUserRepository: UserRepository {
    typealias Entity = User
    let entityName = "users"
    
    var users: [User] = []
    var shouldFailNextOperation = false
    var lastCalledMethod: String?
    
    func get(byId id: String) async throws -> User {
        lastCalledMethod = "get(byId:)"
        if shouldFailNextOperation {
            throw MockRepositoryError.simulatedFailure
        }
        guard let user = users.first(where: { $0.uid == id }) else {
            throw MockRepositoryError.notFound
        }
        return user
    }
    
    func getAll() async throws -> [User] {
        lastCalledMethod = "getAll"
        if shouldFailNextOperation {
            throw MockRepositoryError.simulatedFailure
        }
        return users
    }
    
    func create(_ entity: User) async throws -> User {
        lastCalledMethod = "create"
        if shouldFailNextOperation {
            throw MockRepositoryError.simulatedFailure
        }
        users.append(entity)
        return entity
    }
    
    func update(_ entity: User) async throws -> User {
        lastCalledMethod = "update"
        if shouldFailNextOperation {
            throw MockRepositoryError.simulatedFailure
        }
        if let index = users.firstIndex(where: { $0.uid == entity.uid }) {
            users[index] = entity
        }
        return entity
    }
    
    func delete(id: String) async throws {
        lastCalledMethod = "delete"
        if shouldFailNextOperation {
            throw MockRepositoryError.simulatedFailure
        }
        users.removeAll { $0.uid == id }
    }
    
    func getTeamMembers(companyId: String) async throws -> [User] {
        lastCalledMethod = "getTeamMembers"
        if shouldFailNextOperation {
            throw MockRepositoryError.simulatedFailure
        }
        return users.filter { $0.companyId == companyId }
    }
    
    // Minimal implementations for protocol compliance
    func listen(forId id: String, completion: @escaping (Result<User?, Error>) -> Void) -> ListenerRegistration {
        return MockListenerRegistration()
    }
    
    func stopListening(_ registration: ListenerRegistration) {}
}

class MockShiftRepository: ShiftRepository {
    typealias Entity = Shift
    let entityName = "shifts"
    
    var shifts: [Shift] = []
    var shouldFailNextOperation = false
    var lastCalledMethod: String?
    
    func get(byId id: String) async throws -> Shift {
        lastCalledMethod = "get(byId:)"
        if shouldFailNextOperation {
            throw MockRepositoryError.simulatedFailure
        }
        guard let shift = shifts.first(where: { $0.id == id }) else {
            throw MockRepositoryError.notFound
        }
        return shift
    }
    
    func getAll() async throws -> [Shift] {
        lastCalledMethod = "getAll"
        if shouldFailNextOperation {
            throw MockRepositoryError.simulatedFailure
        }
        return shifts
    }
    
    func create(_ entity: Shift) async throws -> Shift {
        lastCalledMethod = "create"
        if shouldFailNextOperation {
            throw MockRepositoryError.simulatedFailure
        }
        shifts.append(entity)
        return entity
    }
    
    func update(_ entity: Shift) async throws -> Shift {
        lastCalledMethod = "update"
        if shouldFailNextOperation {
            throw MockRepositoryError.simulatedFailure
        }
        if let index = shifts.firstIndex(where: { $0.id == entity.id }) {
            shifts[index] = entity
        }
        return entity
    }
    
    func delete(id: String) async throws {
        lastCalledMethod = "delete"
        if shouldFailNextOperation {
            throw MockRepositoryError.simulatedFailure
        }
        shifts.removeAll { $0.id == id }
    }
    
    func getShiftsForCompany(companyId: String) async throws -> [Shift] {
        lastCalledMethod = "getShiftsForCompany"
        if shouldFailNextOperation {
            throw MockRepositoryError.simulatedFailure
        }
        return shifts.filter { $0.companyId == companyId }
    }
    
    func query(filter: ShiftQueryFilter) async throws -> [Shift] {
        lastCalledMethod = "query"
        if shouldFailNextOperation {
            throw MockRepositoryError.simulatedFailure
        }
        return shifts // Simplified for testing
    }
    
    // Minimal implementations for protocol compliance
    func listen(forId id: String, completion: @escaping (Result<Shift?, Error>) -> Void) -> ListenerRegistration {
        return MockListenerRegistration()
    }
    
    func listenAll(completion: @escaping (Result<[Shift], Error>) -> Void) -> ListenerRegistration {
        return MockListenerRegistration()
    }
    
    func stopListening(_ registration: ListenerRegistration) {}
}

class MockRoleRepository: RoleRepository {
    typealias Entity = Role
    let entityName = "roles"
    
    var roles: [Role] = []
    var shouldFailNextOperation = false
    var lastCalledMethod: String?
    
    func get(byId id: String) async throws -> Role {
        lastCalledMethod = "get(byId:)"
        if shouldFailNextOperation {
            throw MockRepositoryError.simulatedFailure
        }
        guard let role = roles.first(where: { $0.id == id }) else {
            throw MockRepositoryError.notFound
        }
        return role
    }
    
    func getAll() async throws -> [Role] {
        lastCalledMethod = "getAll"
        if shouldFailNextOperation {
            throw MockRepositoryError.simulatedFailure
        }
        return roles
    }
    
    func create(_ entity: Role) async throws -> Role {
        lastCalledMethod = "create"
        if shouldFailNextOperation {
            throw MockRepositoryError.simulatedFailure
        }
        roles.append(entity)
        return entity
    }
    
    func update(_ entity: Role) async throws -> Role {
        lastCalledMethod = "update"
        if shouldFailNextOperation {
            throw MockRepositoryError.simulatedFailure
        }
        if let index = roles.firstIndex(where: { $0.id == entity.id }) {
            roles[index] = entity
        }
        return entity
    }
    
    func delete(id: String) async throws {
        lastCalledMethod = "delete"
        if shouldFailNextOperation {
            throw MockRepositoryError.simulatedFailure
        }
        roles.removeAll { $0.id == id }
    }
    
    func getRolesForCompany(companyId: String) async throws -> [Role] {
        lastCalledMethod = "getRolesForCompany"
        if shouldFailNextOperation {
            throw MockRepositoryError.simulatedFailure
        }
        return roles.filter { $0.companyId == companyId }
    }
    
    func getAllStandardRoles() async throws -> [Role] {
        lastCalledMethod = "getAllStandardRoles"
        if shouldFailNextOperation {
            throw MockRepositoryError.simulatedFailure
        }
        return roles.filter { $0.isStandard }
    }
}

class MockCheckListRepository: CheckListRepository {
    typealias Entity = CheckList
    let entityName = "checklists"
    
    var checkLists: [CheckList] = []
    var shouldFailNextOperation = false
    var lastCalledMethod: String?
    
    func get(byId id: String) async throws -> CheckList {
        lastCalledMethod = "get(byId:)"
        if shouldFailNextOperation {
            throw MockRepositoryError.simulatedFailure
        }
        guard let checkList = checkLists.first(where: { $0.id == id }) else {
            throw MockRepositoryError.notFound
        }
        return checkList
    }
    
    func getAll() async throws -> [CheckList] {
        lastCalledMethod = "getAll"
        if shouldFailNextOperation {
            throw MockRepositoryError.simulatedFailure
        }
        return checkLists
    }
    
    func create(_ entity: CheckList) async throws -> CheckList {
        lastCalledMethod = "create"
        if shouldFailNextOperation {
            throw MockRepositoryError.simulatedFailure
        }
        checkLists.append(entity)
        return entity
    }
    
    func update(_ entity: CheckList) async throws -> CheckList {
        lastCalledMethod = "update"
        if shouldFailNextOperation {
            throw MockRepositoryError.simulatedFailure
        }
        if let index = checkLists.firstIndex(where: { $0.id == entity.id }) {
            checkLists[index] = entity
        }
        return entity
    }
    
    func delete(id: String) async throws {
        lastCalledMethod = "delete"
        if shouldFailNextOperation {
            throw MockRepositoryError.simulatedFailure
        }
        checkLists.removeAll { $0.id == id }
    }
}

// MARK: - Mock Support Classes

class MockListenerRegistration: ListenerRegistration {
    var isRemoved = false
    
    func remove() {
        isRemoved = true
    }
}

enum MockRepositoryError: Error, LocalizedError {
    case simulatedFailure
    case notFound
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .simulatedFailure:
            return "Simulated repository failure"
        case .notFound:
            return "Entity not found"
        case .invalidData:
            return "Invalid data provided"
        }
    }
}
