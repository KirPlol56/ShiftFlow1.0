//
//  ShiftServiceWithRepo.swift
//  ShiftFlow
//
//  Created by Kirill P on 13/03/2025.
//

import Foundation
import FirebaseFirestore
import Combine

/// Protocol defining shift management operations with async/await first approach
protocol ShiftServiceProtocol: ObservableObject {
    // MARK: - Published State
    
    var shifts: [Shift] { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    var isLoadingMore: Bool { get }
    var hasMorePages: Bool { get }
    
    // MARK: - Async Streams
    
    /// Get a stream of shifts updates
    func shiftsStream() -> AsyncThrowingStream<[Shift], Error>
    
    /// Get a stream of updates for a specific shift
    func shiftStream(id: String) -> AsyncThrowingStream<Shift?, Error>
    
    // MARK: - Primary Async API
    
    /// Fetch shifts for a company
    func fetchShifts(for companyId: String) async
    
    /// Fetch shifts for a specific user
    func fetchUserShifts(for userId: String, in companyId: String) async
    
    /// Fetch next page of shifts for a company
    func fetchNextShiftsPage(for companyId: String) async
    
    /// Fetch next page of user shifts
    func fetchNextUserShiftsPage(for userId: String, in companyId: String) async
    
    /// Update a shift
    func updateShift(_ shift: Shift) async throws -> Shift
    
    /// Create a new shift
    func createShift(_ shift: Shift) async throws -> Shift
    
    /// Delete a shift
    func deleteShift(id: String) async throws
    
    /// Update a task in a shift
    func updateTask(in shiftId: String, task: ShiftTask) async throws -> Shift
    
    /// Add a task to a shift
    func addTask(to shiftId: String, task: ShiftTask) async throws -> Shift
    
    /// Remove a task from a shift
    func removeTask(from shiftId: String, taskId: String) async throws -> Shift
    
    /// Mark a task as completed
    func markTaskCompleted(in shiftId: String, taskId: String, completedBy: String, photoURL: String?) async throws -> Shift
    
    /// Fetch shifts for the current week
    func fetchShiftsForWeek(companyId: String) async throws -> [Shift]
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
    
    // MARK: - Pagination Support
    
    /// Reset pagination state
    private func resetPaginationState() {
        lastShiftDocument = nil
        hasMorePages = true
    }
    
    // MARK: - Async Streams
    
    func shiftsStream() -> AsyncThrowingStream<[Shift], Error> {
        return shiftRepository.listenAllAsync()
    }
    
    func shiftStream(id: String) -> AsyncThrowingStream<Shift?, Error> {
        return shiftRepository.listenAsync(forId: id)
    }
    
    // MARK: - Primary Async API Implementation
    
    /// Fetch shifts for a company with pagination support
    /// - Parameter companyId: Company ID
    func fetchShifts(for companyId: String) async {
        guard !companyId.isEmpty else {
            await MainActor.run {
                self.errorMessage = "Company ID missing."
                self.shifts = []
            }
            return
        }
        
        // Reset pagination and data state
        resetPaginationState()
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            shifts = [] // Clear previous data
        }
        
        await fetchNextShiftsPage(for: companyId)
    }
    
