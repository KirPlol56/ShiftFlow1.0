//
//  AddCheckListViewRepo.swift
//  ShiftFlow
//
//  Created by Kirill P on 14/03/2025.
//

import SwiftUI
import FirebaseFirestore

@MainActor
struct AddCheckListViewRepo: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var checkListService: CheckListServiceWithRepo
    @EnvironmentObject var roleService: RoleServiceWithRepo

    // State variables for the form
    @State private var title = ""
    @State private var frequencyType = 0 // 0: EveryShift, 1: SpecificDay, 2: SpecificDate
    @State private var selectedDay: Shift.DayOfWeek = .monday
    @State private var selectedDate = Date()
    @State private var shiftSection: CheckList.ShiftSection = .during
    @State private var checkListTasks: [CheckListTask] = []
    @State private var assignedRoleIds: [String] = []

    // UI state
    @State private var showingAddTaskSheet = false
    @State private var showingRolesSheet = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var showSuccess = false

    // Task management
    @StateObject private var taskManager = TaskManager()

    var body: some View {
        NavigationView {
            Form {
                // Check List Details
                Section(header: Text("Check List Details")) {
                    TextField("Title", text: $title)

                    Picker("Frequency Type", selection: $frequencyType) {
                        Text("Every Shift").tag(0)
                        Text("Specific Day").tag(1)
                        Text("Specific Date").tag(2)
                    }
                    .pickerStyle(SegmentedPickerStyle())

                    if frequencyType == 1 {
                        Picker("Day of Week", selection: $selectedDay) {
                            ForEach(Shift.DayOfWeek.allCases, id: \.self) { day in
                                Text(day.displayName).tag(day)
                            }
                        }
                    } else if frequencyType == 2 {
                        DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                    }

                    Picker("Shift Section", selection: $shiftSection) {
                        ForEach(CheckList.ShiftSection.allCases, id: \.self) { section in
                            Text(section.displayName).tag(section)
                        }
                    }
                }

                // Role Assignment Section
                Section(header: Text("Assign to Roles (Optional)")) {
                    Button(action: { showingRolesSheet = true }) {
                        HStack {
                            Text(assignedRoleIds.isEmpty ? "Assign Roles..." : "\(assignedRoleIds.count) Role(s) Selected")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .foregroundColor(.primary)
                    }
                }

                // Tasks Section
                Section(header: HStack {
                    Text("Tasks")
                    Spacer()
                    Button(action: { showingAddTaskSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                }) {
                    if checkListTasks.isEmpty {
                        Text("No tasks added")
                            .foregroundColor(.gray)
                            .italic()
                    } else {
                        ForEach(checkListTasks) { task in
                            VStack(alignment: .leading) {
                                Text(task.title)
                                    .font(.headline)
                                if !task.description.isEmpty {
                                    Text(task.description)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .onDelete(perform: deleteTasks)
                    }
                }

                // Save Button
                Section {
                    AsyncButton("Create Check List") {
                        try await saveCheckList()
                    } onError: { error in
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(!isFormValid)
                }
            }
            .navigationTitle("New Check List")
            .navigationBarItems(trailing: Button("Cancel") {
                taskManager.cancelAllTasks()
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $showingAddTaskSheet) {
                AddTaskSheet(onTaskCreated: { task in
                    checkListTasks.append(task)
                })
            }
            .sheet(isPresented: $showingRolesSheet) {
                NavigationView {
                    RoleSelectionSheet(selectedRoleIds: $assignedRoleIds)
                        .environmentObject(roleService)
                        .environmentObject(userState)
                }
            }
            .alert(isPresented: $showError) {
                Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
            }
            .alert(isPresented: $showSuccess) {
                Alert(
                    title: Text("Success"),
                    message: Text("Check list created successfully."),
                    dismissButton: .default(Text("OK")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
            .onDisappear {
                taskManager.cancelAllTasks()
            }
        }
        .navigationViewStyle(.stack)
    }

    // Form validation
    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && !checkListTasks.isEmpty
    }

    // Handle task deletion
    private func deleteTasks(at offsets: IndexSet) {
        checkListTasks.remove(atOffsets: offsets)
    }

    // Save checklist
    private func saveCheckList() async throws {
        guard let currentUser = userState.currentUser,
              let companyId = currentUser.companyId else {
            throw NSError(domain: "CheckListError", code: 0, userInfo: [NSLocalizedDescriptionKey: "User information not found"])
        }

        // Create frequency based on selection
        let frequency: CheckList.Frequency
        switch frequencyType {
        case 0: frequency = .everyShift
        case 1: frequency = .specificDay(dayOfWeek: selectedDay)
        case 2: frequency = .specificDate(date: Timestamp(date: selectedDate))
        default: frequency = .everyShift
        }

        // Create CheckList object
        let checkList = CheckList(
            title: title.trimmingCharacters(in: .whitespaces),
            frequency: frequency,
            shiftSection: shiftSection,
            tasks: checkListTasks,
            companyId: companyId,
            createdByUID: currentUser.uid,
            createdAt: Date(),
            assignedRoleIds: assignedRoleIds
        )

        // Using TaskManager for task handling
        return try await taskManager.withTask(id: "saveCheckList") {
            // Fix: Replace with underscore assignment since createdList is unused
            _ = try await checkListService.createCheckList(checkList)
            await MainActor.run {
                showSuccess = true
            }
            return
        }
    }
}

// MARK: - Task Adding Sheet
struct AddTaskSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var title = ""
    @State private var description = ""
    var onTaskCreated: (CheckListTask) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Details")) {
                    TextField("Task Title", text: $title)
                    TextField("Description (Optional)", text: $description, axis: .vertical)
                        .lineLimit(3...)
                }
                Section {
                    Button("Add Task") {
                        createTask()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(title.isEmpty)
                }
            }
            .navigationTitle("Add Task to Check List")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }

    private func createTask() {
        let newTask = CheckListTask(
            title: title.trimmingCharacters(in: .whitespaces),
            description: description.trimmingCharacters(in: .whitespaces)
        )
        onTaskCreated(newTask)
        presentationMode.wrappedValue.dismiss()
    }
}



// MARK: - Helper Views
struct AddCheckListTaskViewRepo: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var title = ""
    @State private var description = ""
    var onTaskCreated: (CheckListTask) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Details")) {
                    TextField("Task Title", text: $title)
                    TextField("Description (Optional)", text: $description, axis: .vertical)
                        .lineLimit(3...)
                }
                Section {
                    Button("Add Task") {
                        createTask()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(title.isEmpty)
                }
            }
            .navigationTitle("Add Task to Check List")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }

    private func createTask() {
        // Create CheckListTask
        let newTask = CheckListTask(
            title: title.trimmingCharacters(in: .whitespaces),
            description: description.trimmingCharacters(in: .whitespaces)
        )
        
        onTaskCreated(newTask)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Role Row
struct RoleRow: View {
    let role: Role
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(role.title)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    if role.isStandardRole {
                        Text("Standard")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title3)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - TaskManager Extension
extension TaskManager {
    // Helper to perform a task and return its result
    func withTask<T>(id: String, priority: TaskPriority? = nil, operation: @escaping () async throws -> T) async throws -> T {
        // Create a throwing continuation to bridge the gap
        return try await withCheckedThrowingContinuation { continuation in
            startTaskWithHandlers(
                id: id,
                priority: priority,
                operation: operation,
                onSuccess: { result in
                    continuation.resume(returning: result)
                },
                onError: { error in
                    continuation.resume(throwing: error)
                }
            )
        }
    }
}
