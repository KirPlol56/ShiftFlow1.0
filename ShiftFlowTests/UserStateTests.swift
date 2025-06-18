//
//  UserStateTests.swift
//  ShiftFlowTests
//
//  Created by Unit Test Generator on 16/06/2025.
//

import XCTest
import Combine
@testable import ShiftFlow

@MainActor
final class UserStateTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var userState: UserState!
    var cancellables: Set<AnyCancellable>!
    
    // MARK: - Test Setup & Teardown
    
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
        // Assert
        XCTAssertNil(userState.currentUser)
    }
    
    func testUserStateUpdates() {
        // Arrange
        let expectation = XCTestExpectation(description: "User state updates")
        expectation.expectedFulfillmentCount = 2 // initial nil + new user
        
        var receivedUsers: [User?] = []
        
        userState.$currentUser
            .sink { user in
                receivedUsers.append(user)
                if receivedUsers.count >= 2 {
                    expectation.fulfill()
                }
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
        
        userState.currentUser = testUser
        
        // Assert
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(receivedUsers.count, 2)
        XCTAssertNil(receivedUsers[0]) // Initial state
        XCTAssertNotNil(receivedUsers[1]) // Updated state
        XCTAssertEqual(receivedUsers[1]?.uid, testUser.uid)
    }
    
    func testUserStateTransitions() {
        // Arrange
        let expectation = XCTestExpectation(description: "Multiple user state transitions")
        expectation.expectedFulfillmentCount = 4 // nil -> user1 -> user2 -> nil
        
        var stateChanges = 0
        
        userState.$currentUser
            .sink { _ in
                stateChanges += 1
                if stateChanges >= 4 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Act
        let user1 = User(uid: "user1", email: "user1@test.com", name: "User 1",
                        isManager: false, roleTitle: "Barista", roleId: "barista-role",
                        companyId: "company1", companyName: "Company 1", createdAt: Date())
        
        let user2 = User(uid: "user2", email: "user2@test.com", name: "User 2",
                        isManager: true, roleTitle: "Manager", roleId: "manager-role",
                        companyId: "company2", companyName: "Company 2", createdAt: Date())
        
        userState.currentUser = user1
        userState.currentUser = user2
        userState.currentUser = nil
        
        // Assert
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(stateChanges, 4)
        XCTAssertNil(userState.currentUser)
    }
    
    func testUserStateIsObservableObject() {
        // Arrange & Act
        let mirror = Mirror(reflecting: userState!)
        let isObservableObject = userState is any ObservableObject
        
        // Assert
        XCTAssertTrue(isObservableObject)
    }
}
