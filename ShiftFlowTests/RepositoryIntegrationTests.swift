//
//  RepositoryIntegrationTests.swift
//  ShiftFlowTests
//
//  Created by Kirill P on 15/04/2025.
//

import XCTest
@testable import ShiftFlow
import FirebaseFirestore
import FirebaseCore
class RepositoryIntegrationTests: XCTestCase {
    
    // Test repositories
    var userRepository: MockUserRepository!
    var shiftRepository: MockShiftRepository!
    var roleRepository: MockRoleRepository!
    var checkListRepository: MockCheckListRepository!
    
    // Services using repositories
    var authService: FirebaseAuthenticationServiceWithRepo!
    var shiftService: ShiftServiceWithRepo!
    var roleService: RoleServiceWithRepo!
    var checkListService: CheckListServiceWithRepo!
    
    // Repository provider for tests
    var mockRepositoryProvider: RepositoryProvider!
    
    override func setUp() {
        super.setUp()
        
        // Initialize mock repositories
        userRepository = MockUserRepository()
        shiftRepository = MockShiftRepository()
        roleRepository = MockRoleRepository()
        checkListRepository = MockCheckListRepository()
        
        // Set up the repository provider
        mockRepositoryProvider = RepositoryFactory.createMockFactory(
            userRepository: userRepository,
            shiftRepository: shiftRepository,
            roleRepository: roleRepository,
            checkListRepository: checkListRepository
        )
        
        // Initialize services with mock repositories
        authService = FirebaseAuthenticationServiceWithRepo(repositoryProvider: mockRepositoryProvider)
        shiftService = ShiftServiceWithRepo(repositoryProvider: mockRepositoryProvider)
        roleService = RoleServiceWithRepo(repositoryProvider: mockRepositoryProvider)
        checkListService = CheckListServiceWithRepo(repositoryProvider: mockRepositoryProvider)
        
        // Seed data
        seedTestData()
    }
    
    override func tearDown() {
        userRepository = nil
        shiftRepository = nil
        roleRepository = nil
        checkListRepository = nil
        
        authService = nil
        shiftService = nil
        roleService = nil
        checkListService = nil
        
        mockRepositoryProvider = nil
        
        super.tearDown()
    }
    
    // MARK: - Seed Data
    
    private func seedTestData() {
        // Add mock data for testing
        let companyId = "test-company"
        
        // Seed users
        let manager = createTestUser(
            uid: "manager-1",
            email: "manager@example.com",
            name: "Manager One",
            isManager: true,
            companyId: companyId
        )
        
        let barista1 = createTestUser(
            uid: "barista-1",
            email: "barista1@example.com",
            name: "Barista One",
            isManager: false,
            companyId: companyId,
            roleId: "std_barista"
        )
        
        let barista2 = createTestUser(
            uid: "barista-2",
            email: "barista2@example.com",
            name: "Barista Two",
            isManager: false,
            companyId: companyId,
            roleId: "std_barista"
        )
        
        userRepository.users = [manager, barista1, barista2]
        
        // Seed shifts
        let mondayShift = createTestShift(
            id: "shift-monday",
            dayOfWeek: .monday,
            companyId: companyId,
            assignedUserIds: ["barista-1"]
        )
        
        let tuesdayShift = createTestShift(
            id: "shift-tuesday",
            dayOfWeek: .tuesday,
            companyId: companyId,
            assignedUserIds: ["barista-2"]
        )
        
        shiftRepository.shifts = [mondayShift, tuesdayShift]
        
        // Seed roles
        let customRole = Role(
            title: "Custom Role",
            companyId: companyId,
            createdBy: "manager-1",
            createdAt: Timestamp(date: Date())
        )
        
        roleRepository.roles = [customRole]
        
        // Seed checklists
        let openingChecklist = createTestChecklist(
            id: "checklist-1",
            title: "Opening Checklist",
            companyId: companyId,
            shiftSection: .opening,
            assignedRoleIds: ["std_barista"]
        )
        
        let closingChecklist = createTestChecklist(
            id: "checklist-2",
            title: "Closing Checklist",
            companyId: companyId,
            shiftSection: .closing,
            assignedRoleIds: ["std_barista"]
        )
        
        checkListRepository.checkLists = [openingChecklist, closingChecklist]
    }
    
