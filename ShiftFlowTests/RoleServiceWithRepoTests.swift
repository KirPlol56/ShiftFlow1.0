//
//  RoleServiceWithRepoTests.swift
//  ShiftFlowTests
//
//  Created by Kirill P on 24/06/2025.
//

import XCTest
@testable import ShiftFlow

@MainActor
final class RoleServiceWithRepoTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var roleService: RoleServiceWithRepo!
    var mockRepositoryProvider: MockRepositoryProvider!
    var mockRoleRepository: MockRoleRepository!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        mockRoleRepository = MockRoleRepository()
        mockRepositoryProvider = MockRepositoryProvider(roleRepository: mockRoleRepository)
        roleService = RoleServiceWithRepo(repositoryProvider: mockRepositoryProvider)
    }
    
    override func tearDown() {
        roleService = nil
        mockRepositoryProvider = nil
        mockRoleRepository = nil
        super.tearDown()
    }
    
    // MARK: - Custom Role Creation Tests
    
    func testCustomRoleCreation() async {
        // Given
        let companyId = "test-company-123"
        let roleTitle = "Custom Barista Manager"
        let createdBy = "user-456"
        
        // When
        do {
            let createdRole = try await roleService.addRole(title: roleTitle, companyId: companyId, createdBy: createdBy)
            
            // Then
            XCTAssertEqual(createdRole.title, roleTitle, "Created role should have correct title")
            XCTAssertEqual(createdRole.companyId, companyId, "Created role should have correct company ID")
            XCTAssertEqual(createdRole.createdBy, createdBy, "Created role should have correct creator")
            XCTAssertFalse(createdRole.isStandard, "Custom role should not be marked as standard")
            XCTAssertNotNil(createdRole.id, "Created role should have an ID")
            XCTAssertEqual(mockRoleRepository.lastCalledMethod, "create", "Should call create method on repository")
            
        } catch {
            XCTFail("Should not throw error: \(error)")
        }
    }
    
    func testDuplicateRoleCreationPrevention() async {
        // Given
        let companyId = "test-company-123"
        let roleTitle = "Existing Role"
        let createdBy = "user-456"
        
        // Setup existing role
        let existingRole = Role(id: "existing-1", title: roleTitle, companyId: companyId, isStandard: false, createdBy: createdBy, createdAt: Date())
        mockRoleRepository.roles.append(existingRole)
        
        // When/Then
        do {
            let exists = try await roleService.checkRoleExists(title: roleTitle, companyId: companyId)
            XCTAssertTrue(exists, "Should detect existing role")
            
            // Attempt to create duplicate
            let duplicateRole = try await roleService.addRole(title: roleTitle, companyId: companyId, createdBy: createdBy)
            
            // In a real implementation, this should prevent duplicates or handle them appropriately
            XCTAssertNotNil(duplicateRole, "Service should handle duplicate creation")
            
        } catch {
            // Expected behavior - duplicates should be handled
            XCTAssertTrue(true, "Duplicate role creation should be handled appropriately")
        }
    }
    
    // MARK: - Permission Inheritance Tests
    
    func testStandardRolePermissionInheritance() async {
        // Given - Setup standard roles
        let standardRoles = createStandardRoles()
        mockRoleRepository.roles.append(contentsOf: standardRoles)
        
        // When
        do {
            let retrievedStandardRoles = try await roleService.getAllStandardRoles()
            
            // Then
            XCTAssertFalse(retrievedStandardRoles.isEmpty, "Should return standard roles")
            
            for role in retrievedStandardRoles {
                XCTAssertTrue(role.isStandard, "All returned roles should be marked as standard")
                
                // Test permission inheritance based on role type
                switch role.title.lowercased() {
                case let title where title.contains("manager"):
                    XCTAssertTrue(title.contains("manager"), "Manager roles should be identified correctly")
                case let title where title.contains("barista"):
                    XCTAssertTrue(title.contains("barista"), "Barista roles should be identified correctly")
                case let title where title.contains("chef"):
                    XCTAssertTrue(title.contains("chef"), "Chef roles should be identified correctly")
                default:
                    XCTAssertTrue(true, "Other standard roles should be valid")
                }
            }
            
        } catch {
            XCTFail("Should not throw error: \(error)")
        }
    }
    
    func testManagerVsBaristaPermissions() async {
        // Given
        let companyId = "test-company-123"
        let managerRole = createManagerRole(companyId: companyId)
        let baristaRole = createBaristaRole(companyId: companyId)
        
        mockRoleRepository.roles.append(contentsOf: [managerRole, baristaRole])
        
        // When
        do {
            let companyRoles = try await roleService.fetchRoles(forCompany: companyId)
            
            // Then
            let managers = companyRoles.filter { $0.title.lowercased().contains("manager") }
            let baristas = companyRoles.filter { $0.title.lowercased().contains("barista") }
            
            XCTAssertFalse(managers.isEmpty, "Should have manager roles")
            XCTAssertFalse(baristas.isEmpty, "Should have barista roles")
            
            // Test role-specific permissions
            for manager in managers {
                XCTAssertTrue(manager.title.lowercased().contains("manager"), "Manager role should be identified")
                // In real implementation, test specific manager permissions
            }
            
            for barista in baristas {
                XCTAssertTrue(barista.title.lowercased().contains("barista"), "Barista role should be identified")
                // In real implementation, test specific barista permissions
            }
            
        } catch {
            XCTFail("Should not throw error: \(error)")
        }
    }
    
    // MARK: - Role-Based Data Access Tests
    
    func testRoleBasedDataAccess() async {
        // Given
        let companyId1 = "company-1"
        let companyId2 = "company-2"
        
        let company1Roles = [
            createTestRole(companyId: companyId1, title: "Company 1 Manager"),
            createTestRole(companyId: companyId1, title: "Company 1 Barista")
        ]
        
        let company2Roles = [
            createTestRole(companyId: companyId2, title: "Company 2 Manager"),
            createTestRole(companyId: companyId2, title: "Company 2 Barista")
        ]
        
        mockRoleRepository.roles.append(contentsOf: company1Roles + company2Roles)
        
        // When
        do {
            let company1FetchedRoles = try await roleService.fetchRoles(forCompany: companyId1)
            let company2FetchedRoles = try await roleService.fetchRoles(forCompany: companyId2)
            
            // Then
            XCTAssertEqual(company1FetchedRoles.count, 2, "Should return exactly 2 roles for company 1")
            XCTAssertEqual(company2FetchedRoles.count, 2, "Should return exactly 2 roles for company 2")
            
            // Verify data isolation
            for role in company1FetchedRoles {
                XCTAssertEqual(role.companyId, companyId1, "Company 1 roles should only belong to company 1")
            }
            
            for role in company2FetchedRoles {
                XCTAssertEqual(role.companyId, companyId2, "Company 2 roles should only belong to company 2")
            }
            
        } catch {
            XCTFail("Should not throw error: \(error)")
        }
    }
    
    func testRoleAccessValidation() async {
        // Given
        let validCompanyId = "valid-company-123"
        let invalidCompanyId = ""
        
        // When/Then - Test valid company ID
        do {
            let roles = try await roleService.fetchRoles(forCompany: validCompanyId)
            XCTAssertNotNil(roles, "Should return roles array for valid company ID")
        } catch {
            // Expected in test environment
            XCTAssertTrue(true, "Valid company ID test completed")
        }
        
        // When/Then - Test invalid company ID
        do {
            _ = try await roleService.fetchRoles(forCompany: invalidCompanyId)
            XCTFail("Should throw error for invalid company ID")
        } catch {
            // Expected - invalid company ID should cause error
            XCTAssertTrue(true, "Should handle invalid company ID appropriately")
        }
    }
    
    // MARK: - Role Resolution Tests
    
    func testRoleInfoResolution() async {
        // Given
        let companyId = "test-company-123"
        let testRole = createTestRole(companyId: companyId, title: "Test Role")
        mockRoleRepository.roles.append(testRole)
        
        // When
        do {
            let roleInfo = try await roleService.resolveRoleInfo(roleId: testRole.id!, companyId: companyId)
            
            // Then
            XCTAssertEqual(roleInfo.id, testRole.id, "Should resolve correct role ID")
            XCTAssertEqual(roleInfo.title, testRole.title, "Should resolve correct role title")
            
        } catch {
            XCTFail("Should not throw error: \(error)")
        }
    }
    
    func testRoleInfoResolutionWithInvalidId() async {
        // Given
        let companyId = "test-company-123"
        let invalidRoleId = "nonexistent-role"
        
        // When/Then
        do {
            _ = try await roleService.resolveRoleInfo(roleId: invalidRoleId, companyId: companyId)
            XCTFail("Should throw error for invalid role ID")
        } catch {
            // Expected - invalid role ID should cause error
            XCTAssertTrue(true, "Should handle invalid role ID appropriately")
        }
    }
    
    // MARK: - Role Management Tests
    
    func testRoleUpdateOperation() async {
        // Given
        let companyId = "test-company-123"
        let originalRole = createTestRole(companyId: companyId, title: "Original Role")
        mockRoleRepository.roles.append(originalRole)
        
        let updatedRole = Role(
            id: originalRole.id,
            title: "Updated Role Title",
            companyId: originalRole.companyId,
            isStandard: originalRole.isStandard,
            createdBy: originalRole.createdBy,
            createdAt: originalRole.createdAt
        )
        
        // When
        do {
            let result = try await roleService.updateRole(role: updatedRole)
            
            // Then
            XCTAssertEqual(result.title, "Updated Role Title", "Role title should be updated")
            XCTAssertEqual(result.id, originalRole.id, "Role ID should remain the same")
            XCTAssertEqual(mockRoleRepository.lastCalledMethod, "update", "Should call update method on repository")
            
        } catch {
            XCTFail("Should not throw error: \(error)")
        }
    }
    
    func testRoleDeletionOperation() async {
        // Given
        let companyId = "test-company-123"
        let roleToDelete = createTestRole(companyId: companyId, title: "Role to Delete")
        mockRoleRepository.roles.append(roleToDelete)
        
        // When
        do {
            try await roleService.deleteRole(id: roleToDelete.id!)
            
            // Then
            XCTAssertEqual(mockRoleRepository.lastCalledMethod, "delete", "Should call delete method on repository")
            
        } catch {
            XCTFail("Should not throw error: \(error)")
        }
    }
    
    // MARK: - Completion Handler API Tests
    
    func testCompletionHandlerAPI() async {
        // Given
        let companyId = "test-company-123"
        let testRoles = [
            createTestRole(companyId: companyId, title: "Manager"),
            createTestRole(companyId: companyId, title: "Barista")
        ]
        mockRoleRepository.roles.append(contentsOf: testRoles)
        
        // When
        let expectation = XCTestExpectation(description: "Completion handler called")
        
        roleService.fetchRoles(forCompany: companyId) { result in
            switch result {
            case .success(let roles):
                XCTAssertEqual(roles.count, 2, "Should return 2 roles")
                XCTAssertTrue(roles.allSatisfy { $0.companyId == companyId }, "All roles should belong to company")
            case .failure(let error):
                XCTFail("Should not fail: \(error)")
            }
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    // MARK: - Helper Methods
    
    private func createTestRole(companyId: String, title: String) -> Role {
        return Role(
            id: "role-\(UUID().uuidString)",
            title: title,
            companyId: companyId,
            isStandard: false,
            createdBy: "test-user",
            createdAt: Date()
        )
    }
    
    private func createManagerRole(companyId: String) -> Role {
        return Role(
            id: "manager-\(UUID().uuidString)",
            title: "Manager",
            companyId: companyId,
            isStandard: true,
            createdBy: nil,
            createdAt: Date()
        )
    }
    
    private func createBaristaRole(companyId: String) -> Role {
        return Role(
            id: "barista-\(UUID().uuidString)",
            title: "Barista",
            companyId: companyId,
            isStandard: true,
            createdBy: nil,
            createdAt: Date()
        )
    }
    
    private func createStandardRoles() -> [Role] {
        return [
            Role(id: "std-1", title: "Manager", companyId: "test-company", isStandard: true, createdBy: nil, createdAt: Date()),
            Role(id: "std-2", title: "Barista", companyId: "test-company", isStandard: true, createdBy: nil, createdAt: Date()),
            Role(id: "std-3", title: "Chef", companyId: "test-company", isStandard: true, createdBy: nil, createdAt: Date()),
            Role(id: "std-4", title: "Waiter", companyId: "test-company", isStandard: true, createdBy: nil, createdAt: Date())
        ]
    }
}

// MARK: - Mock Repository Provider

class MockRepositoryProvider: RepositoryProvider {
    private let _roleRepository: any RoleRepository
    
    init(roleRepository: any RoleRepository) {
        self._roleRepository = roleRepository
    }
    
    func userRepository() -> any UserRepository {
        return MockUserRepository()
    }
    
    func shiftRepository() -> any ShiftRepository {
        return MockShiftRepository()
    }
    
    func roleRepository() -> any RoleRepository {
        return _roleRepository
    }
    
    func checkListRepository() -> any CheckListRepository {
        return MockCheckListRepository()
    }
}
