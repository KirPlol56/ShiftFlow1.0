//
//  MockRepositories.swift
//  ShiftFlow
//
//  Created by Kirill P on 15/04/2025.
//
//  Updated with pagination support on 08/05/2025.
//

import Foundation
import FirebaseFirestore

/// Mock listener registration for testing
class MockListenerRegistration {
    var isRemoved = false
    
    func remove() {
        isRemoved = true
    }
}

/// Mock DocumentID for pagination testing
struct MockDocumentID {
    let id: String
}

/// Mock User Repository for testing
class MockUserRepository: UserRepository {
    typealias ListenerRegistration = MockListenerRegistration
    
    var entityName: String = "users"
    var users: [User] = []
    var activeListeners: [String: (Result<User?, Error>) -> Void] = [:]
    var allListeners: [(Result<[User], Error>) -> Void] = []
    
    init(users: [User] = []) {
        self.users = users
    }
    
    // MARK: - ReadableRepository
    
    func get(byId id: String) async throws -> User {
        if let user = users.first(where: { $0.uid == id }) {
            return user
        }
        throw ShiftFlowRepositoryError.documentNotFound
    }
    
    func getAll() async throws -> [User] {
        return users
    }
    
    // MARK: - WritableRepository
    
    func create(_ user: User) async throws -> User {
        var newUser = user
        
        // Ensure the user has a UID - since uid is a let property, create a new user
        if newUser.uid.isEmpty {
            // Create a new user with generated UID
            let generatedUid = UUID().uuidString
            // Use the correct initializer matching your User struct
            newUser = User(
                id: nil,
                uid: generatedUid,
                email: newUser.email,
                name: newUser.name,
                isManager: newUser.isManager,
                roleTitle: newUser.roleTitle,
                roleId: newUser.roleId,
                companyId: newUser.companyId,
                companyName: newUser.companyName,
                createdAt: Date() // Use Date() instead of Timestamp
            )
        }
        
        if users.contains(where: { $0.uid == newUser.uid }) {
            throw ShiftFlowRepositoryError.operationFailed("User with this ID already exists")
        }
        
        users.append(newUser)
        notifyListeners()
        return newUser
    }
    
    func update(_ user: User) async throws -> User {
        guard !user.uid.isEmpty else {
            throw ShiftFlowRepositoryError.invalidData("User ID cannot be empty")
        }
        
        if let index = users.firstIndex(where: { $0.uid == user.uid }) {
            users[index] = user
            notifyListeners()
            return user
        }
        
        throw ShiftFlowRepositoryError.documentNotFound
    }
    
    func delete(id: String) async throws {
        if let index = users.firstIndex(where: { $0.uid == id }) {
            users.remove(at: index)
            notifyListeners()
            return
        }
        
        throw ShiftFlowRepositoryError.documentNotFound
    }
    
    // MARK: - ListenableRepository
    
    func listen(forId id: String, completion: @escaping (Result<User?, Error>) -> Void) -> MockListenerRegistration {
        let registration = MockListenerRegistration()
        activeListeners[id] = completion
        
        // Initial notification
        if let user = users.first(where: { $0.uid == id }) {
            completion(.success(user))
        } else {
            completion(.success(nil))
        }
        
        return registration
    }
    
    func listenAll(completion: @escaping (Result<[User], Error>) -> Void) -> MockListenerRegistration {
        let registration = MockListenerRegistration()
        allListeners.append(completion)
        
        // Initial notification
        completion(.success(users))
        
        return registration
    }
    
    func stopListening(_ registration: MockListenerRegistration) {
        // In a real implementation, we'd remove specific listeners
    }
    
    // Helper to notify listeners when data changes
    private func notifyListeners() {
        // Notify individual listeners
        for (id, completion) in activeListeners {
            if let user = users.first(where: { $0.uid == id }) {
                completion(.success(user))
            } else {
                completion(.success(nil))
            }
        }
        
        // Notify all listeners
        for completion in allListeners {
            completion(.success(users))
        }
    }
    
    // MARK: - UserRepository specific methods
    
    func getTeamMembers(companyId: String) async throws -> [User] {
        return users.filter { $0.companyId == companyId }
    }
    
    func getUsersByRole(companyId: String, roleId: String) async throws -> [User] {
        return users.filter { $0.companyId == companyId && $0.roleId == roleId }
    }
    
    func checkUserExists(email: String) async throws -> Bool {
        return users.contains { $0.email?.lowercased() == email.lowercased() }
    }
}

/// Mock Shift Repository for testing
class MockShiftRepository: ShiftRepository {
    typealias ListenerRegistration = MockListenerRegistration
    
