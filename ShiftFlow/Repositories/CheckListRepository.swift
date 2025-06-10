//
//  CheckListRepository.swift
//  ShiftFlow
//
//  Created by Kirill P on 15/04/2025.
//


import Foundation
import FirebaseFirestore

/// Query filter for checklists
struct CheckListQueryFilter {
    var companyId: String? = nil
    var createdByUID: String? = nil
    var shiftSection: CheckList.ShiftSection? = nil
    var assignedRoleId: String? = nil
    var activeToday: Bool? = nil // Only get checklists active for today
}

/// Protocol defining operations specific to checklist data
protocol CheckListRepository: CRUDRepository, QueryableRepository
    where Model == CheckList, ID == String, QueryFilter == CheckListQueryFilter {
    
    /// Get checklists for a specific company
    func getCheckListsForCompany(companyId: String) async throws -> [CheckList]
    
    /// Get checklists assigned to a specific role
    func getCheckListsForRole(roleId: String, companyId: String) async throws -> [CheckList]
    
    /// Get checklists for today
    func getCheckListsForToday(companyId: String) async throws -> [CheckList]
    
    /// Add task to a checklist
    func addTask(to checkListId: String, task: CheckListTask) async throws -> CheckList
    
    /// Remove task from a checklist
    func removeTask(from checkListId: String, taskId: String) async throws -> CheckList
    
    /// Update task in a checklist
    func updateTask(in checkListId: String, task: CheckListTask) async throws -> CheckList
    
    /// Assign roles to a checklist
    func assignRoles(to checkListId: String, roleIds: [String]) async throws -> CheckList
}

