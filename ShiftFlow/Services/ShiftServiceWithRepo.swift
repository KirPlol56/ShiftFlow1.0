//
//  ShiftServiceWithRepo.swift
//  ShiftFlow
//
//  Created by Kirill P on 15/04/2025.
//  Updated by Kirill P on 23/05/2025.
//

import Foundation
import FirebaseFirestore
import SwiftUI

/// Protocol defining operations provided by the shift service
protocol ShiftServiceProtocol {
    /// Fetch all shifts for a company
    func fetchShifts(for companyId: String) async throws -> [Shift]
    
    /// Create a new shift
    func createShift(_ shift: Shift) async throws -> Shift
    
    /// Update an existing shift
    func updateShift(_ shift: Shift) async throws -> Shift
    
    /// Delete a shift
    func deleteShift(id: String) async throws
    
    /// Fetch shifts assigned to a specific user
    func fetchUserShifts(for userId: String, in companyId: String) async throws -> [Shift]
    
    /// Update a task within a shift
    func updateTask(in shiftId: String, task: ShiftTask) async throws -> Shift
    
    /// Add a task to a shift
    func addTask(to shiftId: String, task: ShiftTask) async throws -> Shift
    
    /// Remove a task from a shift
    func removeTask(from shiftId: String, taskId: String) async throws -> Shift
    
    /// Mark a task as completed
    func markTaskCompleted(in shiftId: String, taskId: String, completedBy: String, photoURL: String?) async throws -> Shift
    
    /// Fetch shifts for the current week
    func fetchShiftsForWeek(companyId: String) async throws -> [Shift]
    
    /// Apply multiple updates to a shift in a single transaction
    func batchUpdateShift(shiftId: String, updates: [ShiftUpdate]) async throws -> Shift
    
    /// Apply updates to multiple shifts in a single transaction
    func batchUpdateShifts(updates: [ShiftBatchUpdate]) async throws -> [Shift]
    
    /// Complete multiple tasks at once
    func completeMultipleTasks(shiftId: String, taskIds: [String], completedBy: String) async throws -> Shift
}

/// Implementation of ShiftService using the repository pattern
class ShiftServiceWithRepo: ObservableObject, ShiftServiceProtocol {
    // MARK: - Published State
    
    @Published var shifts: [Shift] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isLoadingMore: Bool = false
    @Published var hasMorePages: Bool = true
    
    let shiftRepository: any ShiftRepository
    
    // MARK: - Private Properties
    private var shiftsListenerRegistration: FirebaseFirestore.ListenerRegistration?
    private var shiftsTask: Task<Void, Never>?
    private var lastShiftDocument: DocumentSnapshot? = nil
    private let pageSize = 20
    
    // MARK: - Lifecycle
    
    init(repositoryProvider: RepositoryProvider = RepositoryFactory.shared) {
        self.shiftRepository = repositoryProvider.shiftRepository()
    }
    
    deinit {
        // Cancel any ongoing listeners
        shiftsTask?.cancel()
        if let registration = shiftsListenerRegistration {
            registration.remove()
        }
    }
    
    // MARK: - Shift Operations
    
