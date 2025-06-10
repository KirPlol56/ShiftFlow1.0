//
//   CheckListServiceWithRepo.swift
//  ShiftFlow
//
//  Created by Kirill P on 15/04/2025.
//

import Foundation
import FirebaseFirestore
import Combine

/// Protocol defining checklist management operations with async/await first approach
protocol CheckListServiceProtocol: ObservableObject {
    // MARK: - Primary Async API
    
    /// Fetch checklists for a company
    func fetchCheckLists(for companyId: String) async throws -> [CheckList]
    
    /// Fetch checklists for a user's role
    func fetchCheckListsForRole(roleId: String, companyId: String) async throws -> [CheckList]
    
    /// Create a new checklist
    func createCheckList(_ checkList: CheckList) async throws -> CheckList
    
    /// Update an existing checklist
    func updateCheckList(_ checkList: CheckList) async throws -> CheckList
    
    /// Delete a checklist
    func deleteCheckList(id: String) async throws
    
    /// Add a task to a checklist
    func addTask(to checkListId: String, task: CheckListTask) async throws -> CheckList
    
    /// Update a task in a checklist
    func updateTask(in checkListId: String, task: CheckListTask) async throws -> CheckList
    
    /// Remove a task from a checklist
    func removeTask(from checkListId: String, taskId: String) async throws -> CheckList
    
    /// Assign roles to a checklist
    func assignRoles(to checkListId: String, roleIds: [String]) async throws -> CheckList
    
    /// Fetch checklists active for today
    func fetchCheckListsForToday(companyId: String) async throws -> [CheckList]
    
    /// Fetch checklists for the current user based on role and filter by today's active ones
    func fetchCheckListsForCurrentUser(user: User) async throws -> [CheckList]
    
    /// Create a deep copy of a checklist
    func cloneCheckList(_ checkList: CheckList, newTitle: String) async throws -> CheckList
    
    // MARK: - Completion Handler API for Backward Compatibility
    
    /// Fetch checklists for a company
    func fetchCheckLists(for companyId: String, completion: @escaping (Result<[CheckList], Error>) -> Void)
    
    /// Fetch checklists for a user's role
    func fetchCheckListsForRole(roleId: String, companyId: String, completion: @escaping (Result<[CheckList], Error>) -> Void)
    
    /// Create a new checklist
    func createCheckList(_ checkList: CheckList, completion: @escaping (Result<CheckList, Error>) -> Void)
    
    /// Update an existing checklist
    func updateCheckList(_ checkList: CheckList, completion: @escaping (Result<CheckList, Error>) -> Void)
    
    /// Delete a checklist
    func deleteCheckList(id: String, completion: @escaping (Result<Void, Error>) -> Void)
    
    /// Add a task to a checklist
    func addTask(to checkListId: String, task: CheckListTask, completion: @escaping (Result<CheckList, Error>) -> Void)
    
    /// Update a task in a checklist
    func updateTask(in checkListId: String, task: CheckListTask, completion: @escaping (Result<CheckList, Error>) -> Void)
    
    /// Remove a task from a checklist
    func removeTask(from checkListId: String, taskId: String, completion: @escaping (Result<CheckList, Error>) -> Void)
    
    /// Assign roles to a checklist
    func assignRoles(to checkListId: String, roleIds: [String], completion: @escaping (Result<CheckList, Error>) -> Void)
    
    /// Fetch checklists active for today
    func fetchCheckListsForToday(companyId: String, completion: @escaping (Result<[CheckList], Error>) -> Void)
    
    /// Fetch checklists for the current user based on role and filter by today's active ones
    func fetchCheckListsForCurrentUser(user: User, completion: @escaping (Result<[CheckList], Error>) -> Void)
    
    /// Create a deep copy of a checklist
    func cloneCheckList(_ checkList: CheckList, newTitle: String, completion: @escaping (Result<CheckList, Error>) -> Void)
    
    // MARK: - Synchronous Methods
    
    /// Check if a checklist is active for today
    func isCheckListActiveToday(_ checkList: CheckList) -> Bool
    
    /// Group checklists by shift section
    func groupCheckListsBySection(checkLists: [CheckList]) -> [CheckList.ShiftSection: [CheckList]]
}

/// Implementation of CheckListService using the repository pattern
class CheckListServiceWithRepo: ObservableObject, CheckListServiceProtocol {
    // MARK: - Properties
    
    /// Repository for data access
    private let checkListRepository: any CheckListRepository
    
    // MARK: - Lifecycle
    
    /// Initialize with repository
    init(repositoryProvider: RepositoryProvider = RepositoryFactory.shared) {
        self.checkListRepository = repositoryProvider.checkListRepository()
    }
    
    // MARK: - Primary Async API Implementation
    
    /// Fetch checklists for a company
    /// - Parameter companyId: Company ID
    /// - Returns: Array of checklists
    func fetchCheckLists(for companyId: String) async throws -> [CheckList] {
        guard !companyId.isEmpty else {
            throw ServiceError.invalidOperation("Company ID is required")
        }
        
        return try await checkListRepository.getCheckListsForCompany(companyId: companyId)
    }
    
