//
//  EditShiftViewWithTaskEditingRepo.swift
//  ShiftFlow
//
//  Created by Kirill P on 14/04/2025.
//

import SwiftUI
import FirebaseFirestore

@MainActor
struct EditShiftViewWithTaskEditingRepo: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var shiftService: ShiftServiceWithRepo
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var roleService: RoleServiceWithRepo
    @EnvironmentObject var authService: FirebaseAuthenticationServiceWithRepo

    @State var shift: Shift // Use @State to allow modifications locally
    @State private var assignedUserIds: [String] // Local state for managing user assignments
    @State private var showingAddTaskSheet = false
    @State private var showingEditTaskSheet = false
    @State private var showingAssignUsersSheet = false
    @State private var selectedTask: ShiftTask?
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var showSuccess = false

    // Task Management for saving/deleting tasks
    @StateObject private var taskManager = TaskManager()

    // Cache for assigned user names
    @State private var assignedUserNames: [String: String] = [:]
    @State private var isLoadingNames = false

    init(shift: Shift) {
        _shift = State(initialValue: shift)
        _assignedUserIds = State(initialValue: shift.assignedToUIDs)
    }

    var body: some View {
        Form {
            // Shift Details Section
            makeShiftDetailsSection()
            
            // Assigned Baristas Section
            makeAssignedBaristasSection()
            
            // Tasks Section
            makeTasksSection()
            
            // Save Button
            makeSaveButtonSection()
        }
        .navigationTitle("Edit Shift")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
            }
        }
        .sheet(isPresented: $showingAddTaskSheet, onDismiss: nil) {
            makeAddTaskSheet()
        }
        .sheet(isPresented: $showingEditTaskSheet, onDismiss: refreshLocalShiftData) {
            makeEditTaskSheet()
        }
        .sheet(isPresented: $showingAssignUsersSheet) {
            makeAssignUsersSheet()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { errorMessage = "" }
        } message: {
            Text(errorMessage)
        }
        .alert("Success", isPresented: $showSuccess) {
            Button("OK") { presentationMode.wrappedValue.dismiss() }
        } message: {
            Text("Shift updated successfully.")
        }
        .task { await loadAssignedUserNames() }
        .onDisappear {
            taskManager.cancelAllTasks()
        }
    }
    
    // MARK: - Section Builders
    
    private func makeShiftDetailsSection() -> some View {
        Section {
            HStack {
                Text("Day of Week")
                Spacer()
                Text(shift.dayOfWeek.displayName).foregroundColor(.gray)
            }

            DatePicker(
                "Start Time",
                selection: Binding<Date>(
                    get: { self.shift.startTime.dateValue() },
                    set: { self.shift.startTime = Timestamp(date: $0) }
                ),
                displayedComponents: .hourAndMinute
            )
            
            DatePicker(
                "End Time",
                selection: Binding<Date>(
                    get: { self.shift.endTime.dateValue() },
                    set: { self.shift.endTime = Timestamp(date: $0) }
                ),
                displayedComponents: .hourAndMinute
            )

            makeStatusPicker()
        } header: {
            Text("Shift Details")
        }
    }
    
    private func makeStatusPicker() -> some View {
        // Using the correct ShiftStatus cases from your model
        let statuses: [(title: String, status: Shift.ShiftStatus)] = [
            ("Scheduled", .scheduled),
            ("In Progress", .inProgress),
            ("Completed", .completed),
            ("Cancelled", .cancelled)
        ]
        
        return Picker("Status", selection: $shift.status) {
            ForEach(statuses, id: \.status) { item in
                Text(item.title).tag(item.status)
            }
        }
    }
    
    private func makeAssignedBaristasSection() -> some View {
        Section {
            Button {
                showingAssignUsersSheet = true
            } label: {
                HStack {
                    if isLoadingNames {
                        ProgressView()
                    }
                    Text(assignedUsersDisplay)
                        .foregroundColor(assignedUserIds.isEmpty ? .gray : .primary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .foregroundColor(.primary)
            }
        } header: {
            Text("Assigned Baristas")
        }
    }
    
    private func makeTasksSection() -> some View {
        Section {
            if shift.tasks.isEmpty {
                Text("No tasks assigned").foregroundColor(.gray)
            } else {
                ForEach(shift.tasks) { task in
                    Button {
                        selectedTask = task
                        showingEditTaskSheet = true
                    } label: {
                        TaskRow(task: task)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteTask)
            }
        } header: {
            makeTasksHeader()
        }
    }
    
    private func makeTasksHeader() -> some View {
        HStack {
            Text("Tasks")
            Spacer()
            Button {
                showingAddTaskSheet = true
            } label: {
                Image(systemName: "plus.circle.fill")
            }
        }
    }
    
    private func makeSaveButtonSection() -> some View {
        Section {
            Button {
                Task {
                    do {
                        try await saveShift()
                    } catch {
                        setError(error.localizedDescription)
                    }
                }
            } label: {
                Text("Save Shift Changes")
                    .frame(maxWidth: .infinity)
            }
            .disabled(isLoading)
        }
    }
    
    // MARK: - Sheet Builders
    
    private func makeAddTaskSheet() -> some View {
        NavigationView {
            AddTaskViewRepo { newTask in
                shift.tasks.append(newTask)
            }
            .environmentObject(userState)
            .environmentObject(roleService)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { showingAddTaskSheet = false }
                }
            }
        }
    }
    
    private func makeEditTaskSheet() -> some View {
        Group {
            if let task = selectedTask {
                EditShiftTaskViewRepoWrapper(task: task, shiftId: shift.id ?? "")
            }
        }
    }
    
    private func makeAssignUsersSheet() -> some View {
        NavigationView {
            AssignUsersViewRepoWrapper(
                assignedUserIds: $assignedUserIds,
                companyId: userState.currentUser?.companyId ?? ""
            )
        }
    }
    
    // MARK: - Computed Properties
    
    var assignedUsersDisplay: String {
        if assignedUserIds.isEmpty { return "Assign Baristas..." }
        let namesToShow = assignedUserIds.prefix(3).compactMap { assignedUserNames[$0] ?? $0 }.joined(separator: ", ")
        let remainingCount = assignedUserIds.count - 3
        return namesToShow + (remainingCount > 0 ? " +\(remainingCount) others" : "")
    }
    
    // MARK: - Data Handling Methods

    private func refreshLocalShiftData() {
        guard let shiftId = shift.id else { return }
        taskManager.startTask(id: "refreshLocalShift_\(shiftId)") {
            do {
                let freshShift = try await shiftService.shiftRepository.get(byId: shiftId)
                self.shift = freshShift
            } catch {
                print("Error refreshing local shift data: \(error)")
            }
        }
    }

    private func loadAssignedUserNames() async {
        guard !assignedUserIds.isEmpty else { return }
        guard let companyId = userState.currentUser?.companyId else { return }
        
        isLoadingNames = true
        taskManager.startTask(id: "loadAssigneeNames") {
            do {
                let members = try await authService.fetchTeamMembers(companyId: companyId)
                var namesDict: [String: String] = [:]
                for member in members where assignedUserIds.contains(member.uid) {
                    namesDict[member.uid] = member.name
                }
                await MainActor.run {
                    self.assignedUserNames = namesDict
                    self.isLoadingNames = false
                }
            } catch {
                await MainActor.run {
                    print("Error loading assigned user names: \(error)")
                    self.isLoadingNames = false
                }
            }
        }
    }

    private func deleteTask(at offsets: IndexSet) {
        guard let shiftId = shift.id else { return }
        let tasksToDelete = offsets.map { shift.tasks[$0] }

        shift.tasks.remove(atOffsets: offsets)

        for task in tasksToDelete {
            guard let taskId = task.id else { continue }
            taskManager.startTaskWithHandlers(
                id: "deleteTask_\(taskId)",
                operation: {
                    return try await shiftService.removeTask(from: shiftId, taskId: taskId)
                },
                onSuccess: { _ in
                    print("Task \(taskId) deleted successfully from backend.")
                },
                onError: { error in
                    setError("Failed to delete task '\(task.title)': \(error.localizedDescription)")
                    refreshLocalShiftData()
                }
            )
        }
    }

    private func saveShift() async throws {
        guard let shiftId = shift.id, let currentUserId = userState.currentUser?.uid else {
            throw NSError(domain: "ShiftError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Shift or User ID missing"])
        }

        var shiftToSave = shift
        shiftToSave.assignedToUIDs = assignedUserIds
        shiftToSave.lastUpdatedBy = currentUserId
        shiftToSave.lastUpdatedAt = Timestamp(date: Date())

        let savedShift = try await shiftService.updateShift(shiftToSave)

        self.shift = savedShift
        self.showSuccess = true
    }

    private func setError(_ message: String) {
        print("Error: \(message)")
        self.errorMessage = message
        self.showError = true
        self.isLoading = false
    }
}