    // MARK: - Integration Tests
    
    func testFetchTeamMembers() {
        // Arrange
        let companyId = "test-company"
        let expectation = XCTestExpectation(description: "Fetch team members")
        
        // Act
        authService.fetchTeamMembers(companyId: companyId) { result in
            switch result {
            case .success(let teamMembers):
                // Assert
                XCTAssertEqual(teamMembers.count, 3)
                XCTAssertTrue(teamMembers.contains { $0.uid == "manager-1" })
                XCTAssertTrue(teamMembers.contains { $0.uid == "barista-1" })
                XCTAssertTrue(teamMembers.contains { $0.uid == "barista-2" })
                expectation.fulfill()
                
            case .failure(let error):
                XCTFail("Failed to fetch team members: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testFetchShifts() {
        // Arrange
        let companyId = "test-company"
        
        // Act
        shiftService.fetchShifts(for: companyId)
        
        // Assert - Wait for shifts to be loaded
        let waitExpectation = expectation(description: "Wait for shifts to be loaded")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(self.shiftService.shifts.count, 2)
            XCTAssertTrue(self.shiftService.shifts.contains { $0.id == "shift-monday" })
            XCTAssertTrue(self.shiftService.shifts.contains { $0.id == "shift-tuesday" })
            waitExpectation.fulfill()
        }
        
        wait(for: [waitExpectation], timeout: 1.0)
    }
    
    func testFetchUserShifts() {
        // Arrange
        let companyId = "test-company"
        let userId = "barista-1"
        
        // Act
        shiftService.fetchUserShifts(for: userId, in: companyId)
        
        // Assert - Wait for shifts to be loaded
        let waitExpectation = expectation(description: "Wait for user shifts to be loaded")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(self.shiftService.shifts.count, 1)
            XCTAssertEqual(self.shiftService.shifts.first?.id, "shift-monday")
            waitExpectation.fulfill()
        }
        
        wait(for: [waitExpectation], timeout: 1.0)
    }
    
    func testUpdateTask() {
        // Arrange
        let shiftId = "shift-monday"
        let taskId = "task-1"
        let expectation = XCTestExpectation(description: "Update task")
        
        // Get the shift and the task
        guard let shift = shiftRepository.shifts.first(where: { $0.id == shiftId }),
              let taskIndex = shift.tasks.firstIndex(where: { $0.id == taskId }) else {
            XCTFail("Could not find test shift or task")
            return
        }
        
        // Create an updated task
        var updatedTask = shift.tasks[taskIndex]
        updatedTask.title = "Updated Task Title"
        
        // Act
        shiftService.updateTask(in: shiftId, task: updatedTask) { success, error in
            XCTAssertTrue(success)
            XCTAssertNil(error)
            
            // Verify the task was updated in the repository
            if let updatedShift = self.shiftRepository.shifts.first(where: { $0.id == shiftId }),
               let updatedTaskIndex = updatedShift.tasks.firstIndex(where: { $0.id == taskId }) {
                XCTAssertEqual(updatedShift.tasks[updatedTaskIndex].title, "Updated Task Title")
                expectation.fulfill()
            } else {
                XCTFail("Could not find updated task")
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testFetchRoles() {
        // Arrange
        let companyId = "test-company"
        let expectation = XCTestExpectation(description: "Fetch roles")
        
        // Act
        roleService.fetchRoles(forCompany: companyId) { result in
            switch result {
            case .success(let roles):
                // Assert
                // We should get both standard roles and our custom role
                XCTAssertTrue(roles.count > 1)
                XCTAssertTrue(roles.contains { $0.title == "Custom Role" })
                expectation.fulfill()
                
            case .failure(let error):
                XCTFail("Failed to fetch roles: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testFetchCheckLists() {
        // Arrange
        let companyId = "test-company"
        let expectation = XCTestExpectation(description: "Fetch checklists")
        
        // Act
        checkListService.fetchCheckLists(for: companyId) { result in
            switch result {
            case .success(let checklists):
                // Assert
                XCTAssertEqual(checklists.count, 2)
                XCTAssertTrue(checklists.contains { $0.id == "checklist-1" })
                XCTAssertTrue(checklists.contains { $0.id == "checklist-2" })
                expectation.fulfill()
                
            case .failure(let error):
                XCTFail("Failed to fetch checklists: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testFetchCheckListsForRole() {
        // Arrange
        let companyId = "test-company"
        let roleId = "std_barista"
        let expectation = XCTestExpectation(description: "Fetch checklists for role")
        
        // Act
        checkListService.fetchCheckListsForRole(roleId: roleId, companyId: companyId) { result in
            switch result {
            case .success(let checklists):
                // Assert
                XCTAssertEqual(checklists.count, 2)
                XCTAssertTrue(checklists.contains { $0.id == "checklist-1" })
                XCTAssertTrue(checklists.contains { $0.id == "checklist-2" })
                expectation.fulfill()
                
            case .failure(let error):
                XCTFail("Failed to fetch checklists for role: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testAddTaskToChecklist() {
        // Arrange
        let checklistId = "checklist-1"
        let expectation = XCTestExpectation(description: "Add task to checklist")
        
        let newTask = CheckListTask(
            title: "New Task",
            description: "Task description"
        )
        
        // Act
        checkListService.addTask(to: checklistId, task: newTask) { result in
            switch result {
            case .success(let updatedChecklist):
                // Assert
                XCTAssertTrue(updatedChecklist.tasks.contains { $0.title == "New Task" })
                expectation.fulfill()
                
            case .failure(let error):
                XCTFail("Failed to add task to checklist: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Helper Methods
    
    private func createTestUser(
        uid: String,
        email: String,
        name: String,
        isManager: Bool,
        companyId: String,
        roleId: String = "std_manager"
    ) -> User {
        return User(
            uid: uid,
            email: email,
            name: name,
            isManager: isManager,
            roleTitle: isManager ? "Manager" : "Barista",
            roleId: roleId,
            companyId: companyId,
            companyName: "Test Company",
            createdAt: Date()
        )
    }
    
    private func createTestShift(
        id: String,
        dayOfWeek: Shift.DayOfWeek,
        companyId: String,
        assignedUserIds: [String]
    ) -> Shift {
        let startTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
        let endTime = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()
        
        var shift = Shift(
            dayOfWeek: dayOfWeek,
            startTime: startTime,
            endTime: endTime,
            assignedToUIDs: assignedUserIds,
            companyId: companyId,
            tasks: [],
            status: .scheduled,
            lastUpdatedBy: "manager-1",
            lastUpdatedAt: Date()
        )
        
        shift.id = id
        
        // Add a test task to the shift
        let task = ShiftTask(
            id: "task-1",
            title: "Test Task",
            description: "Test task description",
            isCompleted: false,
            priority: .medium,
            requiresPhotoProof: false,
            createdAt: Date()
        )
        
        shift.tasks = [task]
        
        return shift
    }
    
    private func createTestChecklist(
        id: String,
        title: String,
        companyId: String,
        shiftSection: CheckList.ShiftSection,
        assignedRoleIds: [String]
    ) -> CheckList {
        var checklist = CheckList(
            title: title,
            frequency: .everyShift,
            shiftSection: shiftSection,
            tasks: [],
            companyId: companyId,
            createdByUID: "manager-1",
            createdAt: Date(),
            assignedRoleIds: assignedRoleIds
        )
        
        checklist.id = id
        
        // Add test tasks to the checklist
        let task1 = CheckListTask(
            id: "checklist-task-1",
            title: "Checklist Task 1",
            description: "Description for task 1"
        )
        
        let task2 = CheckListTask(
            id: "checklist-task-2",
            title: "Checklist Task 2",
            description: "Description for task 2"
        )
        
        checklist.tasks = [task1, task2]
        
        return checklist
    }
}
