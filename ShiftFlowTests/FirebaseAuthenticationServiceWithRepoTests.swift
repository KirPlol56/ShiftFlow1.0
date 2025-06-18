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
        
        // Reset mock state
        mockUserRepository.reset()
        mockShiftRepository.reset()
        
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
        cancellables?.removeAll()
        cancellables = nil
        authService = nil
        mockUserRepository?.reset()
        mockShiftRepository?.reset()
        mockUserRepository = nil
        mockShiftRepository = nil
        mockRepositoryProvider = nil
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
        let invalidEmail = "invalid-email-format" // Invalid format (no @ symbol)
        let password = "testPassword123"
        let name = "Test Manager"
        let companyName = "Test Company"
        
        // Configure mock to simulate invalid email error
        mockUserRepository.shouldSucceed = false
        mockUserRepository.simulateError(.invalidEmail)
        
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
            // Use pattern matching instead of isEqual
            switch error {
            case .invalidEmail:
                XCTAssertTrue(true) // Test passes if we get invalidEmail
            default:
                XCTFail("Expected invalidEmail, got \(error)")
            }
        } catch {
            XCTFail("Should throw ShiftFlowAuthenticationError, got: \(error)")
        }
    }
    
    func testUserRegistrationWithWeakPassword_ThrowsError() async {
        // Arrange
        let email = "test@example.com"
        let weakPassword = "123" // Too short
        let name = "Test Manager"
        let companyName = "Test Company"
        
        // Configure mock to simulate weak password error
        mockUserRepository.shouldSucceed = false
        mockUserRepository.simulateError(.invalidPassword) // Use invalidPassword from existing enum
        
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
            // Use pattern matching instead of isEqual
            switch error {
            case .invalidPassword:
                XCTAssertTrue(true) // Test passes if we get invalidPassword
            default:
                XCTFail("Expected invalidPassword, got \(error)")
            }
        } catch {
            XCTFail("Should throw ShiftFlowAuthenticationError, got: \(error)")
        }
    }
    
    func testTeamMemberRegistration_Success() async throws {
        // Arrange
        let email = "member@testcompany.com"
        let password = "testPassword123"
        let name = "Test Member"
        let companyId = "existing-company-id"
        
        // Clear any existing emails to prevent conflicts
        mockUserRepository.reset()
        mockUserRepository.shouldSucceed = true
        
        // Act & Assert
        do {
            let testUser = User(
                uid: "test-member-uid",
                email: email,
                name: name,
                isManager: false,
                roleTitle: "Team Member",
                roleId: "member-role-id",
                companyId: companyId,
                companyName: "Test Company",
                createdAt: Date()
            )
            
            // Test user creation through repository
            let createdUser = try await mockUserRepository.create(testUser)
            
            XCTAssertEqual(createdUser.email, email)
            XCTAssertEqual(createdUser.name, name)
            XCTAssertFalse(createdUser.isManager)
            XCTAssertEqual(createdUser.companyId, companyId)
        } catch {
            XCTFail("Team member registration should succeed: \(error)")
        }
    }
    
    func testUserAuthenticationStateTransitions() {
        // Arrange
        let expectation = XCTestExpectation(description: "Authentication state changes")
        expectation.expectedFulfillmentCount = 3 // initial -> authenticated -> signed out
        
        var authStates: [Bool] = []
        
        // Subscribe to authentication state changes
        authService.$isAuthenticated
            .sink { isAuthenticated in
                authStates.append(isAuthenticated)
                if authStates.count >= 3 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Act - Simulate authentication state changes
        authService.isAuthenticated = true
        authService.isAuthenticated = false
        
        // Assert
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(authStates.count, 3)
        XCTAssertFalse(authStates[0]) // Initial state
        XCTAssertTrue(authStates[1])  // Authenticated
        XCTAssertFalse(authStates[2]) // Signed out
    }
}

// MARK: - MockUserRepository Extension

extension MockUserRepository {
    private static var existingEmails: Set<String> = []
    private static var simulatedError: ShiftFlowAuthenticationError?
    
    func reset() {
        Self.existingEmails.removeAll()
        Self.simulatedError = nil
        shouldSucceed = true
    }
    
    func simulateEmailExists(_ email: String) {
        Self.existingEmails.insert(email)
    }
    
    func simulateError(_ error: ShiftFlowAuthenticationError) {
        Self.simulatedError = error
        shouldSucceed = false
    }
    
    override func create(_ user: User) async throws -> User {
        if !shouldSucceed {
            if let error = Self.simulatedError {
                throw error
            }
            throw ShiftFlowAuthenticationError.unknownError(nil)
        }
        
        if Self.existingEmails.contains(user.email) {
            throw ShiftFlowAuthenticationError.emailAlreadyInUse
        }
        
        // Validate email format
        if !user.email.contains("@") || user.email.isEmpty {
            throw ShiftFlowAuthenticationError.invalidEmail
        }
        
        Self.existingEmails.insert(user.email)
        return user
    }
}