    var entityName: String = "shifts"
    var shifts: [Shift] = []
    var activeListeners: [String: (Result<Shift?, Error>) -> Void] = [:]
    var allListeners: [(Result<[Shift], Error>) -> Void] = []
    
    init(shifts: [Shift] = []) {
        self.shifts = shifts
    }
    
    // MARK: - ReadableRepository
    
    func get(byId id: String) async throws -> Shift {
        if let shift = shifts.first(where: { $0.id == id }) {
            return shift
        }
        throw ShiftFlowRepositoryError.documentNotFound
    }
    
    func getAll() async throws -> [Shift] {
        return shifts
    }
    
    // MARK: - WritableRepository
    
    func create(_ shift: Shift) async throws -> Shift {
        var newShift = shift
        
        // Generate ID if not provided
        if newShift.id == nil || newShift.id!.isEmpty {
            newShift.id = UUID().uuidString
        }
        
        if shifts.contains(where: { $0.id == newShift.id }) {
            throw ShiftFlowRepositoryError.operationFailed("Shift with this ID already exists")
        }
        
        shifts.append(newShift)
        notifyListeners()
        return newShift
    }
    
    func update(_ shift: Shift) async throws -> Shift {
        guard let id = shift.id, !id.isEmpty else {
            throw ShiftFlowRepositoryError.invalidData("Invalid data")
        }
        
        if let index = shifts.firstIndex(where: { $0.id == id }) {
            shifts[index] = shift
            notifyListeners()
            return shift
        }
        
        throw ShiftFlowRepositoryError.documentNotFound
    }
    
    func delete(id: String) async throws {
        if let index = shifts.firstIndex(where: { $0.id == id }) {
            shifts.remove(at: index)
            notifyListeners()
            return
        }
        
        throw ShiftFlowRepositoryError.documentNotFound
    }
    
    // MARK: - ListenableRepository
    
    func listen(forId id: String, completion: @escaping (Result<Shift?, Error>) -> Void) -> MockListenerRegistration {
        let registration = MockListenerRegistration()
        activeListeners[id] = completion
        
        // Initial notification
        if let shift = shifts.first(where: { $0.id == id }) {
            completion(.success(shift))
        } else {
            completion(.success(nil))
        }
        
        return registration
    }
    
    func listenAll(completion: @escaping (Result<[Shift], Error>) -> Void) -> MockListenerRegistration {
        let registration = MockListenerRegistration()
        allListeners.append(completion)
        
        // Initial notification
        completion(.success(shifts))
        
        return registration
    }
    
    func stopListening(_ registration: MockListenerRegistration) {
        // In a real implementation, we'd remove specific listeners
    }
    
    // Helper to notify listeners when data changes
    private func notifyListeners() {
        // Notify individual listeners
        for (id, completion) in activeListeners {
            if let shift = shifts.first(where: { $0.id == id }) {
                completion(.success(shift))
            } else {
                completion(.success(nil))
            }
        }
        
        // Notify all listeners
        for completion in allListeners {
            completion(.success(shifts))
        }
    }
    
    // MARK: - QueryableRepository
    
    func query(filter: ShiftQueryFilter) async throws -> [Shift] {
        var filteredShifts = shifts
        
        if let companyId = filter.companyId {
            filteredShifts = filteredShifts.filter { $0.companyId == companyId }
        }
        
        if let dayOfWeek = filter.dayOfWeek {
            filteredShifts = filteredShifts.filter { $0.dayOfWeek == dayOfWeek }
        }
        
        if let status = filter.status {
            filteredShifts = filteredShifts.filter { $0.status == status }
        }
        
        if let userId = filter.assignedToUserId {
            filteredShifts = filteredShifts.filter { $0.assignedToUIDs.contains(userId) }
        }
        
        if let roleId = filter.assignedToRoleId {
            filteredShifts = filteredShifts.filter { $0.assignedRoleIds?.contains(roleId) ?? false }
        }
        
        return filteredShifts
    }
    
    // MARK: - PaginatedRepositoryProtocol
    
