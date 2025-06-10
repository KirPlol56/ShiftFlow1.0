//
//  UserRepository.swift
//  ShiftFlow
//
//  Created by Kirill P on 15/04/2025.
//

import Foundation
import FirebaseFirestore
import Combine

/// Protocol defining operations specific to user data
protocol UserRepository: CRUDRepository, ListenableRepository where Model == User, ID == String {
    /// Fetch users belonging to a specific company
    func getTeamMembers(companyId: String) async throws -> [User]
    
    /// Fetch users with a specific role in a company
    func getUsersByRole(companyId: String, roleId: String) async throws -> [User]
    
    /// Check if a user with a specific email exists
    func checkUserExists(email: String) async throws -> Bool
}

/// Firestore implementation of UserRepository
actor FirestoreUserRepository: UserRepository {
    typealias ListenerRegistration = FirebaseFirestore.ListenerRegistration
    
    private let db = Firestore.firestore()
    let entityName: String = "users"
    
    private var activeListeners: [String: ListenerRegistration] = [:]
    
    /// Get a user by ID
    func get(byId id: String) async throws -> User {
        do {
            let documentSnapshot = try await db.collection(entityName).document(id).getDocument()
            
            if !documentSnapshot.exists {
                throw ShiftFlowRepositoryError.documentNotFound
            }
            
            guard let user = try? documentSnapshot.data(as: User.self) else {
                throw ShiftFlowRepositoryError.decodingFailed
            }
            
            return user
        } catch let error as ShiftFlowRepositoryError {
            throw error
        } catch {
            throw ShiftFlowRepositoryError.networkError(error)
        }
    }
    
    /// Get all users (limit to a reasonable number for safety)
    func getAll() async throws -> [User] {
        do {
            // Add a safety limit to prevent fetching too many users
            let querySnapshot = try await db.collection(entityName).limit(to: 100).getDocuments()
            
            let users = querySnapshot.documents.compactMap { document -> User? in
                try? document.data(as: User.self)
            }
            
            return users
        } catch {
            throw ShiftFlowRepositoryError.networkError(error)
        }
    }
    
    /// Create a new user
    func create(_ user: User) async throws -> User {
        do {
            guard !user.uid.isEmpty else {
                throw ShiftFlowRepositoryError.invalidData("User ID cannot be empty")
            }
            
            // Use the user's UID as the document ID
            let documentRef = db.collection(entityName).document(user.uid)
            
            try documentRef.setData(from: user)
            
            // Return the user with any server-generated fields if needed
            return user
        } catch let error as ShiftFlowRepositoryError {
            throw error
        // Fix: Replace 'error' with '_' since it's not used
        } catch _ as EncodingError {
            throw ShiftFlowRepositoryError.encodingFailed
        } catch {
            throw ShiftFlowRepositoryError.unexpectedError(error)
        }
    }
    
    /// Update an existing user
    func update(_ user: User) async throws -> User {
        do {
            guard !user.uid.isEmpty else {
                throw ShiftFlowRepositoryError.invalidData("User ID cannot be empty")
            }
            
            let documentRef = db.collection(entityName).document(user.uid)
            
            // Check if document exists
            let document = try await documentRef.getDocument()
            if !document.exists {
                throw ShiftFlowRepositoryError.documentNotFound
            }
            
            // Set the data with merge option to update only provided fields
            try documentRef.setData(from: user, merge: true)
            
            return user
        } catch let error as ShiftFlowRepositoryError {
            throw error
        // Fix: Replace 'error' with '_' since it's not used
        } catch _ as EncodingError {
            throw ShiftFlowRepositoryError.encodingFailed
        } catch {
            throw ShiftFlowRepositoryError.networkError(error)
        }
    }
    
    /// Delete a user by ID
    func delete(id: String) async throws {
        do {
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
    
    nonisolated func listen(forId id: String, completion: @escaping (Result<User?, Error>) -> Void) -> ListenerRegistration {
        let listenerKey = "user_\(id)"
        
        // Access non-isolated firestore
        let db = Firestore.firestore()
        let entityName = self.entityName // Capture the entityName
        
        let listener = db.collection(entityName).document(id)
            .addSnapshotListener { documentSnapshot, error in
                if let error = error {
                    completion(.failure(ShiftFlowRepositoryError.networkError(error)))
                    return
                }
                
                guard let document = documentSnapshot else {
                    completion(.success(nil))
                    return
                }
                
                if !document.exists {
                    completion(.success(nil))
                    return
                }
                
                do {
                    let user = try document.data(as: User.self)
                    completion(.success(user))
                } catch {
                    completion(.failure(ShiftFlowRepositoryError.decodingFailed))
                }
            }
        
        // Store the listener via Task
        Task { [weak self] in
            await self?.storeListener(listener, forKey: listenerKey)
        }
        
        return listener
    }

    // For listenAll method
    nonisolated func listenAll(completion: @escaping (Result<[User], Error>) -> Void) -> ListenerRegistration {
        let listenerKey = "all_users"
        
        // Access non-isolated firestore
        let db = Firestore.firestore()
        let entityName = self.entityName // Capture the entityName
        
        let listener = db.collection(entityName)
            .limit(to: 100) // Safety limit
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    completion(.failure(ShiftFlowRepositoryError.networkError(error)))
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    completion(.success([]))
                    return
                }
                
                let users = documents.compactMap { document -> User? in
                    try? document.data(as: User.self)
                }
                
                completion(.success(users))
            }
        
        // Store the listener via Task
        Task { [weak self] in
            await self?.storeListener(listener, forKey: listenerKey)
        }
        
        return listener
    }

    // For stopListening method
    nonisolated func stopListening(_ registration: ListenerRegistration) {
        registration.remove()
        
        // Remove from active listeners via Task
        Task { [weak self] in
            await self?.removeListener(registration)
        }
    }

    // Helper methods for actor-isolated state access
    func storeListener(_ listener: ListenerRegistration, forKey key: String) {
        activeListeners[key] = listener
    }

    func removeListener(_ registration: ListenerRegistration) {
        for (key, listener) in activeListeners where listener === registration {
            activeListeners.removeValue(forKey: key)
            break
        }
    }
    
    /// Get team members for a company
    func getTeamMembers(companyId: String) async throws -> [User] {
        do {
            guard !companyId.isEmpty else {
                throw ShiftFlowRepositoryError.invalidData("Company ID cannot be empty")
            }
            
            let querySnapshot = try await db.collection(entityName)
                .whereField("companyId", isEqualTo: companyId)
                .getDocuments()
            
            let users = querySnapshot.documents.compactMap { document -> User? in
                try? document.data(as: User.self)
            }
            
            return users
        } catch let error as ShiftFlowRepositoryError {
            throw error
        } catch {
            throw ShiftFlowRepositoryError.networkError(error)
        }
    }
    
    /// Get users with a specific role in a company
    func getUsersByRole(companyId: String, roleId: String) async throws -> [User] {
        do {
            guard !companyId.isEmpty else {
                throw ShiftFlowRepositoryError.invalidData("Company ID cannot be empty")
            }
            
            guard !roleId.isEmpty else {
                throw ShiftFlowRepositoryError.invalidData("Role ID cannot be empty")
            }
            
            let querySnapshot = try await db.collection(entityName)
                .whereField("companyId", isEqualTo: companyId)
                .whereField("roleId", isEqualTo: roleId)
                .getDocuments()
            
            let users = querySnapshot.documents.compactMap { document -> User? in
                try? document.data(as: User.self)
            }
            
            return users
        } catch let error as ShiftFlowRepositoryError {
            throw error
        } catch {
            throw ShiftFlowRepositoryError.networkError(error)
        }
    }
    
    /// Check if a user with the given email exists
    func checkUserExists(email: String) async throws -> Bool {
        do {
            guard !email.isEmpty else {
                throw ShiftFlowRepositoryError.invalidData("Email cannot be empty")
            }
            
            let querySnapshot = try await db.collection(entityName)
                .whereField("email", isEqualTo: email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))
                .limit(to: 1)
                .getDocuments()
            
            return !querySnapshot.isEmpty
        } catch let error as ShiftFlowRepositoryError {
            throw error
        } catch {
            throw ShiftFlowRepositoryError.networkError(error)
        }
    }
    
    // MARK: - AsyncStream Support for Modern Swift Concurrency
    
    /// Create an AsyncStream for a specific user
    /// - Parameter userId: User ID
    /// - Returns: AsyncThrowingStream that emits the user or nil
    func streamUser(userId: String) -> AsyncThrowingStream<User?, Error> {
        return AsyncThrowingStream { continuation in
            let listener = listen(forId: userId) { result in
                switch result {
                case .success(let user):
                    continuation.yield(user)
                case .failure(let error):
                    continuation.finish(throwing: error)
                }
            }
            
            continuation.onTermination = { @Sendable _ in
                self.stopListening(listener)
            }
        }
    }
    
    /// Create an AsyncStream for all users
    /// - Returns: AsyncThrowingStream that emits arrays of users
    func streamAllUsers() -> AsyncThrowingStream<[User], Error> {
        return AsyncThrowingStream { continuation in
            let listener = listenAll { result in
                switch result {
                case .success(let users):
                    continuation.yield(users)
                case .failure(let error):
                    continuation.finish(throwing: error)
                }
            }
            
            continuation.onTermination = { @Sendable _ in
                self.stopListening(listener)
            }
        }
    }
}
