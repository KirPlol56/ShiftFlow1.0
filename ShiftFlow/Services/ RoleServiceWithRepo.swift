//
//  RoleServiceWithRepo.swift
//  ShiftFlow
//
//  Created by Kirill P on 07/04/2025.
//

import Foundation
import FirebaseFirestore
import Combine

/// Protocol defining role management operations with async/await first approach
protocol RoleServiceProtocol: ObservableObject {
    // MARK: - Primary Async API
    
    /// Fetch roles for a company
    func fetchRoles(forCompany companyId: String) async throws -> [Role]
    
    /// Check if a role exists with the given title
    func checkRoleExists(title: String, companyId: String) async throws -> Bool
    
    /// Add a new role
    func addRole(title: String, companyId: String, createdBy: String) async throws -> Role
    
    /// Resolve role info from ID
    func resolveRoleInfo(roleId: String, companyId: String) async throws -> (id: String, title: String)
    
    /// Delete a role
    func deleteRole(id: String) async throws
    
    /// Update a role
    func updateRole(role: Role) async throws -> Role
    
    /// Get all standard roles
    func getAllStandardRoles() async throws -> [Role]
    
    /// Get active roles for a company
    func getActiveRoles(forCompany companyId: String) async throws -> [Role]
    
    // MARK: - Legacy Completion Handler API
    
    /// Fetch roles for a company
    func fetchRoles(forCompany companyId: String, completion: @escaping (Result<[Role], Error>) -> Void)
    
    /// Check if a role exists with the given title
    func checkRoleExists(title: String, companyId: String, completion: @escaping (Result<Bool, Error>) -> Void)
    
    /// Add a new role
    func addRole(title: String, companyId: String, createdBy: String, completion: @escaping (Result<Role, Error>) -> Void)
    
    /// Resolve role info from ID
    func resolveRoleInfo(roleId: String, companyId: String, completion: @escaping (Result<(id: String, title: String), Error>) -> Void)
    
    /// Delete a role
    func deleteRole(id: String, completion: @escaping (Result<Void, Error>) -> Void)
    
    /// Update a role
    func updateRole(role: Role, completion: @escaping (Result<Role, Error>) -> Void)
    
    /// Get all standard roles
    func getAllStandardRoles(completion: @escaping (Result<[Role], Error>) -> Void)
    
    /// Get active roles for a company
    func getActiveRoles(forCompany companyId: String, completion: @escaping (Result<[Role], Error>) -> Void)
    
    // MARK: - Helper Methods
    
    /// Convert a standard role name to ID
    func standardRoleNameToId(name: String) -> String?
    
    /// Check if a role ID is a standard role
    func isStandardRoleId(roleId: String) -> Bool
}

/// Implementation of RoleService using the repository pattern
class RoleServiceWithRepo: ObservableObject, RoleServiceProtocol {
    // MARK: - Properties
    
    /// Repository for data access
    private let roleRepository: any RoleRepository
    
    // MARK: - Lifecycle
    
    /// Initialize with repository
    init(repositoryProvider: RepositoryProvider = RepositoryFactory.shared) {
        self.roleRepository = repositoryProvider.roleRepository()
    }
    
    // MARK: - Primary Async API Implementation
    
    /// Fetch roles for a company
    /// - Parameter companyId: Company ID
    /// - Returns: Array of roles
    func fetchRoles(forCompany companyId: String) async throws -> [Role] {
        guard !companyId.isEmpty else {
            throw ServiceError.invalidOperation("Company ID is missing")
        }
        
        return try await roleRepository.getRolesForCompany(companyId: companyId)
    }
    
    /// Check if a role with the given title exists
    /// - Parameters:
    ///   - title: Role title
    ///   - companyId: Company ID
    /// - Returns: True if the role exists
    func checkRoleExists(title: String, companyId: String) async throws -> Bool {
        guard !companyId.isEmpty else {
            throw ServiceError.invalidOperation("Company ID is missing")
        }
        
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        
        return try await roleRepository.checkRoleExists(title: title, companyId: companyId)
    }
    
