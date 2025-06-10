//
//  EditCheckListViewRepo.swift
//  ShiftFlow
//
//  Created by Kirill P on 14/03/2025.
//

import SwiftUI
import FirebaseFirestore

struct EditCheckListViewRepo: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var checkListService: CheckListServiceWithRepo
    @EnvironmentObject var roleService: RoleServiceWithRepo
    
    let originalCheckList: CheckList
    
    // State for editing
    @State private var title: String
    @State private var frequencyType: Int
    @State private var selectedDay: Shift.DayOfWeek
    @State private var selectedDate: Date
    @State private var shiftSection: CheckList.ShiftSection
    @State private var tasks: [CheckListTask]
    @State private var assignedRoleIds: [String]
    
    // UI state
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var showSuccess = false
    @State private var showingAddTaskSheet = false
    @State private var showingAssignRolesSheet = false
    @State private var showingDeleteConfirmation = false
    
    init(checkList: CheckList) {
        self.originalCheckList = checkList
        
        // Initialize state properties
        _title = State(initialValue: checkList.title)
        _tasks = State(initialValue: checkList.tasks)
        _shiftSection = State(initialValue: checkList.shiftSection)
        _assignedRoleIds = State(initialValue: checkList.assignedRoleIds ?? [])
        
        // Initialize frequency-related state
        switch checkList.frequency {
        case .everyShift:
            _frequencyType = State(initialValue: 0)
            _selectedDay = State(initialValue: .monday)
            _selectedDate = State(initialValue: Date())
        case .specificDay(let day):
            _frequencyType = State(initialValue: 1)
            _selectedDay = State(initialValue: day)
            _selectedDate = State(initialValue: Date())
        case .specificDate(let timestamp):
            _frequencyType = State(initialValue: 2)
            _selectedDay = State(initialValue: .monday)
            _selectedDate = State(initialValue: timestamp.dateValue())
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Checklist details section
                Section(header: Text("Check List Details")) {
                    TextField("Title", text: $title)
                    
                    Picker("Frequency", selection: $frequencyType) {
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
                
                // Role assignment section
                Section(header: Text("Assign to Roles")) {
                    Button(action: { showingAssignRolesSheet = true }) {
                        HStack {
                            Text(assignedRoleIds.isEmpty ? "Assign Roles..." : "\(assignedRoleIds.count) Role(s) Selected")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .foregroundColor(.primary)
                    }
                }
                
                // Tasks section
                Section(header: HStack {
                    Text("Tasks")
                    Spacer()
                    Button(action: { showingAddTaskSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                }) {
                    if tasks.isEmpty {
                        Text("No tasks added")
                            .foregroundColor(.gray)
                            .italic()
                    } else {
                        ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                            VStack(alignment: .leading, spacing: 4) {
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
                
                // Action buttons
                Section {
                    Button(action: saveCheckList) {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                            } else {
                                Text("Save Changes")
                            }
                            Spacer()
                        }
                    }
                    .disabled(isLoading || !isFormValid)
                    
                    Button(action: { showingDeleteConfirmation = true }) {
                        HStack {
                            Spacer()
                            Text("Delete Check List")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                    .disabled(isLoading)
                }
            }
            .navigationTitle("Edit Check List")
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $showingAddTaskSheet) {
                AddCheckListTaskViewRepo { newTask in
                    tasks.append(newTask)
                }
            }
            .sheet(isPresented: $showingAssignRolesSheet) {
                NavigationView {
                    // Extract the navigation content to reduce complexity
                    RoleSelectionContent(
                        assignedRoleIds: $assignedRoleIds,
                        companyId: userState.currentUser?.companyId ?? "",
                        roleService: roleService,
                        onDismiss: { showingAssignRolesSheet = false }
                    )
                }
            }
            .alert(isPresented: $showError) {
                Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK") {
                    presentationMode.wrappedValue.dismiss()
                }
            } message: {
                Text("Check list updated successfully.")
            }
            .alert("Confirm Deletion", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteCheckList()
                }
            } message: {
                Text("Are you sure you want to delete this check list? This action cannot be undone.")
            }
        }
    }
    
    // Validate form before saving
    private var isFormValid: Bool {
        return !title.trimmingCharacters(in: .whitespaces).isEmpty && !tasks.isEmpty
    }
    
    // Delete tasks at specified indices
    private func deleteTasks(at offsets: IndexSet) {
        tasks.remove(atOffsets: offsets)
    }
    
    // Save updated checklist using repository-based service
    private func saveCheckList() {
        guard let checkListId = originalCheckList.id else {
            errorMessage = "Missing checklist ID."
            showError = true
            return
        }
        
        isLoading = true
        
        // Create updated frequency based on selection
        let frequency: CheckList.Frequency
        switch frequencyType {
        case 0:
            frequency = .everyShift
        case 1:
            frequency = .specificDay(dayOfWeek: selectedDay)
        case 2:
            frequency = .specificDate(date: Timestamp(date: selectedDate))
        default:
            frequency = .everyShift
        }
        
        // Create updated checklist object
        let updatedCheckList = CheckList(
            id: checkListId,
            title: title.trimmingCharacters(in: .whitespaces),
            frequency: frequency,
            shiftSection: shiftSection,
            tasks: tasks,
            companyId: originalCheckList.companyId,
            createdByUID: originalCheckList.createdByUID,
            createdAt: originalCheckList.createdAt.dateValue(),
            assignedRoleIds: assignedRoleIds
        )
        
        // Use repository-based service
        checkListService.updateCheckList(updatedCheckList) { result in
            isLoading = false
            
            switch result {
            case .success:
                showSuccess = true
            case .failure(let error):
                errorMessage = "Failed to update checklist: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    // Delete the checklist using repository-based service
    private func deleteCheckList() {
        guard let checkListId = originalCheckList.id else {
            errorMessage = "Checklist ID is missing."
            showError = true
            return
        }
        
        isLoading = true
        
        checkListService.deleteCheckList(id: checkListId) { result in
            isLoading = false
            
            switch result {
            case .success:
                presentationMode.wrappedValue.dismiss()
            case .failure(let error):
                errorMessage = "Failed to delete checklist: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}


// Add/Edit task view for checklist tasks
struct EditCheckListTaskView: View {
    @Environment(\.presentationMode) var presentationMode
    let task: CheckListTask
    let onSave: (CheckListTask) -> Void
    
    @State private var title: String
    @State private var description: String
    
    init(task: CheckListTask, onSave: @escaping (CheckListTask) -> Void) {
        self.task = task
        self.onSave = onSave
        _title = State(initialValue: task.title)
        _description = State(initialValue: task.description)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Details")) {
                    TextField("Title", text: $title)
                    TextField("Description (Optional)", text: $description, axis: .vertical)
                        .lineLimit(3...)
                }
                
                Section {
                    Button("Save Changes") {
                        let updatedTask = CheckListTask(
                            id: task.id,
                            title: title.trimmingCharacters(in: .whitespaces),
                            description: description.trimmingCharacters(in: .whitespaces)
                        )
                        onSave(updatedTask)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
