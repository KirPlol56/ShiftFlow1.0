//
//  ShiftRepository.swift
//  ShiftFlow
//
//  Created by Kirill P on 15/04/2025.
//  Updated by Kirill P on 23/05/2025.
//

import Foundation
import FirebaseFirestore

/// Query filter for shifts
struct ShiftQueryFilter {
    var companyId: String? = nil
    var dayOfWeek: Shift.DayOfWeek? = nil
    var assignedToUserId: String? = nil
    var status: Shift.ShiftStatus? = nil
    var assignedToRoleId: String? = nil
}

/// Protocol defining operations specific to shift data
protocol ShiftRepository: CRUDRepository, ListenableRepository, QueryableRepository, PaginatedRepositoryProtocol
    where Model == Shift, ID == String, QueryFilter == ShiftQueryFilter {
    
    /// Get shifts for a specific company
    func getShiftsForCompany(companyId: String) async throws -> [Shift]
    
    /// Get shifts assigned to a specific user
    func getShiftsForUser(userId: String, companyId: String) async throws -> [Shift]
    
    /// Update a task within a shift
    func updateTask(in shiftId: String, task: ShiftTask) async throws -> Shift
    
    /// Get shifts for the current week
    func getShiftsForWeek(companyId: String) async throws -> [Shift]
    
    /// Add a task to a shift
    func addTask(to shiftId: String, task: ShiftTask) async throws -> Shift
    
    /// Remove a task from a shift
    func removeTask(from shiftId: String, taskId: String) async throws -> Shift
    
    /// Mark a task as completed
    func markTaskCompleted(in shiftId: String, taskId: String, completedBy: String, photoURL: String?) async throws -> Shift
    
    /// Perform multiple updates on a shift in a single transaction
    func batchUpdateShift(shiftId: String, updates: [ShiftUpdate]) async throws -> Shift
    
    /// Perform updates on multiple shifts in a single transaction
    func batchUpdateShifts(updates: [ShiftBatchUpdate]) async throws -> [Shift]
}