    func fetchShifts(for companyId: String) async throws -> [Shift] {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedShifts = try await shiftRepository.getShiftsForCompany(companyId: companyId)
            
            await MainActor.run {
                self.shifts = fetchedShifts
                self.isLoading = false
            }
            
            return fetchedShifts
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch shifts: \(error.localizedDescription)"
                self.isLoading = false
            }
            throw error
        }
    }
    
    func createShift(_ shift: Shift) async throws -> Shift {
        isLoading = true
        errorMessage = nil
        
        do {
            let newShift = try await shiftRepository.create(shift)
            
            await MainActor.run {
                self.shifts.append(newShift)
                self.isLoading = false
            }
            
            return newShift
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to create shift: \(error.localizedDescription)"
                self.isLoading = false
            }
            throw error
        }
    }
    
    func updateShift(_ shift: Shift) async throws -> Shift {
        isLoading = true
        errorMessage = nil
        
        do {
            let updatedShift = try await shiftRepository.update(shift)
            
            await MainActor.run {
                if let index = self.shifts.firstIndex(where: { $0.id == shift.id }) {
                    self.shifts[index] = updatedShift
                }
                self.isLoading = false
            }
            
            return updatedShift
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to update shift: \(error.localizedDescription)"
                self.isLoading = false
            }
            throw error
        }
    }
    
    func deleteShift(id: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            try await shiftRepository.delete(id: id)
            
            await MainActor.run {
                self.shifts.removeAll { $0.id == id }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to delete shift: \(error.localizedDescription)"
                self.isLoading = false
            }
            throw error
        }
    }
    
    func fetchUserShifts(for userId: String, in companyId: String) async throws -> [Shift] {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedShifts = try await shiftRepository.getShiftsForUser(userId: userId, companyId: companyId)
            
            await MainActor.run {
                self.shifts = fetchedShifts
                self.isLoading = false
            }
            
            return fetchedShifts
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch user shifts: \(error.localizedDescription)"
                self.isLoading = false
            }
            throw error
        }
    }
    
    // MARK: - Task Operations
    
    func updateTask(in shiftId: String, task: ShiftTask) async throws -> Shift {
        return try await shiftRepository.updateTask(in: shiftId, task: task)
    }
    
    func addTask(to shiftId: String, task: ShiftTask) async throws -> Shift {
        return try await shiftRepository.addTask(to: shiftId, task: task)
    }
    
    func removeTask(from shiftId: String, taskId: String) async throws -> Shift {
        return try await shiftRepository.removeTask(from: shiftId, taskId: taskId)
    }
    
    func markTaskCompleted(in shiftId: String, taskId: String, completedBy: String, photoURL: String?) async throws -> Shift {
        return try await shiftRepository.markTaskCompleted(in: shiftId, taskId: taskId, completedBy: completedBy, photoURL: photoURL)
    }
    
    func fetchShiftsForWeek(companyId: String) async throws -> [Shift] {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedShifts = try await shiftRepository.getShiftsForWeek(companyId: companyId)
            
            await MainActor.run {
                self.shifts = fetchedShifts
                self.isLoading = false
            }
            
            return fetchedShifts
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch shifts for week: \(error.localizedDescription)"
                self.isLoading = false
            }
            throw error
        }
    }
    
    // MARK: - Batch Operations
    
    /// Apply multiple updates to a shift in a single operation
    func batchUpdateShift(shiftId: String, updates: [ShiftUpdate]) async throws -> Shift {
        isLoading = true
        errorMessage = nil
        
        do {
            let updatedShift = try await shiftRepository.batchUpdateShift(shiftId: shiftId, updates: updates)
            
            await MainActor.run {
                if let index = self.shifts.firstIndex(where: { $0.id == shiftId }) {
                    self.shifts[index] = updatedShift
                }
                self.isLoading = false
            }
            
            return updatedShift
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to apply batch updates: \(error.localizedDescription)"
                self.isLoading = false
            }
            throw error
        }
    }
    
    /// Apply updates to multiple shifts in a single transaction
    func batchUpdateShifts(updates: [ShiftBatchUpdate]) async throws -> [Shift] {
        isLoading = true
        errorMessage = nil
        
        do {
            let updatedShifts = try await shiftRepository.batchUpdateShifts(updates: updates)
            
            await MainActor.run {
                // Update shifts in the published array
                for updatedShift in updatedShifts {
                    if let index = self.shifts.firstIndex(where: { $0.id == updatedShift.id }) {
                        self.shifts[index] = updatedShift
                    }
                }
                self.isLoading = false
            }
            
            return updatedShifts
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to apply multi-shift updates: \(error.localizedDescription)"
                self.isLoading = false
            }
            throw error
        }
    }
    
    /// Helper method to create common batch updates
    func completeMultipleTasks(shiftId: String, taskIds: [String], completedBy: String) async throws -> Shift {
        let updates = taskIds.map { taskId in
            ShiftUpdate.markTaskCompleted(taskId: taskId, completedBy: completedBy, photoURL: nil)
        }
        return try await batchUpdateShift(shiftId: shiftId, updates: updates)
    }
}