    /// Add a new role
    /// - Parameters:
    ///   - title: Role title
    ///   - companyId: Company ID
    ///   - createdBy: Creator user ID
    /// - Returns: Created role
    func addRole(title: String, companyId: String, createdBy: String) async throws -> Role {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedTitle.isEmpty else {
            throw ServiceError.invalidOperation("Role title is missing")
        }
        
        guard !companyId.isEmpty else {
            throw ServiceError.invalidOperation("Company ID is missing")
        }
        
        guard !createdBy.isEmpty else {
            throw ServiceError.invalidOperation("Creator ID is missing")
        }
        
        // Check if the role already exists
        let exists = try await checkRoleExists(title: trimmedTitle, companyId: companyId)
        
        if exists {
            throw ServiceError.dataConflict("A role with the title '\(trimmedTitle)' already exists")
        }
        
        // Create a new role
        let newRole = Role(
            title: trimmedTitle,
            companyId: companyId,
            createdBy: createdBy,
            createdAt: Timestamp(date: Date())
        )
        
        // Add to repository
        return try await roleRepository.create(newRole)
    }
    
    /// Resolve role info from ID
    /// - Parameters:
    ///   - roleId: Role ID
    ///   - companyId: Company ID
    /// - Returns: Tuple with role ID and title
    func resolveRoleInfo(roleId: String, companyId: String) async throws -> (id: String, title: String) {
        return try await roleRepository.resolveRoleInfo(roleId: roleId, companyId: companyId)
    }
    
    /// Delete a role
    /// - Parameter id: Role ID
    func deleteRole(id: String) async throws {
        try await roleRepository.delete(id: id)
    }
    
    /// Update a role
    /// - Parameter role: Role to update
    /// - Returns: Updated role
    func updateRole(role: Role) async throws -> Role {
        return try await roleRepository.update(role)
    }
    
    /// Get all standard roles
    /// - Returns: Array of standard roles
    func getAllStandardRoles() async throws -> [Role] {
        return try await roleRepository.getAllStandardRoles()
    }
    
    /// Get active roles for a company
    /// - Parameter companyId: Company ID
    /// - Returns: Array of active roles
    func getActiveRoles(forCompany companyId: String) async throws -> [Role] {
        return try await fetchRoles(forCompany: companyId)
    }
    
    // MARK: - Legacy Completion Handler API Implementation
    
    func fetchRoles(forCompany companyId: String, completion: @escaping (Result<[Role], Error>) -> Void) {
        Task {
            do {
                let roles = try await fetchRoles(forCompany: companyId)
                
                await MainActor.run {
                    completion(.success(roles))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func checkRoleExists(title: String, companyId: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        Task {
            do {
                let exists = try await checkRoleExists(title: title, companyId: companyId)
                
                await MainActor.run {
                    completion(.success(exists))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func addRole(title: String, companyId: String, createdBy: String, completion: @escaping (Result<Role, Error>) -> Void) {
        Task {
            do {
                let role = try await addRole(title: title, companyId: companyId, createdBy: createdBy)
                
                await MainActor.run {
                    completion(.success(role))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func resolveRoleInfo(roleId: String, companyId: String, completion: @escaping (Result<(id: String, title: String), Error>) -> Void) {
        Task {
            do {
                let roleInfo = try await resolveRoleInfo(roleId: roleId, companyId: companyId)
                
                await MainActor.run {
                    completion(.success(roleInfo))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func deleteRole(id: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                try await deleteRole(id: id)
                
                await MainActor.run {
                    completion(.success(()))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func updateRole(role: Role, completion: @escaping (Result<Role, Error>) -> Void) {
        Task {
            do {
                let updatedRole = try await updateRole(role: role)
                
                await MainActor.run {
                    completion(.success(updatedRole))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func getAllStandardRoles(completion: @escaping (Result<[Role], Error>) -> Void) {
        Task {
            do {
                let standardRoles = try await getAllStandardRoles()
                
                await MainActor.run {
                    completion(.success(standardRoles))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func getActiveRoles(forCompany companyId: String, completion: @escaping (Result<[Role], Error>) -> Void) {
        fetchRoles(forCompany: companyId, completion: completion)
    }
    
    // MARK: - Helper Methods
    
    /// Convert a standard role name to ID
    /// - Parameter name: Role name
    /// - Returns: Role ID
    func standardRoleNameToId(name: String) -> String? {
        let standardRole = StandardRoles.allCases.first {
            $0.rawValue.lowercased() == name.lowercased()
        }
        
        guard let role = standardRole else {
            return nil
        }
        
        return "std_\(role.rawValue.lowercased().replacingOccurrences(of: " ", with: "_"))"
    }
    
    /// Check if a role ID is a standard role
    /// - Parameter roleId: Role ID
    /// - Returns: True if it's a standard role
    func isStandardRoleId(roleId: String) -> Bool {
        return roleId.hasPrefix("std_")
    }
}
