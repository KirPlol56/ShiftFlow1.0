//
// UserStateTests.swift
// ShiftFlowTests
//
// Created by Unit Test Generator on 16/06/2025.
//

import XCTest
import Combine
@testable import ShiftFlow

@MainActor
final class UserStateTests: XCTestCase {
    
    // MARK: - Test Properties
    var userState: UserState!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        userState = UserState()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        cancellables?.removeAll()
        cancellables = nil
        userState = nil
        try super.tearDownWithError()
    }
    
    // MARK: - User State Management Tests
    func testInitialUserState() {
        XCTAssertNil(userState.currentUser)
    }
    
    // MARK: - Fixed User State Updates Test
    func testUserStateUpdates() async {
        // Arrange
        let expectation = XCTestExpectation(description: "User state updates")
        var receivedUsers: [User?] = []
        
        let cancellable = userState.$currentUser
            .sink { user in
                receivedUsers.append(user)
                if receivedUsers.count == 2 {
                    expectation.fulfill()
                }
            }
        
        // Act - Allow initial state to be captured
        await Task.yield()
        
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
        
        userState.currentUser = testUser
        
        // Assert
        await fulfillment(of: [expectation], timeout: 2.0)
        cancellable.cancel()
        
        XCTAssertEqual(receivedUsers.count, 2)
        XCTAssertNil(receivedUsers[0]) // Initial state
        XCTAssertNotNil(receivedUsers[1]) // Updated state
        XCTAssertEqual(receivedUsers[1]?.uid, testUser.uid)
    }
    
    // MARK: - Fixed User State Transitions Test
    func testUserStateTransitions() async {
        // Arrange
        let expectation = XCTestExpectation(description: "Multiple user state transitions")
        var stateChanges = 0
        
        let cancellable = userState.$currentUser
            .sink { _ in
                stateChanges += 1
                if stateChanges == 4 {
                    expectation.fulfill()
                }
            }
        
        // Act - Allow initial state to be captured
        await Task.yield()
        
        let user1 = User(
            uid: "user1",
            email: "user1@test.com",
            name: "User 1",
            isManager: false,
            roleTitle: "Barista",
            roleId: "barista-role",
            companyId: "company1",
            companyName: "Company 1",
            createdAt: Date()
        )
        
        let user2 = User(
            uid: "user2",
            email: "user2@test.com",
            name: "User 2",
            isManager: true,
            roleTitle: "Manager",
            roleId: "manager-role",
            companyId: "company2",
            companyName: "Company 2",
            createdAt: Date()
        )
        
        userState.currentUser = user1
        await Task.yield()
        
        userState.currentUser = user2
        await Task.yield()
        
        userState.currentUser = nil
        
        // Assert
        await fulfillment(of: [expectation], timeout: 2.0)
        cancellable.cancel()
        
        XCTAssertEqual(stateChanges, 4)
        XCTAssertNil(userState.currentUser)
    }
    
    // Alternative simplified test that doesn't rely on async expectations
    func testUserStateTransitions_Simplified() {
        // Test direct state changes
        XCTAssertNil(userState.currentUser) // Initial state
        
        let user1 = User(
            uid: "user1",
            email: "user1@test.com",
            name: "User 1",
            isManager: false,
            roleTitle: "Barista",
            roleId: "barista-role",
            companyId: "company1",
            companyName: "Company 1",
            createdAt: Date()
        )
        
        userState.currentUser = user1
        XCTAssertEqual(userState.currentUser?.uid, "user1")
        
        let user2 = User(
            uid: "user2",
            email: "user2@test.com",
            name: "User 2",
            isManager: true,
            roleTitle: "Manager",
            roleId: "manager-role",
            companyId: "company2",
            companyName: "Company 2",
            createdAt: Date()
        )
        
        userState.currentUser = user2
        XCTAssertEqual(userState.currentUser?.uid, "user2")
        
        userState.currentUser = nil
        XCTAssertNil(userState.currentUser)
    }
    
    func testUserStateIsObservableObject() {
        let isObservableObject = userState is any ObservableObject
        XCTAssertTrue(isObservableObject)
    }
}

