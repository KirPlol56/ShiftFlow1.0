//
//  EditShiftTaskViewRepo.swift
//  ShiftFlow
//
//  Created by Kirill P on 28/04/2025.
//

import SwiftUI
import FirebaseFirestore

/// A much simpler implementation of the task edit view that avoids complex nested functions and task management
@MainActor
struct EditShiftTaskViewRepo: View {
    // Environment
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var shiftService: ShiftServiceWithRepo
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var roleService: RoleServiceWithRepo
    
    // Input parameters
    let originalTask: ShiftTask
    let shiftId: String
    
    // Form state
    @State private var title: String
    @State private var description: String
    @State private var priority: ShiftTask.TaskPriority
    @State private var requiresPhotoProof: Bool
    @State private var assignedRoleIds: [String]
    
    // UI state
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var showSuccess = false
    @State private var showingAssignRolesSheet = false
    @State private var showingDeleteConfirmation = false
    
    // Use a simpler TaskManager instead of manual Task variables
    @StateObject private var taskManager = TaskManager()
    
    init(task: ShiftTask, shiftId: String) {
        self.originalTask = task
        self.shiftId = shiftId
        
        // Initialize state from original task
        _title = State(initialValue: task.title)
        _description = State(initialValue: task.description)
        _priority = State(initialValue: task.priority)
        _requiresPhotoProof = State(initialValue: task.requiresPhotoProof)
        _assignedRoleIds = State(initialValue: task.assignedRoleIds ?? [])
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Task Details
                Section(header: Text("Task Details")) {
                    TextField("Task Title", text: $title)
                    
                    TextField("Description (Optional)", text: $description, axis: .vertical)
                        .lineLimit(3...)
                }
                
                // Priority
                Section(header: Text("Priority")) {
                    Picker("Priority", selection: $priority) {
                        ForEach(ShiftTask.TaskPriority.allCases, id: \.self) { priority in
                            HStack {
                                Circle()
                                    .fill(priority.color)
                                    .frame(width: 16, height: 16)
                                Text(priority.displayValue)
                            }
                            .tag(priority)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                // Role Assignment
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
                
                // Completion Requirements
                Section(header: Text("Completion Requirements")) {
                    Toggle("Require Photo Proof", isOn: $requiresPhotoProof)
                    
                    if requiresPhotoProof {
                        Text("Baristas will need to take a photo to verify task completion.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                // Completion Status (read-only if completed)
                if originalTask.isCompleted {
                    Section(header: Text("Completion Status")) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Task has been completed")
                                .foregroundColor(.green)
                        }
                        
                        if let completedBy = originalTask.completedBy, let completedAt = originalTask.completedAt {
                            Text("Completed by: \(completedBy)")
                                .font(.caption)
                            Text("Completed at: \(formatDate(completedAt.dateValue()))")
                                .font(.caption)
                        }
                        
                        if originalTask.photoURL != nil {
                            Text("Photo proof was provided")
                                .font(.caption)
                        }
                    }
                }
                
                // Action Buttons
                Section {
                    Button("Save Changes") {
                        saveTask()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(!isFormValid || isLoading)
                    
                    Button(action: { showingDeleteConfirmation = true }) {
                        HStack {
                            Spacer()
                            Text("Delete Task")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                    .disabled(isLoading)
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarItems(leading: Button("Cancel") {
                taskManager.cancelAllTasks()
                presentationMode.wrappedValue.dismiss()
            })
            .overlay {
                if isLoading {
                    ProgressView("Processing...")
                        .frame(width: 150, height: 100)
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 3)
                }
            }
            .sheet(isPresented: $showingAssignRolesSheet) {
                NavigationView {
                    RoleSelectionViewWrapper(selectedRoleIds: $assignedRoleIds)
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
                Text("Task updated successfully.")
            }
            .alert("Confirm Deletion", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteTask()
                }
            } message: {
                Text("Are you sure you want to delete this task? This action cannot be undone.")
            }
        }
        .onDisappear {
            taskManager.cancelAllTasks()
        }
    }
    
    // MARK: - Helper Methods
    
    // Format date for display
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Validate form
    private var isFormValid: Bool {
        return !title.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // Save task using TaskManager instead of raw Task
    private func saveTask() {
        guard !isLoading else { return }
        // Fix: Remove unused variable assignment and use direct condition
        if originalTask.id == nil {
            self.errorMessage = "Task ID is missing."
            self.showError = true
            return
        }
        
        // Create updated task
        var updatedTask = originalTask
        updatedTask.title = title.trimmingCharacters(in: .whitespaces)
        updatedTask.description = description.trimmingCharacters(in: .whitespaces)
        updatedTask.priority = priority
        updatedTask.requiresPhotoProof = requiresPhotoProof
        updatedTask.assignedRoleIds = assignedRoleIds
        
        isLoading = true
        
        // Use TaskManager for async operations
        taskManager.startTaskWithHandlers(
            id: "saveTask",
            operation: {
                try await shiftService.updateTask(in: shiftId, task: updatedTask)
            },
            onSuccess: { _ in
                isLoading = false
                showSuccess = true
            },
            onError: { error in
                isLoading = false
                errorMessage = "Failed to save: \(error.localizedDescription)"
                showError = true
            }
        )
    }
    
    // Delete task using TaskManager instead of raw Task
    private func deleteTask() {
        guard !isLoading else { return }
        guard let taskId = originalTask.id else {
            self.errorMessage = "Task ID is missing."
            self.showError = true
            return
        }
        
        isLoading = true
        
        // Use TaskManager for async operations
        taskManager.startTaskWithHandlers(
            id: "deleteTask",
            operation: {
                try await shiftService.removeTask(from: shiftId, taskId: taskId)
            },
            onSuccess: { _ in
                isLoading = false
                presentationMode.wrappedValue.dismiss()
            },
            onError: { error in
                isLoading = false
                errorMessage = "Failed to delete: \(error.localizedDescription)"
                showError = true
            }
        )
    }
}
