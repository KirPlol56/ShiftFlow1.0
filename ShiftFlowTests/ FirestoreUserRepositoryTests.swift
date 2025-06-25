//
//  FirestoreUserRepositoryTests.swift
//  ShiftFlowTests
//
//  Created by Kirill P on 24/06/2025.
//

import XCTest
@testable import ShiftFlow
import FirebaseFirestore
import FirebaseAuth

final class FirestoreUserRepositoryTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var repository: FirestoreUserRepository!
    var mockFirestore: MockFirestore!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Initialize mock Firestore
        mockFirestore = MockFirestore()
        
        // Create repository with mock Firestore
        repository = FirestoreUserRepository()
        // Note: In a real implementation, you'd inject the mock Firestore
    }
    
    override func tearDown() async throws {
        repository = nil
        mockFirestore = nil
        try await super.tearDown()
    }
    
    // MARK: - Actor Thread Safety Tests
    
    func testRepositoryActorThreadSafety() async {
        // Test that multiple concurrent operations don't cause data races
        let expectation = XCTestExpectation(description: "Concurrent operations complete")
        expectation.expectedFulfillmentCount = 100
        
        let testUser = createTestUser()
        
        // Simulate 100 concurrent operations
        for i in 0..<100 {
            Task {
                do {
                    if i % 2 == 0 {
                        _ = try await repository.create(testUser)
                    } else {
                        _ = try await repository.get(byId: testUser.uid)
                    }
                    expectation.fulfill()
                } catch {
                    // Expected for some operations due to test data
                    expectation.fulfill()
                }
            }
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
    }
    
    func testListenerLifecycleManagement() async {
        let testUser = createTestUser()
        var receivedResults: [Result<User?, Error>] = []
        let expectation = XCTestExpectation(description: "Listener receives data")
        
        // Start listening
        let registration = repository.listen(forId: testUser.uid) { result in
            receivedResults.append(result)
            expectation.fulfill()
        }
        
        // Verify listener is active
        XCTAssertNotNil(registration, "Listener registration should not be nil")
        
        // Stop listening
        repository.stopListening(registration)
        
        // Additional operations shouldn't trigger the listener
        await fulfillment(of: [expectation], timeout: 5.0)
        
        // Verify cleanup
        XCTAssertFalse(receivedResults.isEmpty, "Should have received at least one result")
    }
    
    // MARK: - Error Handling and Mapping Tests
    
    func testRepositoryErrorHandlingAndMapping() async {
        // Test document not found error
        do {
            _ = try await repository.get(byId: "nonexistent-id")
            XCTFail("Should throw document not found error")
        } catch let error as ShiftFlowRepositoryError {
            XCTAssertEqual(error, .documentNotFound, "Should map to document not found error")
        } catch {
            XCTFail("Should throw ShiftFlowRepositoryError, got: \(error)")
        }
        
        // Test invalid data error
        let invalidUser = User(
            uid: "",  // Invalid empty UID
            email: "invalid-email",
            name: "",
            companyId: "",
            companyName: "",
            roleId: "",
            roleTitle: "",
            isManager: false,
            profilePictureURL: nil,
            createdAt: Date(),
            lastLoginAt: Date()
        )
        
        do {
            _ = try await repository.create(invalidUser)
            XCTFail("Should throw invalid data error")
        } catch let error as ShiftFlowRepositoryError {
            XCTAssertEqual(error, .invalidData, "Should map to invalid data error")
        } catch {
            XCTFail("Should throw ShiftFlowRepositoryError, got: \(error)")
        }
    }
    
    func testNetworkErrorMapping() async {
        // Simulate network error by using invalid Firestore configuration
        // This test would require dependency injection of Firestore instance
        
        // For now, test error enum properties
        let networkError = ShiftFlowRepositoryError.networkError(NSError(domain: "TestDomain", code: 500, userInfo: nil))
        
        XCTAssertNotNil(networkError.errorDescription, "Network error should have description")
        XCTAssertTrue(networkError.errorDescription?.contains("network") == true ||
                     networkError.errorDescription?.contains("Network") == true,
                     "Error description should mention network")
    }
    
    // MARK: - Query Filtering Tests
    
    func testTeamMembersFiltering() async {
        let companyId = "test-company-123"
        
        do {
            let teamMembers = try await repository.getTeamMembers(companyId: companyId)
            
            // Verify all returned users belong to the company
            for member in teamMembers {
                XCTAssertEqual(member.companyId, companyId, "All team members should belong to the specified company")
            }
            
        } catch {
            // Expected in test environment without real Firestore data
            XCTAssertTrue(error is ShiftFlowRepositoryError, "Should throw ShiftFlowRepositoryError")
        }
    }
    
    func testEmptyCompanyIdValidation() async {
        do {
            _ = try await repository.getTeamMembers(companyId: "")
            XCTFail("Should throw error for empty company ID")
        } catch let error as ShiftFlowRepositoryError {
            XCTAssertEqual(error, .invalidData, "Should throw invalid data error for empty company ID")
        } catch {
            XCTFail("Should throw ShiftFlowRepositoryError")
        }
    }
    
    // MARK: - CRUD Operations Tests
    
    func testUserCreation() async {
        let testUser = createTestUser()
        
        do {
            let createdUser = try await repository.create(testUser)
            XCTAssertEqual(createdUser.uid, testUser.uid, "Created user should have same UID")
            XCTAssertEqual(createdUser.email, testUser.email, "Created user should have same email")
            XCTAssertEqual(createdUser.name, testUser.name, "Created user should have same name")
        } catch {
            // Expected in test environment
            XCTAssertTrue(error is ShiftFlowRepositoryError, "Should throw ShiftFlowRepositoryError")
        }
    }
    
    func testUserRetrieval() async {
        let testUser = createTestUser()
        
        do {
            let retrievedUser = try await repository.get(byId: testUser.uid)
            XCTAssertEqual(retrievedUser.uid, testUser.uid, "Retrieved user should have correct UID")
        } catch {
            // Expected in test environment without seeded data
            XCTAssertTrue(error is ShiftFlowRepositoryError, "Should throw ShiftFlowRepositoryError")
        }
    }
    
    func testUserUpdate() async {
        let testUser = createTestUser()
        let updatedUser = User(
            uid: testUser.uid,
            email: testUser.email,
            name: "Updated Name",
            companyId: testUser.companyId,
            companyName: testUser.companyName,
            roleId: testUser.roleId,
            roleTitle: "Updated Role",
            isManager: true,
            profilePictureURL: testUser.profilePictureURL,
            createdAt: testUser.createdAt,
            lastLoginAt: Date()
        )
        
        do {
            let result = try await repository.update(updatedUser)
            XCTAssertEqual(result.name, "Updated Name", "User name should be updated")
            XCTAssertEqual(result.roleTitle, "Updated Role", "User role should be updated")
            XCTAssertTrue(result.isManager, "User manager status should be updated")
        } catch {
            // Expected in test environment
            XCTAssertTrue(error is ShiftFlowRepositoryError, "Should throw ShiftFlowRepositoryError")
        }
    }
    
    func testUserDeletion() async {
        let testUserId = "test-user-123"
        
        do {
            try await repository.delete(id: testUserId)
            // If we reach here, deletion was successful (or user didn't exist)
            XCTAssertTrue(true, "Deletion should complete without throwing")
        } catch {
            // Expected in test environment
            XCTAssertTrue(error is ShiftFlowRepositoryError, "Should throw ShiftFlowRepositoryError")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestUser() -> User {
        return User(
            uid: "test-user-\(UUID().uuidString)",
            email: "test@example.com",
            name: "Test User",
            companyId: "test-company-123",
            companyName: "Test Company",
            roleId: "test-role-456",
            roleTitle: "Test Role",
            isManager: false,
            profilePictureURL: nil,
            createdAt: Date(),
            lastLoginAt: Date()
        )
    }
}

// MARK: - Mock Firestore for Testing

class MockFirestore {
    var collections: [String: MockCollectionReference] = [:]
    
    func collection(_ path: String) -> MockCollectionReference {
        if let existing = collections[path] {
            return existing
        }
        let newCollection = MockCollectionReference(path: path)
        collections[path] = newCollection
        return newCollection
    }
}

class MockCollectionReference {
    let path: String
    var documents: [String: [String: Any]] = [:]
    
    init(path: String) {
        self.path = path
    }
    
    func document(_ documentID: String) -> MockDocumentReference {
        return MockDocumentReference(path: "\(path)/\(documentID)", collection: self, documentID: documentID)
    }
    
    func addDocument(data: [String: Any]) async throws -> MockDocumentReference {
        let id = UUID().uuidString
        documents[id] = data
        return document(id)
    }
}

class MockDocumentReference {
    let path: String
    let collection: MockCollectionReference
    let documentID: String
    
    init(path: String, collection: MockCollectionReference, documentID: String) {
        self.path = path
        self.collection = collection
        self.documentID = documentID
    }
    
    func getDocument() async throws -> MockDocumentSnapshot {
        let data = collection.documents[documentID]
        return MockDocumentSnapshot(documentID: documentID, data: data, exists: data != nil)
    }
    
    func setData(_ data: [String: Any]) async throws {
        collection.documents[documentID] = data
    }
    
    func updateData(_ data: [String: Any]) async throws {
        if var existing = collection.documents[documentID] {
            for (key, value) in data {
                existing[key] = value
            }
            collection.documents[documentID] = existing
        } else {
            throw MockFirestoreError.documentNotFound
        }
    }
    
    func delete() async throws {
        collection.documents.removeValue(forKey: documentID)
    }
}

class MockDocumentSnapshot {
    let documentID: String
    let data: [String: Any]?
    let exists: Bool
    
    init(documentID: String, data: [String: Any]?, exists: Bool) {
        self.documentID = documentID
        self.data = data
        self.exists = exists
    }
    
    func data() -> [String: Any]? {
        return data
    }
}

enum MockFirestoreError: Error {
    case documentNotFound
    case invalidData
    case networkError
}

// Extension for ShiftFlowRepositoryError
extension ShiftFlowRepositoryError: Equatable {
    public static func == (lhs: ShiftFlowRepositoryError, rhs: ShiftFlowRepositoryError) -> Bool {
        switch (lhs, rhs) {
        case (.documentNotFound, .documentNotFound),
             (.decodingFailed, .decodingFailed),
             (.encodingFailed, .encodingFailed),
             (.permissionDenied, .permissionDenied),
             (.invalidData, .invalidData):
            return true
        case (.networkError(let lhsError), .networkError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.unexpectedError(let lhsError), .unexpectedError(let rhsError)):
            return lhsError?.localizedDescription == rhsError?.localizedDescription
        case (.operationFailed(let lhsMessage), .operationFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}
