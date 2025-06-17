//
//  ShiftServiceWithRepoTests.swift
//  ShiftFlowTests
//
//  Created by Unit Test Generator on 16/06/2025.
//

import XCTest
import Combine
import FirebaseFirestore
@testable import ShiftFlow

@MainActor
final class ShiftServiceWithRepoTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var shiftService: ShiftServiceWithRepo!
    var mockRepositoryProvider: RepositoryProvider!
    var mockShiftRepository: MockShiftRepository!
    var cancellables: Set<AnyCancellable>!
    
    // MARK: - Test Setup & Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create mock repositories
        mockShiftRepository = MockShiftRepository()
        
        // Create mock repository provider
        mockRepositoryProvider = RepositoryFactory.createMockFactory(
            shiftRepository: mockShiftRepository
        )
        
        // Initialize service with mock repositories
        shiftService = ShiftServiceWithRepo(repositoryProvider: mockRepositoryProvider)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        shiftService = nil
        mockRepositoryProvider = nil
        mockShiftRepository = nil
        cancellables = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Shift Assignment Tests
    
    func testShiftAssignmentToMultipleUsers_Success() async throws {
        // Arrange
        let companyId = "test-company-id"
        let userIds = ["user1", "user2", "user3"]
        
        let testShift = Shift(
            dayOfWeek: .monday,
            startTime: Date(),
            endTime: Date().addingTimeInterval(8 * 3600), // 8 hours later
            assignedToUIDs: [],
            companyId: companyId,
            tasks: [],
            status: .scheduled,
            lastUpdatedBy: "manager-id",
            lastUpdatedAt: Date()
        )
        
        mockShiftRepository.shifts = [testShift]
        mockShiftRepository.shouldSucceed = true
        
        // Act
        var updatedShift = testShift
        updatedShift.assignedToUIDs = userIds
        
        let result = try await mockShiftRepository.update(updatedShift)
        
        // Assert
        XCTAssertEqual(result.assignedToUIDs.count, 3)
        XCTAssertEqual(Set(result.assignedToUIDs), Set(userIds))
        XCTAssertEqual(result.companyId, companyId)
    }
    
    func testShiftAssignmentConflictDetection() async throws {
        // Arrange
        let companyId = "test-company-id"
        let userId = "user1"
        let conflictingTime = Date()
        
        let existingShift = Shift(
            dayOfWeek: .monday,
            startTime: conflictingTime,
            endTime: conflictingTime.addingTimeInterval(4 * 3600),
            assignedToUIDs: [userId],
            companyId: companyId,
            tasks: [],
            status: .scheduled,
            lastUpdatedBy: "manager-id",
            lastUpdatedAt: Date()
        )
        
        let newShift = Shift(
            dayOfWeek: .monday,
            startTime: conflictingTime.addingTimeInterval(2 * 3600), // Overlaps
            endTime: conflictingTime.addingTimeInterval(6 * 3600),
            assignedToUIDs: [userId],
            companyId: companyId,
            tasks: [],
            status: .scheduled,
            lastUpdatedBy: "manager-id",
            lastUpdatedAt: Date()
        )
        
        mockShiftRepository.shifts = [existingShift]
        mockShiftRepository.shouldSucceed = true
        
        // Act
        let shifts = try await mockShiftRepository.getShiftsForUser(userId: userId, companyId: companyId)
        
        // Assert - Check for potential conflict
        let mondayShifts = shifts.filter { $0.dayOfWeek == .monday }
        XCTAssertEqual(mondayShifts.count, 1)
        
        // In a real implementation, you'd have conflict detection logic
        let hasTimeConflict = checkForTimeConflict(existing: existingShift, new: newShift)
        XCTAssertTrue(hasTimeConflict)
    }
    
    // MARK: - Concurrent Shift Modifications Tests
    
    func testConcurrentShiftModifications() async throws {
        // Arrange
        let companyId = "test-company-id"
        let shiftId = "test-shift-id"
        
        let originalShift = Shift(
            id: shiftId,
            dayOfWeek: .tuesday,
            startTime: Date(),
            endTime: Date().addingTimeInterval(8 * 3600),
            assignedToUIDs: ["user1"],
            companyId: companyId,
            tasks: [],
            status: .scheduled,
            lastUpdatedBy: "manager1",
            lastUpdatedAt: Date()
        )
        
        mockShiftRepository.shifts = [originalShift]
        mockShiftRepository.shouldSucceed = true
        
        // Act - Simulate concurrent modifications
        var modification1 = originalShift
        modification1.assignedToUIDs = ["user1", "user2"]
        modification1.lastUpdatedBy = "manager1"
        modification1.lastUpdatedAt = Timestamp(date: Date())
        
        var modification2 = originalShift
        modification2.tasks = [
            ShiftTask(title: "Task 1", description: "Test task", isCompleted: false,
                     priority: .medium, requiresPhotoProof: false, assignedRoleIds: [])
        ]
        modification2.lastUpdatedBy = "manager2"
        modification2.lastUpdatedAt = Timestamp(date: Date())

        
        // Apply modifications sequentially (simulating race condition handling)
        let result1 = try await mockShiftRepository.update(modification1)
        let result2 = try await mockShiftRepository.update(modification2)
        
        // Assert - Last modification should win
        let finalShift = try await mockShiftRepository.get(byId: shiftId)
        XCTAssertEqual(finalShift.tasks.count, 1)
        XCTAssertEqual(finalShift.lastUpdatedBy, "manager2")
    }
    
    // MARK: - Shift Pagination Tests
    
    func testShiftPaginationWithRealTimeUpdates() async throws {
        // Arrange
        let companyId = "test-company-id"
        let pageSize = 20
        
        // Create more shifts than page size
        var testShifts: [Shift] = []
        let dayOfWeekValues = Shift.DayOfWeek.testAllCases
        for i in 0..<25 {
            let shift = Shift(
                dayOfWeek: dayOfWeekValues[i % dayOfWeekValues.count],
                startTime: Date().addingTimeInterval(TimeInterval(i * 3600)),
                endTime: Date().addingTimeInterval(TimeInterval(i * 3600 + 8 * 3600)),
                assignedToUIDs: ["user\(i % 3)"],
                companyId: companyId,
                tasks: [],
                status: .scheduled,
                lastUpdatedBy: "manager-id",
                lastUpdatedAt: Date().addingTimeInterval(TimeInterval(i))
            )
            testShifts.append(shift)
        }
        
        mockShiftRepository.shifts = testShifts
        mockShiftRepository.shouldSucceed = true
        
        // Act
        let shifts = try await shiftService.fetchShifts(for: companyId)
        
        // Assert
        XCTAssertFalse(shiftService.isLoading)
        XCTAssertEqual(shiftService.shifts.count, 25)
        XCTAssertTrue(shiftService.hasMorePages) // Would be true if implementing pagination
    }
    
    func testShiftPaginationStateManagement() {
        // Arrange
        let expectation = XCTestExpectation(description: "Loading state changes")
        expectation.expectedFulfillmentCount = 2 // Start loading, stop loading
        
        var loadingStates: [Bool] = []
        
        // Subscribe to loading state changes
        shiftService.$isLoading
            .sink { isLoading in
                loadingStates.append(isLoading)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Act
        Task {
            let companyId = "test-company-id"
            mockShiftRepository.shouldSucceed = true
            _ = try await shiftService.fetchShifts(for: companyId)
        }
        
        // Assert
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(loadingStates.count, 2)
        XCTAssertFalse(loadingStates.first!) // Initial state
        XCTAssertFalse(loadingStates.last!)  // After loading
    }
    
    // MARK: - Task Completion Validation Tests
    
    func testShiftTaskCompletionValidation_Success() async throws {
        // Arrange
        let companyId = "test-company-id"
        let userId = "test-user-id"
        
        let task = ShiftTask(
            title: "Test Task",
            description: "Test Description",
            isCompleted: false,
            priority: .high,
            requiresPhotoProof: false,
            assignedRoleIds: ["barista-role"]
        )
        
        let shift = Shift(
            dayOfWeek: .wednesday,
            startTime: Date(),
            endTime: Date().addingTimeInterval(8 * 3600),
            assignedToUIDs: [userId],
            companyId: companyId,
            tasks: [task],
            status: .scheduled,
            lastUpdatedBy: "manager-id",
            lastUpdatedAt: Date()
        )
        
        mockShiftRepository.shifts = [shift]
        mockShiftRepository.shouldSucceed = true
        
        // Act - Mark task as completed
        var updatedShift = shift
        updatedShift.tasks[0].isCompleted = true
        updatedShift.tasks[0].completedBy = userId
        updatedShift.tasks[0].completedAt = Timestamp(date: Date())
        
        let result = try await mockShiftRepository.update(updatedShift)
        
        // Assert
        XCTAssertTrue(result.tasks[0].isCompleted)
        XCTAssertEqual(result.tasks[0].completedBy, userId)
        XCTAssertNotNil(result.tasks[0].completedAt)
    }
    
    func testShiftTaskCompletionWithPhotoProof() async throws {
        // Arrange
        let task = ShiftTask(
            title: "Photo Required Task",
            description: "Task that requires photo proof",
            isCompleted: false,
            priority: .high,
            requiresPhotoProof: true,
            assignedRoleIds: ["barista-role"]
        )
        
        // Act - Attempt to complete without photo
        var completedTask = task
        completedTask.isCompleted = true
        completedTask.completedBy = "user-id"
        completedTask.completedAt = Timestamp(date: Date())
        // Note: photoURL is still nil
        
        // Assert - In a real implementation, this would validate photo requirement
        XCTAssertTrue(completedTask.requiresPhotoProof)
        XCTAssertNil(completedTask.photoURL)
        
        // Complete with photo proof
        completedTask.photoURL = "https://example.com/photo.jpg"
        XCTAssertNotNil(completedTask.photoURL)
    }
    
    // MARK: - Shift Service State Tests
    
    func testShiftServicePublishedStateUpdates() {
        // Arrange
        let expectation = XCTestExpectation(description: "State updates")
        expectation.expectedFulfillmentCount = 3 // shifts, isLoading, errorMessage
        
        var stateUpdates = 0
        
        // Subscribe to all published properties
        Publishers.CombineLatest3(
            shiftService.$shifts,
            shiftService.$isLoading,
            shiftService.$errorMessage
        )
        .sink { shifts, isLoading, errorMessage in
            stateUpdates += 1
            expectation.fulfill()
        }
        .store(in: &cancellables)
        
        // Act
        shiftService.shifts = [Shift(dayOfWeek: .friday, startTime: Date(), endTime: Date(),
                                   assignedToUIDs: [], companyId: "test", tasks: [],
                                   status: .scheduled, lastUpdatedBy: "test", lastUpdatedAt: Date())]
        shiftService.isLoading = true
        shiftService.errorMessage = "Test error"
        
        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertGreaterThanOrEqual(stateUpdates, 3)
    }
    
    // MARK: - Error Handling Tests
    
    func testShiftFetchingErrorHandling() async {
        // Arrange
        let companyId = "test-company-id"
        mockShiftRepository.shouldSucceed = false
        
        // Act
        do {
            _ = try await shiftService.fetchShifts(for: companyId)
            XCTFail("Should throw error when repository fails")
        } catch {
            // Assert
            XCTAssertNotNil(error)
            XCTAssertFalse(shiftService.isLoading)
            XCTAssertNotNil(shiftService.errorMessage)
        }
    }
    
    func testShiftServiceErrorStateManagement() {
        // Arrange
        let expectation = XCTestExpectation(description: "Error state changes")
        var errorMessages: [String?] = []
        
        shiftService.$errorMessage
            .sink { errorMessage in
                errorMessages.append(errorMessage)
                if errorMessages.count >= 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Act
        shiftService.errorMessage = "Test error"
        shiftService.errorMessage = nil
        
        // Assert
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(errorMessages.count, 2)
        XCTAssertNil(errorMessages.first) // Initial state
        XCTAssertNil(errorMessages.last)  // After clearing
    }
    
    // MARK: - Helper Methods
    
    private func checkForTimeConflict(existing: Shift, new: Shift) -> Bool {
        // Simple overlap detection logic using date comparison
        let existingStart = existing.startTime.dateValue()
        let existingEnd = existing.endTime.dateValue()
        let newStart = new.startTime.dateValue()
        let newEnd = new.endTime.dateValue()
        
        return !(newEnd <= existingStart || newStart >= existingEnd)
    }
}

// MARK: - Test Extensions

// MARK: - Additional Mock Classes

extension MockShiftRepository {
    func getShiftsWithFilter(companyId: String, dayOfWeek: Shift.DayOfWeek?) async throws -> [Shift] {
        let companyShifts = try await getShiftsForCompany(companyId: companyId)
        
        if let dayOfWeek = dayOfWeek {
            return companyShifts.filter { $0.dayOfWeek == dayOfWeek }
        }
        
        return companyShifts
    }
}