    /// Fetch next page of shifts for a company
    /// - Parameter companyId: Company ID
    func fetchNextShiftsPage(for companyId: String) async {
        // Don't fetch if already loading or no more pages
        if isLoadingMore || !hasMorePages {
            return
        }
        
        await MainActor.run {
            isLoadingMore = true
        }
        
        // Cancel previous task if running
        shiftsTask?.cancel()
        
        // Create a new task for fetching the data
        shiftsTask = Task {
            do {
                let filter = ShiftQueryFilter(companyId: companyId)
                
                let result = try await shiftRepository.queryPaginated(
                    filter: filter,
                    pageSize: pageSize,
                    lastDocument: lastShiftDocument
                )
                
                // Update state
                await MainActor.run {
                    // Append new shifts to existing ones
                    let sortedNewShifts = sortShiftsByDayOfWeek(result.items)
                    self.shifts.append(contentsOf: sortedNewShifts)
                    
                    // Update pagination state
                    self.lastShiftDocument = result.lastDocument
                    self.hasMorePages = result.items.count >= self.pageSize
                    self.isLoadingMore = false
                    self.isLoading = false
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        self.errorMessage = "Error fetching shifts: \(error.localizedDescription)"
                        self.isLoadingMore = false
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    /// Fetch shifts for a specific user with pagination
    /// - Parameters:
    ///   - userId: User ID
    ///   - companyId: Company ID
    func fetchUserShifts(for userId: String, in companyId: String) async {
        guard !userId.isEmpty && !companyId.isEmpty else {
            await MainActor.run {
                self.errorMessage = "User ID or Company ID missing."
                self.shifts = []
            }
            return
        }
        
        // Reset pagination and data state
        resetPaginationState()
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            shifts = [] // Clear previous data
        }
        
        await fetchNextUserShiftsPage(for: userId, in: companyId)
    }
    
    /// Fetch next page of user shifts
    /// - Parameters:
    ///   - userId: User ID
    ///   - companyId: Company ID
    func fetchNextUserShiftsPage(for userId: String, in companyId: String) async {
        // Don't fetch if already loading or no more pages
        if isLoadingMore || !hasMorePages {
            return
        }
        
        await MainActor.run {
            isLoadingMore = true
        }
        
        // Cancel previous task if running
        shiftsTask?.cancel()
        
        // Create a new task for fetching the data
        shiftsTask = Task {
            do {
                let filter = ShiftQueryFilter(companyId: companyId, assignedToUserId: userId)
                
                let result = try await shiftRepository.queryPaginated(
                    filter: filter,
                    pageSize: pageSize,
                    lastDocument: lastShiftDocument
                )
                
                // Update state
                await MainActor.run {
                    // Append new shifts to existing ones
                    let sortedNewShifts = sortShiftsByDayOfWeek(result.items)
                    self.shifts.append(contentsOf: sortedNewShifts)
                    
                    // Update pagination state
                    self.lastShiftDocument = result.lastDocument
                    self.hasMorePages = result.items.count >= self.pageSize
                    self.isLoadingMore = false
                    self.isLoading = false
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        self.errorMessage = "Error fetching user shifts: \(error.localizedDescription)"
                        self.isLoadingMore = false
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    
    
    /// Helper method to sort shifts by day of week
    func sortShiftsByDayOfWeek(_ shifts: [Shift]) -> [Shift] {
        return shifts.sorted { shift1, shift2 in
            let day1Value = shift1.dayOfWeek.sortOrder
            let day2Value = shift2.dayOfWeek.sortOrder
            
            if day1Value == day2Value {
                // If same day, sort by start time by comparing the seconds since reference date
                return shift1.startTime.dateValue().timeIntervalSince1970 < shift2.startTime.dateValue().timeIntervalSince1970
            }
            
            return day1Value < day2Value
        }
    }
    
    /// Update a shift
    func updateShift(_ shift: Shift) async throws -> Shift {
        return try await shiftRepository.update(shift)
    }
    
    /// Create a new shift
    func createShift(_ shift: Shift) async throws -> Shift {
        return try await shiftRepository.create(shift)
    }
    
    /// Delete a shift
    func deleteShift(id: String) async throws {
        try await shiftRepository.delete(id: id)
    }
    
    /// Update a task in a shift
    func updateTask(in shiftId: String, task: ShiftTask) async throws -> Shift {
        return try await shiftRepository.updateTask(in: shiftId, task: task)
    }
    
    /// Add a task to a shift
    func addTask(to shiftId: String, task: ShiftTask) async throws -> Shift {
        return try await shiftRepository.addTask(to: shiftId, task: task)
    }
    
    /// Remove a task from a shift
    func removeTask(from shiftId: String, taskId: String) async throws -> Shift {
        return try await shiftRepository.removeTask(from: shiftId, taskId: taskId)
    }
    
    /// Mark a task as completed
    func markTaskCompleted(in shiftId: String, taskId: String, completedBy: String, photoURL: String?) async throws -> Shift {
        return try await shiftRepository.markTaskCompleted(in: shiftId, taskId: taskId, completedBy: completedBy, photoURL: photoURL)
    }
    
    /// Fetch shifts for the current week
    func fetchShiftsForWeek(companyId: String) async throws -> [Shift] {
        return try await shiftRepository.getShiftsForWeek(companyId: companyId)
    }
}

extension Shift.DayOfWeek {
    var sortOrder: Int {
        switch self {
        case .monday:    return 0
        case .tuesday:   return 1
        case .wednesday: return 2
        case .thursday:  return 3
        case .friday:    return 4
        case .saturday:  return 5
        case .sunday:    return 6
        }
    }
}
