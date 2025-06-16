//
//  RoleRepository.swift
//  ShiftFlow
//
//  Created by Kirill P on 15/04/2025.
//

import Foundation
import FirebaseFirestore

/// Protocol defining operations specific to role data
protocol RoleRepository: CRUDRepository where Model == Role, ID == String {
    /// Get roles for a specific company
    func getRolesForCompany(companyId: String) async throws -> [Role]
    
    /// Check if a role with the given title exists in a company
    func checkRoleExists(title: String, companyId: String) async throws -> Bool
    
    /// Get a standard role by ID
    func getStandardRoleById(id: String) async throws -> Role?
    
    /// Get all standard roles
    func getAllStandardRoles() async throws -> [Role]
    
    /// Resolve a role ID to a role title, handling standard and custom roles
    func resolveRoleInfo(roleId: String, companyId: String) async throws -> (id: String, title: String)
}

/// Firestore implementation of RoleRepository
actor FirestoreRoleRepository: RoleRepository {
    private let db = Firestore.firestore()
    let entityName: String = "roles"
    
    // MARK: - CRUD Operations
    
    func get(byId id: String) async throws -> Role {
        // Check if this is a standard role ID
        if id.hasPrefix("std_") {
            let standardRoleTitle = String(id.dropFirst(4))
                .replacingOccurrences(of: "_", with: " ")
            
            // Try to find matching standard role
            if let standardRole = StandardRoles.allCases.first(where: {
                $0.rawValue.lowercased().replacingOccurrences(of: " ", with: "_") == standardRoleTitle.lowercased()
            }) {
                // Return the standard role
                let role = Role.fromStandardRole(standardRole, companyId: "")
                return role
            }
        }
        
        // Otherwise, fetch from Firestore
        do {
            let documentSnapshot = try await db.collection(entityName).document(id).getDocument()
            
            if !documentSnapshot.exists {
                throw ShiftFlowRepositoryError.documentNotFound
            }
            
            guard let role = try? documentSnapshot.data(as: Role.self) else {
                throw ShiftFlowRepositoryError.decodingFailed
            }
            
            return role
        } catch let error as ShiftFlowRepositoryError {
            throw error
        } catch {
            throw ShiftFlowRepositoryError.networkError(error)
        }
    }
    
    func getAll() async throws -> [Role] {
        do {
            let querySnapshot = try await db.collection(entityName).limit(to: 100).getDocuments()
            
            let roles = querySnapshot.documents.compactMap { document -> Role? in
                try? document.data(as: Role.self)
            }
            
            return roles
        } catch {
            throw ShiftFlowRepositoryError.networkError(error)
        }
    }
    
    func create(_ role: Role) async throws -> Role {
        do {
            // Check if this is a standard role
            if role.isStandardRole {
                // For standard roles, no need to save to Firestore
                // Instead, return a proper Role object with ID
                if let standardRole = StandardRoles.allCases.first(where: { $0.rawValue == role.title }) {
                    return Role.fromStandardRole(standardRole, companyId: role.companyId)
                }
            }
            
            // Ensure the role has a company ID
            guard !role.companyId.isEmpty else {
                throw ShiftFlowRepositoryError.invalidData("Invalid role data")
            }
            
            // Check if a role with this title already exists
            let exists = try await checkRoleExists(title: role.title, companyId: role.companyId)
            if exists {
                throw ShiftFlowRepositoryError.operationFailed("A role with this title already exists")
            }
            
            // Create a new role
            var newRole = role
            
            // If role doesn't have an ID, create a document reference to get an ID
            let documentRef: DocumentReference
            if let id = role.id, !id.isEmpty {
                documentRef = db.collection(entityName).document(id)
            } else {
                documentRef = db.collection(entityName).document()
                // Update the role with the new ID
                newRole.id = documentRef.documentID
            }
            
            try documentRef.setData(from: newRole)
            
            return newRole
        } catch let error as ShiftFlowRepositoryError {
            throw error
        } catch {
            throw ShiftFlowRepositoryError.networkError(error)
        }
    }
    
    func update(_ role: Role) async throws -> Role {
        do {
            // Standard roles can't be updated
            if role.isStandardRoleById {
                throw ShiftFlowRepositoryError.operationFailed("Standard roles cannot be modified")
            }
            
            guard let id = role.id, !id.isEmpty else {
                throw ShiftFlowRepositoryError.invalidData("Company ID is required")
            }
            
            let documentRef = db.collection(entityName).document(id)
            
            // Check if document exists
            let document = try await documentRef.getDocument()
            if !document.exists {
                throw ShiftFlowRepositoryError.documentNotFound
            }
            
            // Update with merge option
            try documentRef.setData(from: role, merge: true)
            
            return role
        } catch let error as ShiftFlowRepositoryError {
            throw error
        } catch {
            throw ShiftFlowRepositoryError.networkError(error)
        }
    }
    
    func delete(id: String) async throws {
        do {
            // Cannot delete standard roles
            if id.hasPrefix("std_") {
                throw ShiftFlowRepositoryError.operationFailed("Standard roles cannot be deleted")
            }
            
            let documentRef = db.collection(entityName).document(id)
            
            // Check if document exists
            let document = try await documentRef.getDocument()
            if !document.exists {
                throw ShiftFlowRepositoryError.documentNotFound
            }
            
            try await documentRef.delete()
        } catch let error as ShiftFlowRepositoryError {
            throw error
        } catch {
            throw ShiftFlowRepositoryError.networkError(error)
        }
    }
    
    // MARK: - Role-specific Operations
    
    func getRolesForCompany(companyId: String) async throws -> [Role] {
        do {
            let querySnapshot = try await db.collection(entityName)
                .whereField("companyId", isEqualTo: companyId)
                .getDocuments()
            
            let roles = querySnapshot.documents.compactMap { document -> Role? in
                try? document.data(as: Role.self)
            }
            
            // Also add standard roles
            let standardRoles = try await getAllStandardRoles()
            
            // Combine and return
            return roles + standardRoles
        } catch {
            throw ShiftFlowRepositoryError.networkError(error)
        }
    }
    
    func checkRoleExists(title: String, companyId: String) async throws -> Bool {
        do {
            // Check if this is a standard role
            let standardRoleExists = StandardRoles.allCases.contains {
                $0.rawValue.lowercased() == title.trimmingCharacters(in: .whitespaces).lowercased()
            }
            
            if standardRoleExists {
                return true
            }
            
            // Otherwise, check Firestore
            let querySnapshot = try await db.collection(entityName)
                .whereField("companyId", isEqualTo: companyId)
                .whereField("title", isEqualTo: title.trimmingCharacters(in: .whitespaces))
                .limit(to: 1)
                .getDocuments()
            
            return !querySnapshot.isEmpty
        } catch {
            throw ShiftFlowRepositoryError.networkError(error)
        }
    }
    
    func getStandardRoleById(id: String) async throws -> Role? {
        if id.hasPrefix("std_") {
            let roleName = String(id.dropFirst(4))
                .replacingOccurrences(of: "_", with: " ")
            
            // Find matching standard role
            if let standardRole = StandardRoles.allCases.first(where: {
                $0.rawValue.lowercased().replacingOccurrences(of: " ", with: "_") == roleName.lowercased()
            }) {
                // Return a role object for this standard role
                return Role.fromStandardRole(standardRole, companyId: "")
            }
        }
        
        return nil
    }
    
    func getAllStandardRoles() async throws -> [Role] {
        // Convert all standard roles to Role objects
        return StandardRoles.allCases.map { standardRole in
            Role.fromStandardRole(standardRole, companyId: "")
        }
    }
    
    func resolveRoleInfo(roleId: String, companyId: String) async throws -> (id: String, title: String) {
        if roleId.hasPrefix("std_") {
            // This is a standard role ID
            let title = String(roleId.dropFirst(4))
                .replacingOccurrences(of: "_", with: " ")
                .split(separator: "_")
                .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
                .joined(separator: " ")
            
            return (id: roleId, title: title)
        } else {
            // This is a custom role ID - fetch from Firestore
            do {
                let role = try await get(byId: roleId)
                return (id: roleId, title: role.title)
            } catch ShiftFlowRepositoryError.documentNotFound {
                throw ShiftFlowRepositoryError.operationFailed("Role not found")
            } catch {
                throw error
            }
        }
    }
}