/// Firestore implementation of CheckListRepository
actor FirestoreCheckListRepository: CheckListRepository {
    private let db = Firestore.firestore()
    let entityName: String = "checkLists"
    
    // MARK: - CRUD Operations
    
    func get(byId id: String) async throws -> CheckList {
        do {
            let documentSnapshot = try await db.collection(entityName).document(id).getDocument()
            
            if !documentSnapshot.exists {
                throw ShiftFlowRepositoryError.documentNotFound
            }
            
            guard let checkList = try? documentSnapshot.data(as: CheckList.self) else {
                throw ShiftFlowRepositoryError.decodingFailed
            }
            
            return checkList
        } catch let error as ShiftFlowRepositoryError {
            throw error
        } catch {
            throw ShiftFlowRepositoryError.networkError(error)
        }
    }
    
    func getAll() async throws -> [CheckList] {
        do {
            let querySnapshot = try await db.collection(entityName).limit(to: 100).getDocuments()
            
            let checkLists = querySnapshot.documents.compactMap { document -> CheckList? in
                try? document.data(as: CheckList.self)
            }
            
            return checkLists
        } catch {
            throw ShiftFlowRepositoryError.networkError(error)
        }
    }
    
    func create(_ checkList: CheckList) async throws -> CheckList {
        do {
            var newCheckList = checkList
            
            // Ensure required fields are present
            guard !newCheckList.companyId.isEmpty else {
                throw ShiftFlowRepositoryError.invalidData("Invalid data")
            }
            
            guard !newCheckList.createdByUID.isEmpty else {
                throw ShiftFlowRepositoryError.invalidData("Company ID is required")
            }
            
            // If checklist doesn't have an ID, create a document reference to get an ID
            let documentRef: DocumentReference
            if let id = checkList.id, !id.isEmpty {
                documentRef = db.collection(entityName).document(id)
            } else {
                documentRef = db.collection(entityName).document()
                // Update the checklist with the new ID
                newCheckList.id = documentRef.documentID
            }
            
            try documentRef.setData(from: newCheckList)
            
            return newCheckList
        } catch {
            throw ShiftFlowRepositoryError.networkError(error)
        }
    }
    
    func update(_ checkList: CheckList) async throws -> CheckList {
        do {
            guard let id = checkList.id, !id.isEmpty else {
                throw ShiftFlowRepositoryError.invalidData("Check list ID is required")
            }
            
            let documentRef = db.collection(entityName).document(id)
            
            // Check if document exists
            let document = try await documentRef.getDocument()
            if !document.exists {
                throw ShiftFlowRepositoryError.documentNotFound
            }
            
            // Update with merge option
            try documentRef.setData(from: checkList, merge: true)
            
            return checkList
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
            
            try await documentRef.delete()
        } catch let error as ShiftFlowRepositoryError {
            throw error
        } catch {
            throw ShiftFlowRepositoryError.networkError(error)
        }
    }
    
    // MARK: - Queryable Repository
    
    func query(filter: CheckListQueryFilter) async throws -> [CheckList] {
        do {
            var query: Query = db.collection(entityName)
            
            // Apply filters if provided
            if let companyId = filter.companyId {
                query = query.whereField("companyId", isEqualTo: companyId)
            }
            
            if let createdByUID = filter.createdByUID {
                query = query.whereField("createdByUID", isEqualTo: createdByUID)
            }
            
            if let shiftSection = filter.shiftSection {
                query = query.whereField("shiftSection", isEqualTo: shiftSection.rawValue)
            }
            
            let querySnapshot = try await query.getDocuments()
            
            var checkLists = querySnapshot.documents.compactMap { document -> CheckList? in
                try? document.data(as: CheckList.self)
            }
            
            // Apply client-side filtering for roleId if provided
            if let roleId = filter.assignedRoleId {
                checkLists = checkLists.filter { checkList in
                    guard let assignedRoleIds = checkList.assignedRoleIds else { return false }
                    return assignedRoleIds.contains(roleId)
                }
            }
            
            // Filter for active today if requested
            if let activeToday = filter.activeToday, activeToday {
                checkLists = checkLists.filter { $0.frequency.isActiveToday() }
            }
            
            return checkLists
        } catch {
            throw ShiftFlowRepositoryError.networkError(error)
        }
    }
    
    // MARK: - CheckList-specific Operations
    
    func getCheckListsForCompany(companyId: String) async throws -> [CheckList] {
        let filter = CheckListQueryFilter(companyId: companyId)
        return try await query(filter: filter)
    }
    
    func getCheckListsForRole(roleId: String, companyId: String) async throws -> [CheckList] {
        let filter = CheckListQueryFilter(companyId: companyId, assignedRoleId: roleId)
        return try await query(filter: filter)
    }
    
    func getCheckListsForToday(companyId: String) async throws -> [CheckList] {
        let filter = CheckListQueryFilter(companyId: companyId, activeToday: true)
        return try await query(filter: filter)
    }
    
    func addTask(to checkListId: String, task: CheckListTask) async throws -> CheckList {
        do {
            let documentRef = db.collection(entityName).document(checkListId)
            
            var checkList = try await get(byId: checkListId)
            
            // Ensure task has a valid ID
            var newTask = task
            if newTask.id == nil || newTask.id!.isEmpty {
                newTask.id = UUID().uuidString
            }
            
            // Add the task to the checklist
            checkList.tasks.append(newTask)
            
            // Update using transaction
            try await db.runTransaction { transaction, errorPointer in
                do {
                    let checkListDoc = try transaction.getDocument(documentRef)
                    guard var currentCheckList = try? checkListDoc.data(as: CheckList.self) else {
                        throw ShiftFlowRepositoryError.decodingFailed
                    }
                    
                    currentCheckList.tasks.append(newTask)
                    try transaction.setData(from: currentCheckList, forDocument: documentRef, merge: true)
                    
                    checkList = currentCheckList
                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }
            
            return checkList
        } catch let error as ShiftFlowRepositoryError {
            throw error
        } catch {
            throw ShiftFlowRepositoryError.networkError(error)
        }
    }
    
    func removeTask(from checkListId: String, taskId: String) async throws -> CheckList {
        do {
            let documentRef = db.collection(entityName).document(checkListId)
            
            var checkList = try await get(byId: checkListId)
            
            // Verify the task exists
            guard checkList.tasks.contains(where: { $0.id == taskId }) else {
                throw ShiftFlowRepositoryError.operationFailed("Task not found in checklist")
            }
            
            // Remove the task
            checkList.tasks.removeAll { $0.id == taskId }
            
            // Update using transaction
            try await db.runTransaction { transaction, errorPointer in
                do {
                    let checkListDoc = try transaction.getDocument(documentRef)
                    guard var currentCheckList = try? checkListDoc.data(as: CheckList.self) else {
                        throw ShiftFlowRepositoryError.decodingFailed
                    }
                    
                    currentCheckList.tasks.removeAll { $0.id == taskId }
                    try transaction.setData(from: currentCheckList, forDocument: documentRef, merge: true)
                    
                    checkList = currentCheckList
                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }
            
            return checkList
        } catch let error as ShiftFlowRepositoryError {
            throw error
        } catch {
            throw ShiftFlowRepositoryError.networkError(error)
        }
    }
    
    func updateTask(in checkListId: String, task: CheckListTask) async throws -> CheckList {
        do {
            let documentRef = db.collection(entityName).document(checkListId)
            
            var checkList = try await get(byId: checkListId)
            
            // Find the task by ID
            guard let taskIndex = checkList.tasks.firstIndex(where: { $0.id == task.id }) else {
                throw ShiftFlowRepositoryError.operationFailed("Task not found in checklist")
            }
            
            // Update the task
            checkList.tasks[taskIndex] = task
            
            // Update using transaction
            try await db.runTransaction { transaction, errorPointer in
                do {
                    let checkListDoc = try transaction.getDocument(documentRef)
                    guard var currentCheckList = try? checkListDoc.data(as: CheckList.self) else {
                        throw ShiftFlowRepositoryError.decodingFailed
                    }
                    
                    // Find and update the task
                    if let index = currentCheckList.tasks.firstIndex(where: { $0.id == task.id }) {
                        currentCheckList.tasks[index] = task
                    } else {
                        throw ShiftFlowRepositoryError.operationFailed("Task not found during transaction")
                    }
                    
                    try transaction.setData(from: currentCheckList, forDocument: documentRef, merge: true)
                    
                    checkList = currentCheckList
                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }
            
            return checkList
        } catch let error as ShiftFlowRepositoryError {
            throw error
        } catch {
            throw ShiftFlowRepositoryError.networkError(error)
        }
    }
    
    func assignRoles(to checkListId: String, roleIds: [String]) async throws -> CheckList {
        do {
            let documentRef = db.collection(entityName).document(checkListId)
            
            var checkList = try await get(byId: checkListId)
            
            // Update the assigned role IDs
            checkList.assignedRoleIds = roleIds
            
            // Update the document
            try documentRef.setData(from: checkList, merge: true)
            
            return checkList
        } catch let error as ShiftFlowRepositoryError {
            throw error
        } catch {
            throw ShiftFlowRepositoryError.networkError(error)
        }
    }
}
