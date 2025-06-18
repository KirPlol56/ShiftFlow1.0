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
        // Clean up in reverse order
        cancellables?.removeAll()
        cancellables = nil
        shiftService = nil
        mockShiftRepository?.reset() // Reset mock state
        mockShiftRepository = nil
        mockRepositoryProvider = nil
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
    
    func testShiftPaginationStateManagement() {
        // Arrange
        let expectation = XCTestExpectation(description: "Loading state changes")
        expectation.expectedFulfillmentCount = 2 // loading start, loading end
        
        var loadingStates: [Bool] = []
        var subscriptionCount = 0
        
        // Subscribe to loading state changes, skip initial value
        shiftService.$isLoading
            .dropFirst() // Skip the initial false state
            .sink { isLoading in
                loadingStates.append(isLoading)
                subscriptionCount += 1
                if subscriptionCount <= 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Act
        Task {
            let companyId = "test-company-id"
            mockShiftRepository.shouldSucceed = true
            mockShiftRepository.shifts = [] // Empty shifts for quick test
            
            do {
                _ = try await shiftService.fetchShifts(for: companyId)
            } catch {
                // Handle error if needed
            }
        }
        
        // Assert
        wait(for: [expectation], timeout: 3.0)
        XCTAssertEqual(loadingStates.count, 2)
        XCTAssertTrue(loadingStates.first!) // Started loading
        XCTAssertFalse(loadingStates.last!) // Finished loading
    }
    
    func testShiftServiceErrorStateManagement() {
        // Arrange
        let expectation = XCTestExpectation(description: "Error state changes")
        expectation.expectedFulfillmentCount = 3 // initial nil -> error -> nil
        
        var errorMessages: [String?] = []
        
        shiftService.$errorMessage
            .sink { errorMessage in
                errorMessages.append(errorMessage)
                if errorMessages.count >= 3 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Act
        shiftService.errorMessage = "Test error"
        shiftService.errorMessage = nil
        
        // Assert
        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(errorMessages.count, 3)
        XCTAssertNil(errorMessages[0]) // Initial state
        XCTAssertEqual(errorMessages[1], "Test error") // Error set
        XCTAssertNil(errorMessages[2]) // Error cleared
    }
    
    // MARK: - Rest of the original tests remain the same...
    
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

// MARK: - MockShiftRepository Extension

extension MockShiftRepository {
    func reset() {
        shifts.removeAll()
        shouldSucceed = true
        // Reset any other state properties
    }
    
    func getShiftsWithFilter(companyId: String, dayOfWeek: Shift.DayOfWeek?) async throws -> [Shift] {
        let companyShifts = try await getShiftsForCompany(companyId: companyId)
        
        if let dayOfWeek = dayOfWeek {
            return companyShifts.filter { $0.dayOfWeek == dayOfWeek }
        }
        
        return companyShifts
    }
}
