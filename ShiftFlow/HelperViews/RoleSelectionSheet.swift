//
//  RoleSelectionSheet.swift
//  ShiftFlow
//
//  Created by Kirill P on 29/04/2025.
//

import SwiftUI

struct RoleSelectionSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var roleService: RoleServiceWithRepo
    @EnvironmentObject var userState: UserState
    @Binding var selectedRoleIds: [String]
    
    @State private var roles: [Role] = []
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var searchText = ""
    
    // Create a dictionary to store role titles by ID for display
    @State private var roleTitles: [String: String] = [:]
    
    @StateObject private var taskManager = TaskManager()
    
    // Filtered roles based on search text
    private var filteredRoles: [Role] {
        if searchText.isEmpty {
            return roles
        } else {
            return roles.filter { role in
                role.title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search roles", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            
            // Main content
            if isLoading {
                ProgressView("Loading roles...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if roles.isEmpty {
                EmptyStateView(
                    title: "No Roles Available",
                    message: "No roles have been created yet.",
                    systemImage: "person.badge.shield.checkmark"
                )
            } else if filteredRoles.isEmpty {
                EmptyStateView(
                    title: "No Results",
                    message: "No roles found matching '\(searchText)'",
                    systemImage: "magnifyingglass"
                )
            } else {
                List {
                    ForEach(filteredRoles) { role in
                        RoleRow(
                            role: role,
                            isSelected: selectedRoleIds.contains(role.id ?? ""),
                            onToggle: { toggleRole(role: role) }
                        )
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
        }
        .navigationTitle("Select Roles")
        .navigationBarItems(
            leading: Button("Cancel") { presentationMode.wrappedValue.dismiss() },
            trailing: Button("Done") { presentationMode.wrappedValue.dismiss() }
        )
        .task {
            await loadRoles()
        }
        .alert(isPresented: $showError) {
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
        .onDisappear {
            taskManager.cancelAllTasks()
        }
    }
    
    private func toggleRole(role: Role) {
        guard let roleId = role.id else { return }
        
        if selectedRoleIds.contains(roleId) {
            selectedRoleIds.removeAll { $0 == roleId }
        } else {
            selectedRoleIds.append(roleId)
        }
    }
    
    private func loadRoles() async {
        guard let companyId = userState.currentUser?.companyId else { return }
        
        isLoading = true
        errorMessage = ""
        
        taskManager.startTaskWithHandlers(
            id: "loadRoles",
            operation: {
                try await roleService.fetchRoles(forCompany: companyId)
            },
            onSuccess: { fetchedRoles in
                self.roles = fetchedRoles.sorted { $0.title < $1.title }
                
                // Build dictionary of titles for faster lookup
                var titles: [String: String] = [:]
                for role in fetchedRoles {
                    if let id = role.id {
                        titles[id] = role.title
                    }
                }
                self.roleTitles = titles
                self.isLoading = false
            },
            onError: { error in
                self.errorMessage = "Failed to load roles: \(error.localizedDescription)"
                self.showError = true
                self.isLoading = false
            }
        )
    }
}
