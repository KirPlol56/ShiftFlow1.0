//
// TestDataFactory.swift
// ShiftFlowTests
//
// Created by Unit Test Generator on 16/06/2025.
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
            createdAt: Date() // ✅ Correct: User initializer expects Date, converts to Timestamp
        )
    }
    
    // MARK: - Fixed Shift Creation
    static func createTestShift(
        id: String? = nil,
        dayOfWeek: Shift.DayOfWeek = .monday,
        companyId: String = "test-company-id",
        assignedToUIDs: [String] = [],
        tasks: [ShiftTask] = []
    ) -> Shift {
        let startDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
        let endDate = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()
        
        return Shift(
            id: id,
            dayOfWeek: dayOfWeek,
            startTime: startDate, // ✅ Correct: Shift initializer expects Date, converts to Timestamp
            endTime: endDate, // ✅ Correct: Shift initializer expects Date, converts to Timestamp
            assignedToUIDs: assignedToUIDs,
            companyId: companyId,
            tasks: tasks,
            status: .scheduled,
            lastUpdatedBy: "test-manager",
            lastUpdatedAt: Date() // ✅ Correct: Shift initializer expects Date, converts to Timestamp
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
        return ShiftTask(
            title: title,
            isCompleted: true,
            completedBy: completedBy,
            completedAt: Date(), // ✅ Correct: ShiftTask initializer expects Date, converts to Timestamp
            createdAt: Date() // ✅ Correct: ShiftTask initializer expects Date, converts to Timestamp
        )
    }
    
    // MARK: - Role Creation
    static func createTestRole(
        title: String = "Test Role",
        companyId: String = "test-company-id",
        createdBy: String = "test-manager"
    ) -> Role {
        // ✅ Role initializer expects Timestamp with default conversion
        return Role(
            title: title,
            companyId: companyId,
            createdBy: createdBy,
            createdAt: Timestamp(date: Date()) // Role initializer expects Timestamp
        )
    }
    
    static func createStandardRole(
        standardRole: StandardRoles,
        companyId: String = "test-company-id"
    ) -> Role {
        return Role.fromStandardRole(standardRole, companyId: companyId)
    }
    
    static func createStandardRoles(companyId: String = "test-company-id") -> [Role] {
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
            users.append(createBaristaUser(uid: "user-\(i)", companyId: companyId))
        }
        
        let shifts = createWeeklyShifts(companyId: companyId, assignedToUIDs: users.map { $0.uid })
        
        return (users: users, shifts: shifts, roles: roles)
    }
    
    // MARK: - Helper Methods
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
    
    static func createExpectation(description: String, expectedFulfillmentCount: Int = 1) -> XCTestExpectation {
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

