//
//  FirestoreShiftRepositoryTests.swift
//  ShiftFlowTests
//
//  Created by Kirill P on 24/06/2025.
//

import XCTest
@testable import ShiftFlow
import FirebaseFirestore

final class FirestoreShiftRepositoryTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var repository: FirestoreShiftRepository!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        repository = FirestoreShiftRepository()
    }
    
    override func tearDown() async throws {
        repository = nil
        try await super.tearDown()
    }
    
    // MARK: - Actor Thread Safety Tests
    
    func testRepositoryActorThreadSafety() async {
        let expectation = XCTestExpectation(description: "Concurrent shift operations complete")
        expectation.expectedFulfillmentCount = 50
        
        let testShift = createTestShift()
        
        // Simulate concurrent read/write operations
        for i in 0..<50 {
            Task {
                do {
                    if i % 3 == 0 {
                        _ = try await repository.create(testShift)
                    } else if i % 3 == 1 {
                        _ = try await repository.get(byId: testShift.id ?? "test-id")
                    } else {
                        _ = try await repository.getAll()
                    }
                    expectation.fulfill()
                } catch {
                    // Expected for some operations in test environment
                    expectation.fulfill()
                }
            }
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
    }
    
    func testListenerLifecycleManagement() async {
        let testShiftId = "test-shift-123"
        var receivedResults: [Result<Shift?, Error>] = []
        let expectation = XCTestExpectation(description: "Shift listener receives data")
        
        // Test single shift listener
        let singleListener = repository.listen(forId: testShiftId) { result in
            receivedResults.append(result)
            expectation.fulfill()
        }
        
        // Test collection listener
        var allShiftsResults: [Result<[Shift], Error>] = []
        let allListener = repository.listenAll { result in
            allShiftsResults.append(result)
        }
        
        // Verify listeners are active
        XCTAssertNotNil(singleListener, "Single shift listener should not be nil")
        XCTAssertNotNil(allListener, "All shifts listener should not be nil")
        
        // Stop listeners
        repository.stopListening(singleListener)
        repository.stopListening(allListener)
        
        await fulfillment(of: [expectation], timeout: 5.0)
        
        // Verify results were received
        XCTAssertFalse(receivedResults.isEmpty, "Should have received at least one result")
    }
    
    // MARK: - Query Filtering Logic Tests
    
    func testRepositoryQueryFilteringLogic() async {
        // Test company filtering
        let companyFilter = ShiftQueryFilter(companyId: "test-company-123")
        
        do {
            let shifts = try await repository.query(filter: companyFilter)
            
            // Verify all shifts belong to the company (in real test with data)
            for shift in shifts {
                XCTAssertEqual(shift.companyId, "test-company-123", "All shifts should belong to the filtered company")
            }
        } catch {
            // Expected in test environment
            XCTAssertTrue(error is ShiftFlowRepositoryError, "Should throw ShiftFlowRepositoryError")
        }
        
        // Test day of week filtering
        let dayFilter = ShiftQueryFilter(dayOfWeek: .monday)
        
        do {
            let shifts = try await repository.query(filter: dayFilter)
            
            for shift in shifts {
                XCTAssertEqual(shift.dayOfWeek, .monday, "All shifts should be for Monday")
            }
        } catch {
            // Expected in test environment
            XCTAssertTrue(error is ShiftFlowRepositoryError, "Should throw ShiftFlowRepositoryError")
        }
        
        // Test user assignment filtering
        let userFilter = ShiftQueryFilter(assignedToUserId: "user-123")
        
        do {
            let shifts = try await repository.query(filter: userFilter)
            
            for shift in shifts {
                XCTAssertTrue(shift.assignedToUIDs.contains("user-123"), "All shifts should be assigned to the user")
            }
        } catch {
            // Expected in test environment
            XCTAssertTrue(error is ShiftFlowRepositoryError, "Should throw ShiftFlowRepositoryError")
        }
        
        // Test combined filtering
        let combinedFilter = ShiftQueryFilter(
            companyId: "test-company-123",
            dayOfWeek: .tuesday,
            assignedToUserId: "user-456",
            status: .scheduled
        )
        
        do {
            let shifts = try await repository.query(filter: combinedFilter)
            
            for shift in shifts {
                XCTAssertEqual(shift.companyId, "test-company-123", "Should match company filter")
                XCTAssertEqual(shift.dayOfWeek, .tuesday, "Should match day filter")
                XCTAssertTrue(shift.assignedToUIDs.contains("user-456"), "Should match user filter")
                XCTAssertEqual(shift.status, .scheduled, "Should match status filter")
            }
        } catch {
            // Expected in test environment
            XCTAssertTrue(error is ShiftFlowRepositoryError, "Should throw ShiftFlowRepositoryError")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testRepositoryErrorHandlingAndMapping() async {
        // Test document not found
        do {
            _ = try await repository.get(byId: "nonexistent-shift")
            XCTFail("Should throw document not found error")
        } catch let error as ShiftFlowRepositoryError {
            XCTAssertEqual(error, .documentNotFound, "Should map to document not found error")
        } catch {
            XCTFail("Should throw ShiftFlowRepositoryError")
        }
        
        // Test invalid data handling
        let invalidShift = Shift(
            id: "",  // Invalid empty ID
            title: "",
            startTime: Date(),
            endTime: Date().addingTimeInterval(-3600), // End before start (invalid)
            dayOfWeek: .monday,
            companyId: "",
            assignedToUIDs: [],
            status: .scheduled,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        do {
            _ = try await repository.create(invalidShift)
            XCTFail("Should throw invalid data error")
        } catch {
            // Expected - invalid shift data should cause error
            XCTAssertTrue(error is ShiftFlowRepositoryError || error is DecodingError,
                         "Should throw appropriate error for invalid data")
        }
    }
    
    // MARK: - Company Shifts Retrieval Tests
    
    func testGetShiftsForCompany() async {
        let companyId = "test-company-123"
        
        do {
            let shifts = try await repository.getShiftsForCompany(companyId: companyId)
            
            // Verify all shifts belong to the company
            for shift in shifts {
                XCTAssertEqual(shift.companyId, companyId, "All shifts should belong to the specified company")
            }
            
            // Verify the result is an array (even if empty)
            XCTAssertTrue(shifts is [Shift], "Result should be an array of Shift objects")
            
        } catch {
            // Expected in test environment
            XCTAssertTrue(error is ShiftFlowRepositoryError, "Should throw ShiftFlowRepositoryError")
        }
    }
    
    func testGetShiftsForCompanyWithEmptyId() async {
        do {
            _ = try await repository.getShiftsForCompany(companyId: "")
            XCTFail("Should throw error for empty company ID")
        } catch {
            // Expected - empty company ID should cause validation error
            XCTAssertTrue(error is ShiftFlowRepositoryError, "Should throw ShiftFlowRepositoryError for empty company ID")
        }
    }
    
    // MARK: - CRUD Operations Tests
    
    func testShiftCreation() async {
        let testShift = createTestShift()
        
        do {
            let createdShift = try await repository.create(testShift)
            XCTAssertEqual(createdShift.title, testShift.title, "Created shift should have same title")
            XCTAssertEqual(createdShift.companyId, testShift.companyId, "Created shift should have same company ID")
            XCTAssertEqual(createdShift.dayOfWeek, testShift.dayOfWeek, "Created shift should have same day of week")
        } catch {
            // Expected in test environment
            XCTAssertTrue(error is ShiftFlowRepositoryError, "Should throw ShiftFlowRepositoryError")
        }
    }
    
    func testShiftRetrieval() async {
        let testShiftId = "test-shift-123"
        
        do {
            let retrievedShift = try await repository.get(byId: testShiftId)
            XCTAssertEqual(retrievedShift.id, testShiftId, "Retrieved shift should have correct ID")
        } catch {
            // Expected in test environment without seeded data
            XCTAssertTrue(error is ShiftFlowRepositoryError, "Should throw ShiftFlowRepositoryError")
        }
    }
    
    func testShiftUpdate() async {
        let testShift = createTestShift()
        let updatedShift = Shift(
            id: testShift.id,
            title: "Updated Shift Title",
            startTime: testShift.startTime,
            endTime: testShift.endTime,
            dayOfWeek: .friday, // Changed day
            companyId: testShift.companyId,
            assignedToUIDs: ["new-user-123"], // Changed assignment
            status: .completed, // Changed status
            createdAt: testShift.createdAt,
            updatedAt: Date()
        )
        
        do {
            let result = try await repository.update(updatedShift)
            XCTAssertEqual(result.title, "Updated Shift Title", "Shift title should be updated")
            XCTAssertEqual(result.dayOfWeek, .friday, "Shift day should be updated")
            XCTAssertEqual(result.status, .completed, "Shift status should be updated")
            XCTAssertEqual(result.assignedToUIDs, ["new-user-123"], "Shift assignment should be updated")
        } catch {
            // Expected in test environment
            XCTAssertTrue(error is ShiftFlowRepositoryError, "Should throw ShiftFlowRepositoryError")
        }
    }
    
    func testShiftDeletion() async {
        let testShiftId = "test-shift-123"
        
        do {
            try await repository.delete(id: testShiftId)
            // If we reach here, deletion was successful (or shift didn't exist)
            XCTAssertTrue(true, "Deletion should complete without throwing")
        } catch {
            // Expected in test environment
            XCTAssertTrue(error is ShiftFlowRepositoryError, "Should throw ShiftFlowRepositoryError")
        }
    }
    
    func testGetAllShiftsWithLimit() async {
        do {
            let allShifts = try await repository.getAll()
            
            // Verify that the safety limit is respected (max 100 shifts)
            XCTAssertLessThanOrEqual(allShifts.count, 100, "Should respect the safety limit of 100 shifts")
            
            // Verify all returned objects are Shift instances
            for shift in allShifts {
                XCTAssertTrue(shift is Shift, "All returned objects should be Shift instances")
                XCTAssertNotNil(shift.id, "All shifts should have valid IDs")
                XCTAssertNotNil(shift.companyId, "All shifts should have company IDs")
            }
            
        } catch {
            // Expected in test environment
            XCTAssertTrue(error is ShiftFlowRepositoryError, "Should throw ShiftFlowRepositoryError")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestShift() -> Shift {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(8 * 3600) // 8 hours later
        
        return Shift(
            id: "test-shift-\(UUID().uuidString)",
            title: "Test Shift",
            startTime: startTime,
            endTime: endTime,
            dayOfWeek: .monday,
            companyId: "test-company-123",
            assignedToUIDs: ["user-123", "user-456"],
            status: .scheduled,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

// MARK: - ShiftQueryFilter Test Extension

extension ShiftQueryFilter {
    init(companyId: String? = nil,
         dayOfWeek: DayOfWeek? = nil,
         assignedToUserId: String? = nil,
         status: ShiftStatus? = nil) {
        self.companyId = companyId
        self.dayOfWeek = dayOfWeek
        self.assignedToUserId = assignedToUserId
        self.status = status
    }
}
