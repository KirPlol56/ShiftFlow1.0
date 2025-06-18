//
//  TestDataFactory.swift
//  ShiftFlowTests
//
//  Created by Unit Test Generator on 16/06/2025.
//

import Foundation
import XCTest
import FirebaseFirestore
@testable import ShiftFlow

/// Factory class for creating test data objects
class TestDataFactory {
    
    // MARK: - User Creation
    
    static func createTestUser(
        uid: String = "test-uid",
        email: String = "test@example.com",
        name: String = "Test User",
        isManager: Bool = false,
        roleTitle: String = "Barista",
        roleId: String = "barista-role",
        companyId: String = "test-company-id",
        companyName: String = "Test Company"
    ) -> User {
        return User(
            uid: uid,
            email: email,
            name: name,
            isManager: isManager,
            roleTitle: roleTitle,
            roleId: roleId,
            companyId: companyId,
            companyName: companyName,
            createdAt: Date()
        )
    }
    
    static func createManagerUser(
        uid: String = "manager-uid",
        companyId: String = "test-company-id"
    ) -> User {
        return createTestUser(
            uid: uid,
            email: "manager@company.com",
            name: "Test Manager",
            isManager: true,
            roleTitle: "Manager",
            roleId: "manager-role",
            companyId: companyId,
            companyName: "Test Company"
        )
    }
    
    static func createBaristaUser(
        uid: String = "barista-uid",
        companyId: String = "test-company-id"
    ) -> User {
        return createTestUser(
            uid: uid,
            email: "barista@company.com",
            name: "Test Barista",
            isManager: false,
            roleTitle: "Barista",
            roleId: "barista-role",
            companyId: companyId,
            companyName: "Test Company"
        )
    }
    
    // MARK: - Shift Creation
    
    static func createTestShift(
        id: String? = nil,
        dayOfWeek: Shift.DayOfWeek = .monday,
        companyId: String = "test-company-id",
        assignedToUIDs: [String] = [],
        tasks: [ShiftTask] = []
    ) -> Shift {
        return Shift(
            id: id,
            dayOfWeek: dayOfWeek,
            startTime: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date(),
            endTime: Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date(),
            assignedToUIDs: assignedToUIDs,
            companyId: companyId,
            tasks: tasks,
            status: .scheduled,
            lastUpdatedBy: "test-manager",
            lastUpdatedAt: Date()
        )
    }
    
    static func createWeeklyShifts(
        companyId: String = "test-company-id",
        assignedToUIDs: [String] = []
    ) -> [Shift] {
        return Shift.DayOfWeek.testAllCases.map { dayOfWeek in
            createTestShift(
                dayOfWeek: dayOfWeek,
                companyId: companyId,
                assignedToUIDs: assignedToUIDs
            )
        }
    }
    
    // MARK: - Task Creation
    
    static func createTestTask(
        title: String = "Test Task",
        description: String = "Test task description",
        isCompleted: Bool = false,
        priority: ShiftTask.TaskPriority = .medium,
        requiresPhotoProof: Bool = false,
        assignedRoleIds: [String] = ["barista-role"]
    ) -> ShiftTask {
        return ShiftTask(
            title: title,
            description: description,
            isCompleted: isCompleted,
            priority: priority,
            requiresPhotoProof: requiresPhotoProof,
            assignedRoleIds: assignedRoleIds
        )
    }
    
    static func createCompletedTask(
        title: String = "Completed Task",
        completedBy: String = "test-user-id"
    ) -> ShiftTask {
        var task = createTestTask(title: title)
        task.isCompleted = true
        task.completedBy = completedBy
        task.completedAt = Timestamp(date: Date())
        return task
    }
    
    // MARK: - Role Creation
    
    static func createTestRole(
        title: String = "Test Role",
        companyId: String = "test-company-id",
        createdBy: String = "test-manager"
    ) -> Role {
        // Fixed: Remove id and isStandardRole parameters - they're not in the Role initializer
        var role = Role(
            title: title,
            companyId: companyId,
            createdBy: createdBy,
            createdAt: Timestamp(date: Date())
        )
        // Optionally set an ID after creation for testing purposes
        role.id = "test-role-\(UUID().uuidString)"
        return role
    }
    
    static func createStandardRole(
        standardRole: StandardRoles,
        companyId: String = "test-company-id"
    ) -> Role {
        // Use the built-in helper method from Role extension
        return Role.fromStandardRole(standardRole, companyId: companyId)
    }
    
    static func createStandardRoles(companyId: String = "test-company-id") -> [Role] {
        // Use the StandardRoles enum to create proper standard roles
        return [
            createStandardRole(standardRole: .manager, companyId: companyId),
            createStandardRole(standardRole: .barista, companyId: companyId),
            createStandardRole(standardRole: .waiter, companyId: companyId)
        ]
    }
    
    // MARK: - Company Data
    
    static func createTestCompanyData(
        companyId: String = "test-company-id",
        userCount: Int = 5
    ) -> (users: [User], shifts: [Shift], roles: [Role]) {
        let roles = createStandardRoles(companyId: companyId)
        
        var users: [User] = []
        users.append(createManagerUser(uid: "manager-1", companyId: companyId))
        
        for i in 1..<userCount {
            users.append(createBaristaUser(uid: "barista-\(i)", companyId: companyId))
        }
        
        let shifts = createWeeklyShifts(
            companyId: companyId,
            assignedToUIDs: Array(users.map { $0.uid }.prefix(3))
        )
        
        return (users: users, shifts: shifts, roles: roles)
    }
}

// MARK: - Test Helpers

class AsyncTestHelper {
    
    static func wait(
        for expectation: XCTestExpectation,
        timeout: TimeInterval = 5.0
    ) {
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed)
    }
    
    static func fulfillAfter(
        delay: TimeInterval,
        expectation: XCTestExpectation
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            expectation.fulfill()
        }
    }
    
    static func createExpectation(
        description: String,
        expectedFulfillmentCount: Int = 1
    ) -> XCTestExpectation {
        let expectation = XCTestExpectation(description: description)
        expectation.expectedFulfillmentCount = expectedFulfillmentCount
        return expectation
    }
}

// MARK: - Extensions for Testing

extension Shift.DayOfWeek {
    static var testAllCases: [Shift.DayOfWeek] {
        return [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
    }
    
    var displayName: String {
        switch self {
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        case .sunday: return "Sunday"
        }
    }
}