    func queryPaginated(filter: ShiftQueryFilter, pageSize: Int, lastDocument: DocumentSnapshot?) async throws -> (items: [Shift], lastDocument: DocumentSnapshot?) {
        // First apply all filters
        var filteredShifts = shifts
        
        if let companyId = filter.companyId {
            filteredShifts = filteredShifts.filter { $0.companyId == companyId }
        }
        
        if let dayOfWeek = filter.dayOfWeek {
            filteredShifts = filteredShifts.filter { $0.dayOfWeek == dayOfWeek }
        }
        
        if let userId = filter.assignedToUserId {
            filteredShifts = filteredShifts.filter { $0.assignedToUIDs.contains(userId) }
        }
        
        if let status = filter.status {
            filteredShifts = filteredShifts.filter { $0.status == status }
        }
        
        if let roleId = filter.assignedToRoleId {
            filteredShifts = filteredShifts.filter { $0.assignedRoleIds?.contains(roleId) ?? false }
        }
        
        // Sort by start time - using numerical comparison for timestamps
        filteredShifts.sort { shift1, shift2 in
            // Compare as seconds since reference date
            let time1 = shift1.startTime.dateValue().timeIntervalSinceReferenceDate
            let time2 = shift2.startTime.dateValue().timeIntervalSinceReferenceDate
            return time1 > time2 // Descending order
        }
        
        // Find the starting index if we have a last document
        var startIndex = 0
        if let lastDoc = lastDocument {
            let lastDocId = lastDoc.documentID
            if let foundIndex = filteredShifts.firstIndex(where: { $0.id == lastDocId }) {
                startIndex = foundIndex + 1
            }
        }
        
        // Get the page
        let endIndex = min(startIndex + pageSize, filteredShifts.count)
        guard startIndex < filteredShifts.count else {
            return (items: [], lastDocument: nil)
        }
        
        let page = Array(filteredShifts[startIndex..<endIndex])
        
        // Create a mock document reference for the last item
        var mockLastDoc: DocumentSnapshot? = nil
        if let lastItem = page.last, let lastId = lastItem.id {
            // Instead of creating a mock document snapshot, just pass the real one
            // as we're only using the documentID property
            let documentRef = Firestore.firestore().collection("shifts").document(lastId)
            mockLastDoc = try? await documentRef.getDocument()
        }
        
        return (items: page, lastDocument: mockLastDoc)
    }
    
    // MARK: - ShiftRepository specific methods
    
    func getShiftsForCompany(companyId: String) async throws -> [Shift] {
        return shifts.filter { $0.companyId == companyId }
    }
    
    func getShiftsForUser(userId: String, companyId: String) async throws -> [Shift] {
        return shifts.filter {
            $0.companyId == companyId && $0.assignedToUIDs.contains(userId)
        }
    }
    
    func getShiftsForWeek(companyId: String) async throws -> [Shift] {
        return shifts.filter { $0.companyId == companyId }
    }
    
    func updateTask(in shiftId: String, task: ShiftTask) async throws -> Shift {
        guard let shiftIndex = shifts.firstIndex(where: { $0.id == shiftId }) else {
            throw ShiftFlowRepositoryError.documentNotFound
        }
        
        var shift = shifts[shiftIndex]
        
        if let taskIndex = shift.tasks.firstIndex(where: { $0.id == task.id }) {
            shift.tasks[taskIndex] = task
            shifts[shiftIndex] = shift
            notifyListeners()
            return shift
        } else {
            throw ShiftFlowRepositoryError.documentNotFound
        }
    }
    
    func addTask(to shiftId: String, task: ShiftTask) async throws -> Shift {
        guard let shiftIndex = shifts.firstIndex(where: { $0.id == shiftId }) else {
            throw ShiftFlowRepositoryError.documentNotFound
        }
        
        var shift = shifts[shiftIndex]
        var newTask = task
        
        if newTask.id == nil || newTask.id!.isEmpty {
            newTask.id = UUID().uuidString
        }
        
        shift.tasks.append(newTask)
        shifts[shiftIndex] = shift
        notifyListeners()
        return shift
    }
    
    func removeTask(from shiftId: String, taskId: String) async throws -> Shift {
        guard let shiftIndex = shifts.firstIndex(where: { $0.id == shiftId }) else {
            throw ShiftFlowRepositoryError.documentNotFound
        }
        
        var shift = shifts[shiftIndex]
        
        if let taskIndex = shift.tasks.firstIndex(where: { $0.id == taskId }) {
            shift.tasks.remove(at: taskIndex)
            shifts[shiftIndex] = shift
            notifyListeners()
            return shift
        } else {
            throw ShiftFlowRepositoryError.documentNotFound
        }
    }
    
    func markTaskCompleted(in shiftId: String, taskId: String, completedBy: String, photoURL: String?) async throws -> Shift {
        guard let shiftIndex = shifts.firstIndex(where: { $0.id == shiftId }) else {
            throw ShiftFlowRepositoryError.documentNotFound
        }
        
        var shift = shifts[shiftIndex]
        
        if let taskIndex = shift.tasks.firstIndex(where: { $0.id == taskId }) {
            shift.tasks[taskIndex].isCompleted = true
            shift.tasks[taskIndex].completedBy = completedBy
            shift.tasks[taskIndex].completedAt = Timestamp(date: Date())
            shift.tasks[taskIndex].photoURL = photoURL
            
            shifts[shiftIndex] = shift
            notifyListeners()
            return shift
        } else {
            throw ShiftFlowRepositoryError.documentNotFound
        }
    }
}

