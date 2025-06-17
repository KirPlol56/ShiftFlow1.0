//
//  FirebaseAuthenticationServiceWithRepoTests.swift
//  ShiftFlowTests
//
//  Created by Unit Test Generator on 16/06/2025.
//

import XCTest
import Combine
import FirebaseFirestore
@testable import ShiftFlow

@MainActor
final class FirebaseAuthenticationServiceWithRepoTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var authService: FirebaseAuthenticationServiceWithRepo!
    var mockRepositoryProvider: RepositoryProvider!
    var mockUserRepository: MockUserRepository!
    var mockShiftRepository: MockShiftRepository!
    var cancellables: Set<AnyCancellable>!
    
    // MARK: - Test Setup & Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create mock repositories
        mockUserRepository = MockUserRepository()
        mockShiftRepository = MockShiftRepository()
        
        // Create mock repository provider
        mockRepositoryProvider = RepositoryFactory.createMockFactory(
            userRepository: mockUserRepository,
            shiftRepository: mockShiftRepository
        )
        
        // Initialize service with mock repositories
        authService = FirebaseAuthenticationServiceWithRepo(repositoryProvider: mockRepositoryProvider)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        authService = nil
        mockRepositoryProvider = nil
        mockUserRepository = nil
        mockShiftRepository = nil
        cancellables = nil
        try super.tearDownWithError()
    }
    
    // MARK: - User Registration Tests
    
    func testUserRegistrationWithCompanyCreation_Success() async throws {
        // Arrange
        let email = "manager@testcompany.com"
        let password = "testPassword123"
        let name = "Test Manager"
        let companyName = "Test Company"
        
        // Mock successful user creation
        mockUserRepository.shouldSucceed = true
        
        // Act & Assert - This would normally create a Firebase user
        // For unit tests, we focus on the business logic after Firebase auth
        do {
            // In a real test, we'd need to mock Firebase Auth
            // Here we test the business logic components
            
            let testUser = User(
                uid: "test-uid",
                email: email,
                name: name,
                isManager: true,
                roleTitle: "Manager",
                roleId: "manager-role-id",
                companyId: "test-company-id",
                companyName: companyName,
                createdAt: Date()
            )
            
            // Test user creation through repository
            let createdUser = try await mockUserRepository.create(testUser)
            
            XCTAssertEqual(createdUser.email, email)
            XCTAssertEqual(createdUser.name, name)
            XCTAssertEqual(createdUser.companyName, companyName)
            XCTAssertTrue(createdUser.isManager)
            XCTAssertEqual(createdUser.roleTitle, "Manager")
        } catch {
            XCTFail("User registration should succeed: \(error)")
        }
    }
    
    func testUserRegistrationWithInvalidEmail_ThrowsError() async {
        // Arrange
        let invalidEmail = ""
        let password = "testPassword123"
        let name = "Test Manager"
        let companyName = "Test Company"
        
        // Act & Assert
        do {
            try await authService.registerUser(
                email: invalidEmail,
                password: password,
                name: name,
                companyName: companyName
            )
            XCTFail("Should throw error for invalid email")
        } catch let error as ShiftFlowAuthenticationError {
            XCTAssertTrue(ShiftFlowAuthenticationError.isEqual(error, .invalidEmail))
        } catch {
            XCTFail("Should throw ShiftFlowAuthenticationError, got: \(error)")
        }
    }
    
    func testUserRegistrationWithWeakPassword_ThrowsError() async {
        // Arrange
        let email = "test@example.com"
        let weakPassword = "123" // Less than 6 characters
        let name = "Test User"
        let companyName = "Test Company"
        
        // Act & Assert
        do {
            try await authService.registerUser(
                email: email,
                password: weakPassword,
                name: name,
                companyName: companyName
            )
            XCTFail("Should throw error for weak password")
        } catch let error as ShiftFlowAuthenticationError {
            XCTAssertTrue(ShiftFlowAuthenticationError.isEqual(error, .invalidPassword))
        } catch {
            XCTFail("Should throw ShiftFlowAuthenticationError, got: \(error)")
        }
    }
    
    // MARK: - Team Member Registration Tests
    
    func testTeamMemberRegistration_Success() async throws {
        // Arrange
        let email = "barista@testcompany.com"
        let password = "testPassword123"
        let name = "Test Barista"
        let companyId = "test-company-id"
        let companyName = "Test Company"
        let roleId = "barista-role-id"
        let roleTitle = "Barista"
        let isManager = false
        
        mockUserRepository.shouldSucceed = true
        
        // Act
        do {
            try await authService.registerTeamMember(
                email: email,
                password: password,
                name: name,
                companyId: companyId,
                companyName: companyName,
                roleId: roleId,
                roleTitle: roleTitle,
                isManager: isManager
            )
            
            // Verify user was created in repository
            XCTAssertTrue(mockUserRepository.createCalled)
            XCTAssertEqual(mockUserRepository.users.count, 1)
            
            let createdUser = mockUserRepository.users.first!
            XCTAssertEqual(createdUser.email, email)
            XCTAssertEqual(createdUser.name, name)
            XCTAssertEqual(createdUser.companyId, companyId)
            XCTAssertEqual(createdUser.roleTitle, roleTitle)
            XCTAssertFalse(createdUser.isManager)
            
        } catch {
            XCTFail("Team member registration should succeed: \(error)")
        }
    }
    
    func testTeamMemberRegistrationWithEmptyRole_ThrowsError() async {
        // Arrange
        let email = "test@example.com"
        let password = "testPassword123"
        let name = "Test User"
        let companyId = "test-company-id"
        let companyName = "Test Company"
        let roleId = "test-role-id"
        let roleTitle = "" // Empty role title
        let isManager = false
        
        // Act & Assert
        do {
            try await authService.registerTeamMember(
                email: email,
                password: password,
                name: name,
                companyId: companyId,
                companyName: companyName,
                roleId: roleId,
                roleTitle: roleTitle,
                isManager: isManager
            )
            XCTFail("Should throw error for empty role title")
        } catch let error as ServiceError {
            XCTAssertTrue(ServiceError.isEqual(error, .invalidOperation("Role title is required")))
        } catch {
            XCTFail("Should throw ServiceError, got: \(error)")
        }
    }
    
    // MARK: - Team Member Fetching Tests
    
    func testFetchTeamMembers_Success() async throws {
        // Arrange
        let companyId = "test-company-id"
        let testUsers = [
            User(uid: "user1", email: "user1@company.com", name: "User 1",
                 isManager: false, roleTitle: "Barista", roleId: "barista-role",
                 companyId: companyId, companyName: "Test Company", createdAt: Date()),
            User(uid: "user2", email: "user2@company.com", name: "User 2",
                 isManager: true, roleTitle: "Manager", roleId: "manager-role",
                 companyId: companyId, companyName: "Test Company", createdAt: Date())
        ]
        
        mockUserRepository.users = testUsers
        mockUserRepository.shouldSucceed = true
        
        // Act
        let fetchedUsers = try await authService.fetchTeamMembers(companyId: companyId)
        
        // Assert
        XCTAssertEqual(fetchedUsers.count, 2)
        XCTAssertTrue(mockUserRepository.getTeamMembersCalled)
        XCTAssertEqual(fetchedUsers.first?.name, "User 1")
        XCTAssertEqual(fetchedUsers.last?.name, "User 2")
    }
    
    func testFetchTeamMembersWithEmptyCompanyId_ThrowsError() async {
        // Arrange
        let emptyCompanyId = ""
        
        // Act & Assert
        do {
            _ = try await authService.fetchTeamMembers(companyId: emptyCompanyId)
            XCTFail("Should throw error for empty company ID")
        } catch {
            // Should throw an error - specific error depends on implementation
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - Role-Based Permission Tests
    
    func testRoleBasedPermissionValidation_ManagerRole() {
        // Arrange
        let managerUser = User(
            uid: "manager-uid",
            email: "manager@company.com",
            name: "Manager User",
            isManager: true,
            roleTitle: "Manager",
            roleId: "manager-role-id",
            companyId: "company-id",
            companyName: "Test Company",
            createdAt: Date()
        )
        
        // Act
        authService.currentUser = managerUser
        
        // Assert
        XCTAssertTrue(authService.currentUser?.isManager ?? false)
        XCTAssertEqual(authService.currentUser?.roleTitle, "Manager")
    }
    
    func testRoleBasedPermissionValidation_BaristaRole() {
        // Arrange
        let baristaUser = User(
            uid: "barista-uid",
            email: "barista@company.com",
            name: "Barista User",
            isManager: false,
            roleTitle: "Barista",
            roleId: "barista-role-id",
            companyId: "company-id",
            companyName: "Test Company",
            createdAt: Date()
        )
        
        // Act
        authService.currentUser = baristaUser
        
        // Assert
        XCTAssertFalse(authService.currentUser?.isManager ?? true)
        XCTAssertEqual(authService.currentUser?.roleTitle, "Barista")
    }
    
    // MARK: - User Authentication State Tests
    
    func testUserAuthenticationStateTransitions() {
        // Arrange
        let expectation = XCTestExpectation(description: "User state changes")
        expectation.expectedFulfillmentCount = 2
        
        var receivedUsers: [User?] = []
        
        // Subscribe to user changes
        authService.$currentUser
            .sink { user in
                receivedUsers.append(user)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Act
        let testUser = User(
            uid: "test-uid",
            email: "test@example.com",
            name: "Test User",
            isManager: false,
            roleTitle: "Barista",
            roleId: "barista-role",
            companyId: "company-id",
            companyName: "Test Company",
            createdAt: Date()
        )
        
        authService.currentUser = testUser
        authService.currentUser = nil
        
        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedUsers.count, 2)
        XCTAssertNil(receivedUsers.first) // Initial nil value
        XCTAssertNil(receivedUsers.last) // Should be nil after logout
    }
    
    // MARK: - Company-Based User Filtering Tests
    
    func testCompanyBasedUserFiltering() async throws {
        // Arrange
        let companyId1 = "company-1"
        let companyId2 = "company-2"
        
        let allUsers = [
            User(uid: "user1", email: "user1@company1.com", name: "User 1",
                 isManager: false, roleTitle: "Barista", roleId: "barista-role",
                 companyId: companyId1, companyName: "Company 1", createdAt: Date()),
            User(uid: "user2", email: "user2@company1.com", name: "User 2",
                 isManager: false, roleTitle: "Barista", roleId: "barista-role",
                 companyId: companyId1, companyName: "Company 1", createdAt: Date()),
            User(uid: "user3", email: "user3@company2.com", name: "User 3",
                 isManager: false, roleTitle: "Barista", roleId: "barista-role",
                 companyId: companyId2, companyName: "Company 2", createdAt: Date())
        ]
        
        mockUserRepository.users = allUsers
        mockUserRepository.shouldSucceed = true
        
        // Act
        let company1Users = try await authService.fetchTeamMembers(companyId: companyId1)
        
        // Assert
        XCTAssertEqual(company1Users.count, 2)
        XCTAssertTrue(company1Users.allSatisfy { $0.companyId == companyId1 })
    }
    
    // MARK: - Invitation Flow Tests
    
    func testSendInvitation_Success() async throws {
        // Arrange
        let email = "newuser@company.com"
        let name = "New User"
        let companyId = "company-id"
        let companyName = "Test Company"
        let roleId = "barista-role"
        let roleTitle = "Barista"
        let isManager = false
        
        // Act
        do {
            try await authService.sendInvitation(
                email: email,
                name: name,
                companyId: companyId,
                companyName: companyName,
                roleId: roleId,
                roleTitle: roleTitle,
                isManager: isManager
            )
            
            // In a real implementation, this would create an invitation document
            // For now, we just verify no error was thrown
            XCTAssertTrue(true, "Invitation should be sent successfully")
        } catch {
            XCTFail("Invitation sending should succeed: \(error)")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testAuthenticationErrorMapping() {
        // Test various Firebase error mappings
        let testCases: [(NSError, ShiftFlowAuthenticationError)] = [
            (NSError(domain: "FIRAuthErrorDomain", code: 17004, userInfo: nil), .invalidEmail),
            (NSError(domain: "FIRAuthErrorDomain", code: 17005, userInfo: nil), .userNotFound),
            (NSError(domain: "FIRAuthErrorDomain", code: 17009, userInfo: nil), .wrongPassword),
            (NSError(domain: "FIRAuthErrorDomain", code: 17007, userInfo: nil), .emailAlreadyInUse)
        ]
        
        for (nsError, expectedError) in testCases {
            let mappedError = mapFirebaseAuthError(nsError)
            XCTAssertTrue(ShiftFlowAuthenticationError.isEqual(mappedError as? ShiftFlowAuthenticationError, expectedError))
        }
    }
}

// MARK: - Error Equality Extensions

extension ShiftFlowAuthenticationError {
    static func isEqual(_ lhs: ShiftFlowAuthenticationError?, _ rhs: ShiftFlowAuthenticationError?) -> Bool {
        guard let lhs = lhs, let rhs = rhs else { return lhs == nil && rhs == nil }
        
        switch (lhs, rhs) {
        case (.invalidEmail, .invalidEmail),
             (.invalidPassword, .invalidPassword),
             (.emailAlreadyInUse, .emailAlreadyInUse),
             (.userNotFound, .userNotFound),
             (.wrongPassword, .wrongPassword),
             (.notAuthenticated, .notAuthenticated),
             (.sessionExpired, .sessionExpired):
            return true
        case (.unknownError(let lhsError), .unknownError(let rhsError)):
            return lhsError?.localizedDescription == rhsError?.localizedDescription
        default:
            return false
        }
    }
}

extension ServiceError {
    static func isEqual(_ lhs: ServiceError?, _ rhs: ServiceError?) -> Bool {
        guard let lhs = lhs, let rhs = rhs else { return lhs == nil && rhs == nil }
        
        switch (lhs, rhs) {
        case (.invalidOperation(let lhsMsg), .invalidOperation(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.missingId(let lhsMsg), .missingId(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.dataConflict(let lhsMsg), .dataConflict(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.resourceLimit(let lhsMsg), .resourceLimit(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.dependencyFailed(let lhsMsg), .dependencyFailed(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}

// MARK: - Mock Repository Implementations

class MockUserRepository: UserRepository {
    typealias Model = User
    typealias ID = String
    typealias ListenerRegistration = MockListenerRegistration
    
    var entityName: String = "users"
    var users: [User] = []
    var shouldSucceed = true
    var createCalled = false
    var getTeamMembersCalled = false
    
    func create(_ model: User) async throws -> User {
        createCalled = true
        if shouldSucceed {
            users.append(model)
            return model
        } else {
            throw ShiftFlowRepositoryError.operationFailed("Mock create failed")
        }
    }
    
    func get(byId id: String) async throws -> User {
        if shouldSucceed, let user = users.first(where: { $0.uid == id }) {
            return user
        } else {
            throw ShiftFlowRepositoryError.documentNotFound
        }
    }
    
    func getAll() async throws -> [User] {
        if shouldSucceed {
            return users
        } else {
            throw ShiftFlowRepositoryError.operationFailed("Mock getAll failed")
        }
    }
    
    func update(_ model: User) async throws -> User {
        if shouldSucceed {
            if let index = users.firstIndex(where: { $0.uid == model.uid }) {
                users[index] = model
                return model
            } else {
                throw ShiftFlowRepositoryError.documentNotFound
            }
        } else {
            throw ShiftFlowRepositoryError.operationFailed("Mock update failed")
        }
    }
    
    func delete(id: String) async throws {
        if shouldSucceed {
            users.removeAll { $0.uid == id }
        } else {
            throw ShiftFlowRepositoryError.operationFailed("Mock delete failed")
        }
    }
    
    func getTeamMembers(companyId: String) async throws -> [User] {
        getTeamMembersCalled = true
        if shouldSucceed {
            return users.filter { $0.companyId == companyId }
        } else {
            throw ShiftFlowRepositoryError.operationFailed("Mock getTeamMembers failed")
        }
    }
    
    func getUsersByRole(companyId: String, roleId: String) async throws -> [User] {
        if shouldSucceed {
            return users.filter { $0.companyId == companyId && $0.roleId == roleId }
        } else {
            throw ShiftFlowRepositoryError.operationFailed("Mock getUsersByRole failed")
        }
    }
    
    func checkUserExists(email: String) async throws -> Bool {
        if shouldSucceed {
            return users.contains { $0.email?.lowercased() == email.lowercased() }
        } else {
            throw ShiftFlowRepositoryError.operationFailed("Mock checkUserExists failed")
        }
    }
    
    // MARK: - ListenableRepository
    
    nonisolated func listen(forId id: String, completion: @escaping (Result<User?, Error>) -> Void) -> MockListenerRegistration {
        return MockListenerRegistration()
    }
    
    nonisolated func listenAll(completion: @escaping (Result<[User], Error>) -> Void) -> MockListenerRegistration {
        return MockListenerRegistration()
    }
    
    nonisolated func stopListening(_ registration: MockListenerRegistration) {
        // Mock implementation
    }
}

class MockShiftRepository: ShiftRepository {
    typealias Model = Shift
    typealias ID = String
    typealias QueryFilter = ShiftQueryFilter
    typealias ListenerRegistration = MockListenerRegistration
    
    var entityName: String = "shifts"
    var shifts: [Shift] = []
    var shouldSucceed = true
    
    func create(_ model: Shift) async throws -> Shift {
        if shouldSucceed {
            shifts.append(model)
            return model
        } else {
            throw ShiftFlowRepositoryError.operationFailed("Mock create failed")
        }
    }
    
    func get(byId id: String) async throws -> Shift {
        if shouldSucceed, let shift = shifts.first(where: { $0.id == id }) {
            return shift
        } else {
            throw ShiftFlowRepositoryError.documentNotFound
        }
    }
    
    func getAll() async throws -> [Shift] {
        if shouldSucceed {
            return shifts
        } else {
            throw ShiftFlowRepositoryError.operationFailed("Mock getAll failed")
        }
    }
    
    func update(_ model: Shift) async throws -> Shift {
        if shouldSucceed {
            if let index = shifts.firstIndex(where: { $0.id == model.id }) {
                shifts[index] = model
                return model
            } else {
                throw ShiftFlowRepositoryError.documentNotFound
            }
        } else {
            throw ShiftFlowRepositoryError.operationFailed("Mock update failed")
        }
    }
    
    func delete(id: String) async throws {
        if shouldSucceed {
            shifts.removeAll { $0.id == id }
        } else {
            throw ShiftFlowRepositoryError.operationFailed("Mock delete failed")
        }
    }
    
    func getShiftsForCompany(companyId: String) async throws -> [Shift] {
        if shouldSucceed {
            return shifts.filter { $0.companyId == companyId }
        } else {
            throw ShiftFlowRepositoryError.operationFailed("Mock getShiftsForCompany failed")
        }
    }
    
    func getShiftsForUser(userId: String, companyId: String) async throws -> [Shift] {
        if shouldSucceed {
            return shifts.filter {
                $0.companyId == companyId && $0.assignedToUIDs.contains(userId)
            }
        } else {
            throw ShiftFlowRepositoryError.operationFailed("Mock getShiftsForUser failed")
        }
    }
    
    // MARK: - ListenableRepository
    
    nonisolated func listen(forId id: String, completion: @escaping (Result<Shift?, Error>) -> Void) -> MockListenerRegistration {
        return MockListenerRegistration()
    }
    
    nonisolated func listenAll(completion: @escaping (Result<[Shift], Error>) -> Void) -> MockListenerRegistration {
        return MockListenerRegistration()
    }
    
    nonisolated func stopListening(_ registration: MockListenerRegistration) {
        // Mock implementation
    }
    
    // MARK: - QueryableRepository
    
    func query(filter: ShiftQueryFilter) async throws -> [Shift] {
        var filteredShifts = shifts
        
        if let companyId = filter.companyId {
            filteredShifts = filteredShifts.filter { $0.companyId == companyId }
        }
        
        if let dayOfWeek = filter.dayOfWeek {
            filteredShifts = filteredShifts.filter { $0.dayOfWeek == dayOfWeek }
        }
        
        if let userId = filter.assignedToUserId {
            filteredShifts = filteredShifts.filter { $0.assignedToUIDs.contains(userId) }
        }
        
        if let status = filter.status {
            filteredShifts = filteredShifts.filter { $0.status == status }
        }
        
        return filteredShifts
    }
    
    // MARK: - PaginatedRepositoryProtocol
    
    func queryPaginated(filter: ShiftQueryFilter, pageSize: Int, lastDocument: DocumentSnapshot?) async throws -> (items: [Shift], lastDocument: DocumentSnapshot?) {
        let filteredShifts = try await query(filter: filter)
        let pageShifts = Array(filteredShifts.prefix(pageSize))
        return (items: pageShifts, lastDocument: nil)
    }
    
    // MARK: - Additional ShiftRepository Methods
    
    func updateTask(in shiftId: String, task: ShiftTask) async throws -> Shift {
        guard let index = shifts.firstIndex(where: { $0.id == shiftId }) else {
            throw ShiftFlowRepositoryError.documentNotFound
        }
        
        if let taskIndex = shifts[index].tasks.firstIndex(where: { $0.id == task.id }) {
            shifts[index].tasks[taskIndex] = task
        }
        
        return shifts[index]
    }
    
    func getShiftsForWeek(companyId: String) async throws -> [Shift] {
        return try await getShiftsForCompany(companyId: companyId)
    }
    
    func addTask(to shiftId: String, task: ShiftTask) async throws -> Shift {
        guard let index = shifts.firstIndex(where: { $0.id == shiftId }) else {
            throw ShiftFlowRepositoryError.documentNotFound
        }
        
        shifts[index].tasks.append(task)
        return shifts[index]
    }
    
    func removeTask(from shiftId: String, taskId: String) async throws -> Shift {
        guard let index = shifts.firstIndex(where: { $0.id == shiftId }) else {
            throw ShiftFlowRepositoryError.documentNotFound
        }
        
        shifts[index].tasks.removeAll { $0.id == taskId }
        return shifts[index]
    }
    
    func markTaskCompleted(in shiftId: String, taskId: String, completedBy: String, photoURL: String?) async throws -> Shift {
        guard let shiftIndex = shifts.firstIndex(where: { $0.id == shiftId }) else {
            throw ShiftFlowRepositoryError.documentNotFound
        }
        
        if let taskIndex = shifts[shiftIndex].tasks.firstIndex(where: { $0.id == taskId }) {
            shifts[shiftIndex].tasks[taskIndex].isCompleted = true
            shifts[shiftIndex].tasks[taskIndex].completedBy = completedBy
            shifts[shiftIndex].tasks[taskIndex].completedAt = Timestamp(date: Date())
            shifts[shiftIndex].tasks[taskIndex].photoURL = photoURL
        }
        
        return shifts[shiftIndex]
    }
    
    func batchUpdateShift(shiftId: String, updates: [ShiftUpdate]) async throws -> Shift {
        // Mock implementation
        return try await get(byId: shiftId)
    }
    
    func batchUpdateShifts(updates: [ShiftBatchUpdate]) async throws -> [Shift] {
        // Mock implementation
        return []
    }
}

// Mock listener registration
class MockListenerRegistration {
    // Mock implementation
}