/// Firestore implementation of ShiftRepository
actor FirestoreShiftRepository: ShiftRepository {
    typealias ListenerRegistration = FirebaseFirestore.ListenerRegistration
    
    private let db = Firestore.firestore()
    let entityName: String = "shifts"
    
    private var activeListeners: [String: ListenerRegistration] = [:]
    
    // MARK: - CRUD Operations
    
    func get(byId id: String) async throws -> Shift {
        do {
            let documentSnapshot = try await db.collection(entityName).document(id).getDocument()
            
            if !documentSnapshot.exists {
                throw ShiftFlowRepositoryError.documentNotFound
            }
            
            guard let shift = try? documentSnapshot.data(as: Shift.self) else {
                throw ShiftFlowRepositoryError.decodingFailed
            }
            
            return shift
        } catch let error as ShiftFlowRepositoryError {
            throw error
        } catch {
            throw ShiftFlowRepositoryError.networkError(error)
        }
    }
    
    func getAll() async throws -> [Shift] {
        do {
            // Add a safety limit
            let querySnapshot = try await db.collection(entityName).limit(to: 100).getDocuments()
            
            let shifts = querySnapshot.documents.compactMap { document -> Shift? in
                try? document.data(as: Shift.self)
            }
            
            return shifts
        } catch {
            throw ShiftFlowRepositoryError.networkError(error)
        }
    }
    
    func create(_ shift: Shift) async throws -> Shift {
        do {
            var newShift = shift
            
            // If shift doesn't have an ID, create a document reference to get an ID
            let documentRef: DocumentReference
            if let id = shift.id, !id.isEmpty {
                documentRef = db.collection(entityName).document(id)
            } else {
                documentRef = db.collection(entityName).document()
                // Update the shift with the new ID
                newShift.id = documentRef.documentID
            }
            
            try documentRef.setData(from: newShift)
            
            return newShift
        } catch {
            throw ShiftFlowRepositoryError.networkError(error)
        }
    }
    
    func update(_ shift: Shift) async throws -> Shift {
        do {
            guard let id = shift.id, !id.isEmpty else {
                throw ShiftFlowRepositoryError.invalidData("Invalid shift data")
            }
            
            let documentRef = db.collection(entityName).document(id)
            
            // Check if document exists
            let document = try await documentRef.getDocument()
            if !document.exists {
                throw ShiftFlowRepositoryError.documentNotFound
            }
            
            // Set the data with merge option to update only provided fields
            try documentRef.setData(from: shift, merge: true)
            
            return shift
        } catch let error as ShiftFlowRepositoryError {
            throw error
        } catch {
            throw ShiftFlowRepositoryError.networkError(error)
        }
    }
    
    func delete(id: String) async throws {
        do {
            let documentRef = db.collection(entityName).document(id)
            
            // Check if document exists
            let document = try await documentRef.getDocument()
            if !document.exists {
                throw ShiftFlowRepositoryError.documentNotFound
            }
            
            // Delete the document
            try await documentRef.delete()
        } catch let error as ShiftFlowRepositoryError {
            throw error
        } catch {
            throw ShiftFlowRepositoryError.networkError(error)
        }
    }
    
    // MARK: - ListenableRepository
    
    nonisolated func listen(forId id: String, completion: @escaping (Result<Shift?, Error>) -> Void) -> ListenerRegistration {
        let documentRef = Firestore.firestore().collection(entityName).document(id)
        let listener = documentRef.addSnapshotListener { documentSnapshot, error in
            if let error = error {
                completion(.failure(error))
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
                let shift = try document.data(as: Shift.self)
                completion(.success(shift))
            } catch {
                completion(.failure(error))
            }
        }
        
        // Instead of directly modifying actor-isolated state from non-isolated method
        // We'll use a Task to properly isolate the mutation
        Task { [weak self] in
            await self?.addActiveListener(id: id, registration: listener)
        }
        
        return listener
    }
    // helper method for adding listeners
    private func addActiveListener(id: String, registration: ListenerRegistration) {
        activeListeners[id] = registration
    }

    nonisolated func listenAll(completion: @escaping (Result<[Shift], Error>) -> Void) -> ListenerRegistration {
        let collectionRef = Firestore.firestore().collection(entityName).limit(to: 100)
        let listener = collectionRef.addSnapshotListener { querySnapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let querySnapshot = querySnapshot else {
                completion(.success([]))
                return
            }
            
            let shifts = querySnapshot.documents.compactMap { documentSnapshot -> Shift? in
                try? documentSnapshot.data(as: Shift.self)
            }
            
            completion(.success(shifts))
        }
        
        return listener
    }
    
    nonisolated func stopListening(_ registration: ListenerRegistration) {
        registration.remove()
        
        // Use Task to modify actor state
        Task { [weak self] in
            await self?.removeActiveListener(registration)
        }
    }

    // Add a helper method for removing listeners
    private func removeActiveListener(_ registration: ListenerRegistration) {
        for (id, listener) in activeListeners where listener === registration {
            activeListeners.removeValue(forKey: id)
            break
        }
    }
    // MARK: - QueryableRepository
    
    func query(filter: ShiftQueryFilter) async throws -> [Shift] {
        do {
            // Start building the query
            var query = db.collection(entityName)
            
            // Apply filters
            if let companyId = filter.companyId {
                query = query.whereField("companyId", isEqualTo: companyId) as! CollectionReference
            }
            
            if let dayOfWeek = filter.dayOfWeek {
                query = query.whereField("dayOfWeek", isEqualTo: dayOfWeek.rawValue) as! CollectionReference
            }
            
            if let userId = filter.assignedToUserId {
                query = query.whereField("assignedToUIDs", arrayContains: userId) as! CollectionReference
            }
            
            if let status = filter.status {
                query = query.whereField("status", isEqualTo: status.rawValue) as! CollectionReference
            }
            
            if let roleId = filter.assignedToRoleId {
                query = query.whereField("assignedRoleIds", arrayContains: roleId) as! CollectionReference
            }
            
            // Apply limits
            query = query.limit(to: 100) as! CollectionReference
            
            // Get documents
            let querySnapshot = try await query.getDocuments()
            
            let shifts = querySnapshot.documents.compactMap { document -> Shift? in
                try? document.data(as: Shift.self)
            }
            
            return shifts
        } catch {
            throw ShiftFlowRepositoryError.networkError(error)
        }
    }
    
    // MARK: - PaginatedRepositoryProtocol
    
    func queryPaginated(filter: ShiftQueryFilter, pageSize: Int, lastDocument: DocumentSnapshot?) async throws -> (items: [Shift], lastDocument: DocumentSnapshot?) {
        do {
            // Start building the query
            var query = db.collection(entityName)
            
            // Apply filters
            if let companyId = filter.companyId {
                query = query.whereField("companyId", isEqualTo: companyId) as! CollectionReference
            }
            
            if let dayOfWeek = filter.dayOfWeek {
                query = query.whereField("dayOfWeek", isEqualTo: dayOfWeek.rawValue) as! CollectionReference
            }
            
            if let userId = filter.assignedToUserId {
                query = query.whereField("assignedToUIDs", arrayContains: userId) as! CollectionReference
            }
            
            if let status = filter.status {
                query = query.whereField("status", isEqualTo: status.rawValue) as! CollectionReference
            }
            
            if let roleId = filter.assignedToRoleId {
                query = query.whereField("assignedRoleIds", arrayContains: roleId) as! CollectionReference
            }
            
            // Apply sorting (by start time descending)
            query = query.order(by: "startTime", descending: true) as! CollectionReference
            
            // Apply pagination
            if let lastDocument = lastDocument {
                query = query.start(afterDocument: lastDocument) as! CollectionReference
            }
            
            // Apply page size
            query = query.limit(to: pageSize) as! CollectionReference
            
            // Execute query
            let querySnapshot = try await query.getDocuments()
            
            // Parse results
            let shifts = querySnapshot.documents.compactMap { document -> Shift? in
                try? document.data(as: Shift.self)
            }
            
            // Get the last document for next pagination
            let lastDoc = querySnapshot.documents.last
            
            return (items: shifts, lastDocument: lastDoc)
        } catch {
            throw ShiftFlowRepositoryError.networkError(error)
        }
    }
    
    // MARK: - ShiftRepository specific methods
    
    func getShiftsForCompany(companyId: String) async throws -> [Shift] {
        let filter = ShiftQueryFilter(companyId: companyId)
        return try await query(filter: filter)
    }
    
    func getShiftsForUser(userId: String, companyId: String) async throws -> [Shift] {
        let filter = ShiftQueryFilter(companyId: companyId, assignedToUserId: userId)
        return try await query(filter: filter)
    }
    
    func getShiftsForWeek(companyId: String) async throws -> [Shift] {
        let filter = ShiftQueryFilter(companyId: companyId)
        return try await query(filter: filter)
    }
    
    func updateTask(in shiftId: String, task: ShiftTask) async throws -> Shift {
        do {
            // Get current shift
            let shift = try await get(byId: shiftId)
            
            // Update the task
            var updatedShift = shift
            if let index = updatedShift.tasks.firstIndex(where: { $0.id == task.id }) {
                updatedShift.tasks[index] = task
            } else {
                throw ShiftFlowRepositoryError.documentNotFound
            }
            
            // Save updated shift
            return try await update(updatedShift)
        } catch {
            throw ShiftFlowRepositoryError.operationFailed("Failed to update task: \(error.localizedDescription)")
        }
    }
    
    func addTask(to shiftId: String, task: ShiftTask) async throws -> Shift {
        do {
            // Get current shift
            let shift = try await get(byId: shiftId)
            
            // Create a new task with ID if needed
            var newTask = task
            if newTask.id == nil || newTask.id!.isEmpty {
                newTask.id = UUID().uuidString
            }
            
            // Add the task
            var updatedShift = shift
            updatedShift.tasks.append(newTask)
            
            // Save updated shift
            return try await update(updatedShift)
        } catch {
            throw ShiftFlowRepositoryError.operationFailed("Failed to add task: \(error.localizedDescription)")
        }
    }
    
    func removeTask(from shiftId: String, taskId: String) async throws -> Shift {
        do {
            // Get current shift
            let shift = try await get(byId: shiftId)
            
            // Remove the task
            var updatedShift = shift
            updatedShift.tasks.removeAll { $0.id == taskId }
            
            // Save updated shift
            return try await update(updatedShift)
        } catch {
            throw ShiftFlowRepositoryError.operationFailed("Failed to remove task: \(error.localizedDescription)")
        }
    }
    
    func markTaskCompleted(in shiftId: String, taskId: String, completedBy: String, photoURL: String?) async throws -> Shift {
        do {
            // Get current shift
            let shift = try await get(byId: shiftId)
            
            // Find and update the task
            var updatedShift = shift
            if let index = updatedShift.tasks.firstIndex(where: { $0.id == taskId }) {
                updatedShift.tasks[index].isCompleted = true
                updatedShift.tasks[index].completedBy = completedBy
                updatedShift.tasks[index].completedAt = Timestamp(date: Date())
                updatedShift.tasks[index].photoURL = photoURL
            } else {
                throw ShiftFlowRepositoryError.documentNotFound
            }
            
            // Save updated shift
            return try await update(updatedShift)
        } catch {
            throw ShiftFlowRepositoryError.operationFailed("Failed to mark task as completed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Batch Update Operations
    
    func batchUpdateShift(shiftId: String, updates: [ShiftUpdate]) async throws -> Shift {
        do {
            // Get current shift
            let shift = try await get(byId: shiftId)
            var updatedShift = shift
            
            // Apply all updates
            for update in updates {
                switch update {
                case .addTask(let task):
                    var newTask = task
                    if newTask.id == nil || newTask.id!.isEmpty {
                        newTask.id = UUID().uuidString
                    }
                    updatedShift.tasks.append(newTask)
                    
                case .updateTask(let task):
                    if let index = updatedShift.tasks.firstIndex(where: { $0.id == task.id }) {
                        updatedShift.tasks[index] = task
                    }
                    
                case .removeTask(let taskId):
                    updatedShift.tasks.removeAll { $0.id == taskId }
                    
                case .markTaskCompleted(let taskId, let completedBy, let photoURL):
                    if let index = updatedShift.tasks.firstIndex(where: { $0.id == taskId }) {
                        updatedShift.tasks[index].isCompleted = true
                        updatedShift.tasks[index].completedBy = completedBy
                        updatedShift.tasks[index].completedAt = Timestamp(date: Date())
                        updatedShift.tasks[index].photoURL = photoURL
                    }
                    
                case .updateAssignees(let userIds):
                    updatedShift.assignedToUIDs = userIds
                    
                case .updateShiftStatus(let status):
                    updatedShift.status = status
                    
                case .updateShiftTime(let startTime, let endTime):
                    updatedShift.startTime = Timestamp(date: startTime)
                    updatedShift.endTime = Timestamp(date: endTime)
                }
            }
            
            // Save all changes in a single update operation
            return try await update(updatedShift)
        } catch {
            throw ShiftFlowRepositoryError.operationFailed("Batch update failed: \(error.localizedDescription)")
        }
    }
    
    func batchUpdateShifts(updates: [ShiftBatchUpdate]) async throws -> [Shift] {
        do {
            // Use Firestore batch for true atomic operations across documents
            let batch = db.batch()
            var updatedShifts: [Shift] = []
            
            // Process each shift update
            for shiftUpdate in updates {
                // Get current shift
                let shift = try await get(byId: shiftUpdate.shiftId)
                var updatedShift = shift
                
                // Apply all updates for this shift
                for update in shiftUpdate.updates {
                    switch update {
                    case .addTask(let task):
                        var newTask = task
                        if newTask.id == nil || newTask.id!.isEmpty {
                            newTask.id = UUID().uuidString
                        }
                        updatedShift.tasks.append(newTask)
                        
                    case .updateTask(let task):
                        if let index = updatedShift.tasks.firstIndex(where: { $0.id == task.id }) {
                            updatedShift.tasks[index] = task
                        }
                        
                    case .removeTask(let taskId):
                        updatedShift.tasks.removeAll { $0.id == taskId }
                        
                    case .markTaskCompleted(let taskId, let completedBy, let photoURL):
                        if let index = updatedShift.tasks.firstIndex(where: { $0.id == taskId }) {
                            updatedShift.tasks[index].isCompleted = true
                            updatedShift.tasks[index].completedBy = completedBy
                            updatedShift.tasks[index].completedAt = Timestamp(date: Date())
                            updatedShift.tasks[index].photoURL = photoURL
                        }
                        
                    case .updateAssignees(let userIds):
                        updatedShift.assignedToUIDs = userIds
                        
                    case .updateShiftStatus(let status):
                        updatedShift.status = status
                        
                    case .updateShiftTime(let startTime, let endTime):
                        updatedShift.startTime = Timestamp(date: startTime)
                        updatedShift.endTime = Timestamp(date: endTime)
                    }
                }
                
                // Add to batch
                let docRef = db.collection(entityName).document(updatedShift.id!)
                do {
                    try batch.setData(from: updatedShift, forDocument: docRef, merge: true)
                } catch {
                    throw ShiftFlowRepositoryError.encodingFailed
                }
                
                updatedShifts.append(updatedShift)
            }
            
            // Commit the batch
            try await batch.commit()
            
            return updatedShifts
        } catch {
            throw ShiftFlowRepositoryError.operationFailed("Multi-shift batch update failed: \(error.localizedDescription)")
        }
    }
}