/// Mock Role Repository for testing
class MockRoleRepository: RoleRepository {
    var entityName: String = "roles"
    var roles: [Role] = []
    
    init(roles: [Role] = []) {
        self.roles = roles
    }
    
    // MARK: - ReadableRepository
    
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
        
        if let role = roles.first(where: { $0.id == id }) {
            return role
        }
        throw ShiftFlowRepositoryError.documentNotFound
    }
    
    func getAll() async throws -> [Role] {
        return roles
    }
    
    // MARK: - WritableRepository
    
    func create(_ role: Role) async throws -> Role {
        var newRole = role
        
        // Check if this is a standard role
        if newRole.isStandardRole {
            if let standardRole = StandardRoles.allCases.first(where: { $0.rawValue == newRole.title }) {
                return Role.fromStandardRole(standardRole, companyId: newRole.companyId)
            }
        }
        
        // Generate ID if not provided
        if newRole.id == nil || newRole.id!.isEmpty {
            newRole.id = UUID().uuidString
        }
        
        // Check for duplicates
        if roles.contains(where: { $0.id == newRole.id }) {
            throw ShiftFlowRepositoryError.operationFailed("Role with this ID already exists")
        }
        
        roles.append(newRole)
        return newRole
    }
    
    func update(_ role: Role) async throws -> Role {
        guard let id = role.id, !id.isEmpty else {
            throw ShiftFlowRepositoryError.invalidData("Invalid data")
        }
        
        if let index = roles.firstIndex(where: { $0.id == id }) {
            roles[index] = role
            return role
        }
        
        throw ShiftFlowRepositoryError.documentNotFound
    }
    
    func delete(id: String) async throws {
        if let index = roles.firstIndex(where: { $0.id == id }) {
            roles.remove(at: index)
            return
        }
        
        throw ShiftFlowRepositoryError.documentNotFound
    }
    
    // MARK: - RoleRepository specific methods
    
    func getRolesForCompany(companyId: String) async throws -> [Role] {
        // Include both custom roles for this company and standard roles
        let standardRoles = StandardRoles.allCases.map { Role.fromStandardRole($0, companyId: companyId) }
        let customRoles = roles.filter { $0.companyId == companyId }
        
        return standardRoles + customRoles
    }
    
    func checkRoleExists(title: String, companyId: String) async throws -> Bool {
        // Check if a role with this title already exists in the company
        return roles.contains { $0.companyId == companyId && $0.title.lowercased() == title.lowercased() }
    }
    
    func getStandardRoleById(id: String) async throws -> Role? {
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
        
        return nil
    }
    
    func getAllStandardRoles() async throws -> [Role] {
        return StandardRoles.allCases.map { Role.fromStandardRole($0, companyId: "") }
    }
    
    func resolveRoleInfo(roleId: String, companyId: String) async throws -> (id: String, title: String) {
        // Check if it's a standard role
        if let standardRole = try? await getStandardRoleById(id: roleId) {
            return (id: roleId, title: standardRole.title)
        }
        
        // Try to find a custom role
        if let role = roles.first(where: { $0.id == roleId }) {
            return (id: roleId, title: role.title)
        }
        
        throw ShiftFlowRepositoryError.documentNotFound
    }
}

/// Mock CheckList Repository for testing
class MockCheckListRepository: CheckListRepository {
    var entityName: String = "checkLists"
    var checkLists: [CheckList] = []
    
    init(checkLists: [CheckList] = []) {
        self.checkLists = checkLists
    }
    
    // MARK: - ReadableRepository
    
    func get(byId id: String) async throws -> CheckList {
        if let checkList = checkLists.first(where: { $0.id == id }) {
            return checkList
        }
        throw ShiftFlowRepositoryError.documentNotFound
    }
    
    func getAll() async throws -> [CheckList] {
        return checkLists
    }
    
    // MARK: - WritableRepository
    
    func create(_ checkList: CheckList) async throws -> CheckList {
        var newCheckList = checkList
        
        // Generate ID if not provided
        if newCheckList.id == nil || newCheckList.id!.isEmpty {
            newCheckList.id = UUID().uuidString
        }
        
        if checkLists.contains(where: { $0.id == newCheckList.id }) {
            throw ShiftFlowRepositoryError.operationFailed("CheckList with this ID already exists")
        }
        
        checkLists.append(newCheckList)
        return newCheckList
    }
    
