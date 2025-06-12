//
//  UserRepositoryTests.swift
//  ShiftFlowTests
//
//  Created by Kirill P on 15/04/2025.
//

import XCTest
import FirebaseFirestore
@testable import ShiftFlow

class UserRepositoryTests: XCTestCase {
    var mockRepository: MockUserRepository!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockUserRepository()
    }
    
    override func tearDown() {
        mockRepository = nil
        super.tearDown()
    }
    
    // MARK: - Test Basic CRUD Operations
    
    func testCreateUser() async throws {
        // Arrange
        let testUser = createTestUser()
        
        // Act
        let savedUser = try await mockRepository.create(testUser)
        
        // Assert
        XCTAssertEqual(savedUser.uid, testUser.uid)
        XCTAssertEqual(savedUser.name, testUser.name)
        XCTAssertEqual(savedUser.email, testUser.email)
        XCTAssertEqual(savedUser.isManager, testUser.isManager)
        XCTAssertEqual(mockRepository.users.count, 1)
    }
    
    func testGetUserById() async throws {
        // Arrange
        let testUser = createTestUser()
        try await mockRepository.create(testUser)
        
        // Act
        let fetchedUser = try await mockRepository.get(byId: testUser.uid)
        
        // Assert
        XCTAssertEqual(fetchedUser.uid, testUser.uid)
        XCTAssertEqual(fetchedUser.name, testUser.name)
    }
    
    func testGetUserByIdNotFound() async {
        // Arrange
        let nonExistentId = "non-existent-id"
        
        // Act & Assert
        do {
            _ = try await mockRepository.get(byId: nonExistentId)
            XCTFail("Expected error to be thrown")
        } catch {
            // Note: We changed this from an equality check to a condition check
            // This avoids the need for ShiftFlowRepositoryError to be Equatable
            XCTAssertTrue(error is ShiftFlowRepositoryError, "Error should be ShiftFlowRepositoryError")
            XCTAssertEqual(error.localizedDescription, ShiftFlowRepositoryError.documentNotFound.localizedDescription)
        }
    }
    
    func testUpdateUser() async throws {
        // Arrange
        let testUser = createTestUser()
        try await mockRepository.create(testUser)
        
        // Act
        var updatedUser = testUser
        updatedUser.name = "Updated Name" // Now works because name is var instead of let
        let result = try await mockRepository.update(updatedUser)
        
        // Assert
        XCTAssertEqual(result.name, "Updated Name")
        
        // Verify the repository state was updated
        let fetchedUser = try await mockRepository.get(byId: testUser.uid)
        XCTAssertEqual(fetchedUser.name, "Updated Name")
    }
    
    func testDeleteUser() async throws {
        // Arrange
        let testUser = createTestUser()
        try await mockRepository.create(testUser)
        
        // Act
        try await mockRepository.delete(id: testUser.uid)
        
        // Assert
        XCTAssertEqual(mockRepository.users.count, 0)
        
        // Verify the user cannot be fetched
        do {
            _ = try await mockRepository.get(byId: testUser.uid)
            XCTFail("Expected error to be thrown")
        } catch {
            // Changed from equality check to condition check
            XCTAssertTrue(error is ShiftFlowRepositoryError, "Error should be RepositoryError")
            XCTAssertEqual(error.localizedDescription, ShiftFlowRepositoryError.documentNotFound.localizedDescription)
        }
    }
    
    // MARK: - Test User Repository Specific Operations
    
    func testGetTeamMembers() async throws {
        // Arrange
        let companyId = "test-company"
        let user1 = createTestUser(uid: "user1", companyId: companyId)
        let user2 = createTestUser(uid: "user2", companyId: companyId)
        let user3 = createTestUser(uid: "user3", companyId: "other-company")
        
        try await mockRepository.create(user1)
        try await mockRepository.create(user2)
        try await mockRepository.create(user3)
        
        // Act
        let teamMembers = try await mockRepository.getTeamMembers(companyId: companyId)
        
        // Assert
        XCTAssertEqual(teamMembers.count, 2)
        XCTAssertTrue(teamMembers.contains { $0.uid == "user1" })
        XCTAssertTrue(teamMembers.contains { $0.uid == "user2" })
        XCTAssertFalse(teamMembers.contains { $0.uid == "user3" })
    }
    
    func testGetUsersByRole() async throws {
        // Arrange
        let companyId = "test-company"
        let baristaRoleId = "role_barista"
        let managerRoleId = "role_manager"
        
        let user1 = createTestUser(uid: "user1", companyId: companyId, roleId: baristaRoleId)
        let user2 = createTestUser(uid: "user2", companyId: companyId, roleId: baristaRoleId)
        let user3 = createTestUser(uid: "user3", companyId: companyId, roleId: managerRoleId)
        
        try await mockRepository.create(user1)
        try await mockRepository.create(user2)
        try await mockRepository.create(user3)
        
        // Act
        let baristas = try await mockRepository.getUsersByRole(companyId: companyId, roleId: baristaRoleId)
        
        // Assert
        XCTAssertEqual(baristas.count, 2)
        XCTAssertTrue(baristas.contains { $0.uid == "user1" })
        XCTAssertTrue(baristas.contains { $0.uid == "user2" })
        XCTAssertFalse(baristas.contains { $0.uid == "user3" })
    }
    
    func testCheckUserExists() async throws {
        // Arrange
        let email = "test@example.com"
        let user = createTestUser(email: email)
        try await mockRepository.create(user)
        
        // Act
        let exists = try await mockRepository.checkUserExists(email: email)
        let notExists = try await mockRepository.checkUserExists(email: "other@example.com")
        
        // Assert
        XCTAssertTrue(exists)
        XCTAssertFalse(notExists)
    }
    
    // MARK: - Test Listenable Repository
    
    func testListenForUser() async throws {
        // Arrange
        let testUser = createTestUser()
        try await mockRepository.create(testUser)
        
        // Expectations
        let expectation = XCTestExpectation(description: "Listen for user changes")
        
        // Act
        let registration = mockRepository.listen(forId: testUser.uid) { result in
            switch result {
            case .success(let user):
                XCTAssertNotNil(user)
                XCTAssertEqual(user?.name, testUser.name)
                expectation.fulfill()
            case .failure:
                XCTFail("Unexpected error")
            }
        }
        
        // Wait for expectation to be fulfilled
        wait(for: [expectation], timeout: 1.0)
        
        // Clean up
        mockRepository.stopListening(registration)
    }
    
    func testListenForChanges() async throws {
        // Arrange
        let testUser = createTestUser()
        try await mockRepository.create(testUser)
        
        // Expectations
        let initialExpectation = XCTestExpectation(description: "Initial user data")
        let updateExpectation = XCTestExpectation(description: "Updated user data")
        
        var receivedChanges = 0
        
        // Act
        let registration = mockRepository.listen(forId: testUser.uid) { result in
            switch result {
            case .success(let user):
                XCTAssertNotNil(user)
                
                if receivedChanges == 0 {
                    // First notification - initial data
                    XCTAssertEqual(user?.name, testUser.name)
                    initialExpectation.fulfill()
                    
                    // Trigger an update after receiving initial data
                    Task {
                        do {
                            var updatedUser = testUser
                            updatedUser.name = "Updated Name" // This works now because name is var
                            try await self.mockRepository.update(updatedUser)
                        } catch {
                            XCTFail("Failed to update user: \(error)")
                        }
                    }
                } else if receivedChanges == 1 {
                    // Second notification - after update
                    XCTAssertEqual(user?.name, "Updated Name")
                    updateExpectation.fulfill()
                }
                
                receivedChanges += 1
            case .failure:
                XCTFail("Unexpected error")
            }
        }
        
        // Wait for expectations to be fulfilled
        wait(for: [initialExpectation, updateExpectation], timeout: 1.0)
        
        // Clean up
        mockRepository.stopListening(registration)
    }
    
    // MARK: - Helper Methods
    
    private func createTestUser(
        uid: String = "test-uid",
        email: String = "test@example.com",
        name: String = "Test User",
        isManager: Bool = false,
        companyId: String = "test-company",
        roleId: String = "test-role"
    ) -> User {
        return User(
            uid: uid,
            email: email,
            name: name,
            isManager: isManager,
            roleTitle: isManager ? "Manager" : "Barista",
            roleId: roleId,
            companyId: companyId,
            companyName: "Test Company",
            createdAt: Date()
        )
    }
}
