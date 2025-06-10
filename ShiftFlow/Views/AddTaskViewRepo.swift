//
//  AddTaskViewRepo.swift
//  ShiftFlow
//
//  Created by Kirill P on 13/03/2025.
//

import SwiftUI

struct AddTaskViewRepo: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var roleService: RoleServiceWithRepo // Repository-based service
    
    @State private var title = ""
    @State private var description = ""
    @State private var priority: ShiftTask.TaskPriority = .medium
    @State private var requiresPhotoProof = false
    @State private var showPhotoProofInfo = false
    @State private var assignedRoleIds: [String] = []
    @State private var showingAssignRolesSheet = false
    
    var onTaskCreated: (ShiftTask) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Details")) {
                    TextField("Task Title", text: $title)
                    
                    TextField("Description (Optional)", text: $description)
                        .frame(height: 100)
                }
                
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
                
                Section(header: Text("Assign to Roles (Optional)")) {
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
                
                Section(header: Text("Completion Requirements")) {
                    Toggle("Require Photo Proof", isOn: $requiresPhotoProof)
                    
                    if requiresPhotoProof {
                        Button(action: { showPhotoProofInfo = true }) {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                Text("About Photo Proof")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: createTask) {
                        Text("Add Task")
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .disabled(!isFormValid)
                }
            }
            .navigationTitle("Add Task")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            
            .sheet(isPresented: $showingAssignRolesSheet) {
                NavigationView {
                    AssignUsersViewRepo(assignedIds: $assignedRoleIds, companyId: userState.currentUser?.companyId ?? "")
                        .environmentObject(roleService)
                        .navigationTitle("Assign Roles")
                        .navigationBarItems(trailing: Button("Done") { showingAssignRolesSheet = false })
                }
            }
            .alert(isPresented: $showPhotoProofInfo) {
                Alert(
                    title: Text("About Photo Proof"),
                    message: Text("Tasks with photo proof require baristas to take a photo to verify completion. The photo will be stored securely and viewable by managers."),
                    dismissButton: .default(Text("Got it"))
                )
            }
        }
    }
    
    private var isFormValid: Bool {
        !title.isEmpty
    }
    
    private func createTask() {
        // If this requires a photo proof, we'll create a special task
        let newTask: ShiftTask
        
        if requiresPhotoProof {
            newTask = ShiftTask(
                title: title,
                description: description,
                isCompleted: false,
                priority: priority,
                requiresPhotoProof: true,
                assignedRoleIds: assignedRoleIds
            )
        } else {
            // Regular task
            newTask = ShiftTask(
                title: title,
                description: description,
                isCompleted: false,
                priority: priority,
                requiresPhotoProof: false,
                assignedRoleIds: assignedRoleIds
            )
        }
        
        onTaskCreated(newTask)
        presentationMode.wrappedValue.dismiss()
    }
}