    func update(_ checkList: CheckList) async throws -> CheckList {
        guard let id = checkList.id, !id.isEmpty else {
            throw ShiftFlowRepositoryError.invalidData("Invalid data")
        }
        
        if let index = checkLists.firstIndex(where: { $0.id == id }) {
            checkLists[index] = checkList
            return checkList
        }
        
        throw ShiftFlowRepositoryError.documentNotFound
    }
    
    func delete(id: String) async throws {
        if let index = checkLists.firstIndex(where: { $0.id == id }) {
            checkLists.remove(at: index)
            return
        }
        
        throw ShiftFlowRepositoryError.documentNotFound
    }
    
    // MARK: - QueryableRepository
    
    func query(filter: CheckListQueryFilter) async throws -> [CheckList] {
        var filteredCheckLists = checkLists
        
        if let companyId = filter.companyId {
            filteredCheckLists = filteredCheckLists.filter { $0.companyId == companyId }
        }
        
        if let createdByUID = filter.createdByUID {
            filteredCheckLists = filteredCheckLists.filter { $0.createdByUID == createdByUID }
        }
        
        if let shiftSection = filter.shiftSection {
            filteredCheckLists = filteredCheckLists.filter { $0.shiftSection == shiftSection }
        }
        
        if let roleId = filter.assignedRoleId {
            filteredCheckLists = filteredCheckLists.filter { $0.assignedRoleIds?.contains(roleId) ?? false }
        }
        
        if let activeToday = filter.activeToday, activeToday {
            filteredCheckLists = filteredCheckLists.filter { $0.frequency.isActiveToday() }
        }
        
        return filteredCheckLists
    }
    
    // MARK: - CheckListRepository specific methods
    
    func getCheckListsForCompany(companyId: String) async throws -> [CheckList] {
        return checkLists.filter { $0.companyId == companyId }
    }
    
    func getCheckListsForRole(roleId: String, companyId: String) async throws -> [CheckList] {
        return checkLists.filter {
            $0.companyId == companyId &&
            ($0.assignedRoleIds?.contains(roleId) ?? false)
        }
    }
    
    func getCheckListsForToday(companyId: String) async throws -> [CheckList] {
        return checkLists.filter { $0.companyId == companyId && $0.frequency.isActiveToday() }
    }
    
    func addTask(to checkListId: String, task: CheckListTask) async throws -> CheckList {
        guard let index = checkLists.firstIndex(where: { $0.id == checkListId }) else {
            throw ShiftFlowRepositoryError.documentNotFound
        }
        
        var checkList = checkLists[index]
        var newTask = task
        
        if newTask.id == nil || newTask.id!.isEmpty {
            newTask.id = UUID().uuidString
        }
        
        checkList.tasks.append(newTask)
        checkLists[index] = checkList
        return checkList
    }
    
    func removeTask(from checkListId: String, taskId: String) async throws -> CheckList {
        guard let checkListIndex = checkLists.firstIndex(where: { $0.id == checkListId }) else {
            throw ShiftFlowRepositoryError.documentNotFound
        }
        
        var checkList = checkLists[checkListIndex]
        
        if let taskIndex = checkList.tasks.firstIndex(where: { $0.id == taskId }) {
            checkList.tasks.remove(at: taskIndex)
            checkLists[checkListIndex] = checkList
            return checkList
        } else {
            throw ShiftFlowRepositoryError.documentNotFound
        }
    }
    
    func updateTask(in checkListId: String, task: CheckListTask) async throws -> CheckList {
        guard let checkListIndex = checkLists.firstIndex(where: { $0.id == checkListId }) else {
            throw ShiftFlowRepositoryError.documentNotFound
        }
        
        var checkList = checkLists[checkListIndex]
        
        if let taskIndex = checkList.tasks.firstIndex(where: { $0.id == task.id }) {
            checkList.tasks[taskIndex] = task
            checkLists[checkListIndex] = checkList
            return checkList
        } else {
            throw ShiftFlowRepositoryError.documentNotFound
        }
    }
    
    func assignRoles(to checkListId: String, roleIds: [String]) async throws -> CheckList {
        guard let index = checkLists.firstIndex(where: { $0.id == checkListId }) else {
            throw ShiftFlowRepositoryError.documentNotFound
        }
        
        var checkList = checkLists[index]
        checkList.assignedRoleIds = roleIds
        checkLists[index] = checkList
        return checkList
    }
}