    /// Fetch checklists for a user's role
    /// - Parameters:
    ///   - roleId: Role ID
    ///   - companyId: Company ID
    /// - Returns: Array of checklists
    func fetchCheckListsForRole(roleId: String, companyId: String) async throws -> [CheckList] {
        guard !companyId.isEmpty else {
            throw ServiceError.invalidOperation("Company ID is required")
        }
        
        guard !roleId.isEmpty else {
            throw ServiceError.invalidOperation("Role ID is required")
        }
        
        return try await checkListRepository.getCheckListsForRole(roleId: roleId, companyId: companyId)
    }
    
    /// Create a new checklist
    /// - Parameter checkList: Checklist to create
    /// - Returns: Created checklist
    func createCheckList(_ checkList: CheckList) async throws -> CheckList {
        guard !checkList.companyId.isEmpty else {
            throw ServiceError.invalidOperation("Company ID is required")
        }
        
        guard !checkList.createdByUID.isEmpty else {
            throw ServiceError.invalidOperation("Creator ID is required")
        }
        
        guard !checkList.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ServiceError.invalidOperation("Checklist title is required")
        }
        
        return try await checkListRepository.create(checkList)
    }
    
    /// Update an existing checklist
    /// - Parameter checkList: Checklist to update
    /// - Returns: Updated checklist
    func updateCheckList(_ checkList: CheckList) async throws -> CheckList {
        guard let id = checkList.id, !id.isEmpty else {
            throw ServiceError.missingId("Checklist")
        }
        
        return try await checkListRepository.update(checkList)
    }
    
    /// Delete a checklist
    /// - Parameter id: Checklist ID
    func deleteCheckList(id: String) async throws {
        guard !id.isEmpty else {
            throw ServiceError.missingId("Checklist")
        }
        
        try await checkListRepository.delete(id: id)
    }
    
    /// Add a task to a checklist
    /// - Parameters:
    ///   - checkListId: Checklist ID
    ///   - task: Task to add
    /// - Returns: Updated checklist
    func addTask(to checkListId: String, task: CheckListTask) async throws -> CheckList {
        guard !checkListId.isEmpty else {
            throw ServiceError.missingId("Checklist")
        }
        
        return try await checkListRepository.addTask(to: checkListId, task: task)
    }
    
    /// Update a task in a checklist
    /// - Parameters:
    ///   - checkListId: Checklist ID
    ///   - task: Task to update
    /// - Returns: Updated checklist
    func updateTask(in checkListId: String, task: CheckListTask) async throws -> CheckList {
        guard !checkListId.isEmpty else {
            throw ServiceError.missingId("Checklist")
        }
        
        guard task.id != nil else {
            throw ServiceError.missingId("Task")
        }
        
        return try await checkListRepository.updateTask(in: checkListId, task: task)
    }
    
    /// Remove a task from a checklist
    /// - Parameters:
    ///   - checkListId: Checklist ID
    ///   - taskId: Task ID
    /// - Returns: Updated checklist
    func removeTask(from checkListId: String, taskId: String) async throws -> CheckList {
        guard !checkListId.isEmpty else {
            throw ServiceError.missingId("Checklist")
        }
        
        guard !taskId.isEmpty else {
            throw ServiceError.missingId("Task")
        }
        
        return try await checkListRepository.removeTask(from: checkListId, taskId: taskId)
    }
    
    /// Assign roles to a checklist
    /// - Parameters:
    ///   - checkListId: Checklist ID
    ///   - roleIds: Array of role IDs
    /// - Returns: Updated checklist
    func assignRoles(to checkListId: String, roleIds: [String]) async throws -> CheckList {
        guard !checkListId.isEmpty else {
            throw ServiceError.missingId("Checklist")
        }
        
        return try await checkListRepository.assignRoles(to: checkListId, roleIds: roleIds)
    }
    
    /// Fetch checklists active for today
    /// - Parameter companyId: Company ID
    /// - Returns: Array of checklists
    func fetchCheckListsForToday(companyId: String) async throws -> [CheckList] {
        guard !companyId.isEmpty else {
            throw ServiceError.invalidOperation("Company ID is required")
        }
        
        return try await checkListRepository.getCheckListsForToday(companyId: companyId)
    }
    
    /// Fetch checklists for the current user based on role and filter by today's active ones
    /// - Parameter user: Current user
    /// - Returns: Array of checklists
    func fetchCheckListsForCurrentUser(user: User) async throws -> [CheckList] {
        guard let companyId = user.companyId, !companyId.isEmpty else {
            throw ServiceError.invalidOperation("User has no company ID")
        }
        
        let roleId = user.roleId
        
        if roleId.isEmpty {
            throw ServiceError.invalidOperation("User has no role assigned")
        }
        
        // Filter for checklists active today
        let filter = CheckListQueryFilter(companyId: companyId, assignedRoleId: roleId, activeToday: true)
        return try await checkListRepository.query(filter: filter)
    }
    
    /// Create a deep copy of a checklist
    /// - Parameters:
    ///   - checkList: Checklist to clone
    ///   - newTitle: Title for the cloned checklist
    /// - Returns: Cloned checklist
    func cloneCheckList(_ checkList: CheckList, newTitle: String) async throws -> CheckList {
        guard !newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ServiceError.invalidOperation("New title is required")
        }
        
        var clonedCheckList = checkList
        clonedCheckList.id = nil // Clear ID to create a new document
        clonedCheckList.title = newTitle
        
        // Generate new IDs for tasks to avoid conflicts
        var clonedTasks: [CheckListTask] = []
        for task in clonedCheckList.tasks {
            var clonedTask = task
            clonedTask.id = UUID().uuidString
            clonedTasks.append(clonedTask)
        }
        clonedCheckList.tasks = clonedTasks
        
        return try await createCheckList(clonedCheckList)
    }
    
    // MARK: - Completion Handler API Implementation
    
    func fetchCheckLists(for companyId: String, completion: @escaping (Result<[CheckList], Error>) -> Void) {
        Task {
            do {
                let checkLists = try await fetchCheckLists(for: companyId)
                
                await MainActor.run {
                    completion(.success(checkLists))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func fetchCheckListsForRole(roleId: String, companyId: String, completion: @escaping (Result<[CheckList], Error>) -> Void) {
        Task {
            do {
                let checkLists = try await fetchCheckListsForRole(roleId: roleId, companyId: companyId)
                
                await MainActor.run {
                    completion(.success(checkLists))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func createCheckList(_ checkList: CheckList, completion: @escaping (Result<CheckList, Error>) -> Void) {
        Task {
            do {
                let createdCheckList = try await createCheckList(checkList)
                
                await MainActor.run {
                    completion(.success(createdCheckList))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func updateCheckList(_ checkList: CheckList, completion: @escaping (Result<CheckList, Error>) -> Void) {
        Task {
            do {
                let updatedCheckList = try await updateCheckList(checkList)
                
                await MainActor.run {
                    completion(.success(updatedCheckList))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func deleteCheckList(id: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                try await deleteCheckList(id: id)
                
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
    
    func addTask(to checkListId: String, task: CheckListTask, completion: @escaping (Result<CheckList, Error>) -> Void) {
        Task {
            do {
                let updatedCheckList = try await addTask(to: checkListId, task: task)
                
                await MainActor.run {
                    completion(.success(updatedCheckList))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func updateTask(in checkListId: String, task: CheckListTask, completion: @escaping (Result<CheckList, Error>) -> Void) {
        Task {
            do {
                let updatedCheckList = try await updateTask(in: checkListId, task: task)
                
                await MainActor.run {
                    completion(.success(updatedCheckList))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func removeTask(from checkListId: String, taskId: String, completion: @escaping (Result<CheckList, Error>) -> Void) {
        Task {
            do {
                let updatedCheckList = try await removeTask(from: checkListId, taskId: taskId)
                
                await MainActor.run {
                    completion(.success(updatedCheckList))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func assignRoles(to checkListId: String, roleIds: [String], completion: @escaping (Result<CheckList, Error>) -> Void) {
        Task {
            do {
                let updatedCheckList = try await assignRoles(to: checkListId, roleIds: roleIds)
                
                await MainActor.run {
                    completion(.success(updatedCheckList))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func fetchCheckListsForToday(companyId: String, completion: @escaping (Result<[CheckList], Error>) -> Void) {
        Task {
            do {
                let checkLists = try await fetchCheckListsForToday(companyId: companyId)
                
                await MainActor.run {
                    completion(.success(checkLists))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func fetchCheckListsForCurrentUser(user: User, completion: @escaping (Result<[CheckList], Error>) -> Void) {
        Task {
            do {
                let checkLists = try await fetchCheckListsForCurrentUser(user: user)
                
                await MainActor.run {
                    completion(.success(checkLists))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func cloneCheckList(_ checkList: CheckList, newTitle: String, completion: @escaping (Result<CheckList, Error>) -> Void) {
        Task {
            do {
                let clonedCheckList = try await cloneCheckList(checkList, newTitle: newTitle)
                
                await MainActor.run {
                    completion(.success(clonedCheckList))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Synchronous Methods
    
    /// Check if a checklist is active for today
    /// - Parameter checkList: Checklist to check
    /// - Returns: True if the checklist is active today
    func isCheckListActiveToday(_ checkList: CheckList) -> Bool {
        return checkList.frequency.isActiveToday()
    }
    
    /// Group checklists by shift section
    /// - Parameter checkLists: Checklists to group
    /// - Returns: Dictionary of checklists grouped by section
    func groupCheckListsBySection(checkLists: [CheckList]) -> [CheckList.ShiftSection: [CheckList]] {
        var groupedLists: [CheckList.ShiftSection: [CheckList]] = [:]
        
        for section in CheckList.ShiftSection.allCases {
            groupedLists[section] = checkLists.filter { $0.shiftSection == section }
        }
        
        return groupedLists
    }
}
