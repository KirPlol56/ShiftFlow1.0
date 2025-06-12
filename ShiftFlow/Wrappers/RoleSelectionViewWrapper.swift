//
//  RoleSelectionViewWrapper.swift
//  ShiftFlow
//
//  Created by Kirill P on 29/04/2025.
//

import SwiftUI

// Wrapper view to simplify the sheet presentation of role selection
struct RoleSelectionViewWrapper: View {
    @Binding var selectedRoleIds: [String]
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var roleService: RoleServiceWithRepo
    @EnvironmentObject var userState: UserState
    
    var body: some View {
        // Instead of using ContentUnavailableView, use a simple role selection list
        SimpleRoleSelectionView(
            selectedRoleIds: $selectedRoleIds,
            companyId: userState.currentUser?.companyId ?? ""
        )
        .environmentObject(roleService)
        .navigationTitle("Assign Roles")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

// Simple role selection view that doesn't use ContentUnavailableView
struct SimpleRoleSelectionView: View {
    @Binding var selectedRoleIds: [String]
    let companyId: String
    
    @EnvironmentObject var roleService: RoleServiceWithRepo
    @State private var roles: [Role] = []
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var searchText = ""
    
    // Use TaskManager for async operations
    @StateObject private var taskManager = TaskManager()
    
    // Filter roles by search text
    private var filteredRoles: [Role] {
        if searchText.isEmpty {
            return roles
        } else {
            return roles.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search field
            searchField
            
            // Main content
            mainContent
        }
        .task {
            await loadRoles()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { errorMessage = "" }
        } message: {
            Text(errorMessage)
        }
        .onDisappear {
            taskManager.cancelAllTasks()
        }
    }
    
    // MARK: - Subviews
    
    private var searchField: some View {
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
    }
    
    @ViewBuilder
    private var mainContent: some View {
        if isLoading {
            loadingView
        } else if roles.isEmpty {
            emptyRolesView
        } else if filteredRoles.isEmpty && !searchText.isEmpty {
            emptySearchView
        } else {
            rolesList
        }
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView("Loading roles...")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyRolesView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.badge.shield.checkmark")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text("No Roles Available")
                .font(.headline)
            Text("No roles have been created yet.")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptySearchView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text("No Results")
                .font(.headline)
            Text("No roles matching '\(searchText)'")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var rolesList: some View {
        List {
            ForEach(filteredRoles) { role in
                roleRow(role)
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
        
        private func roleRow(_ role: Role) -> some View {
            Button {
                toggleSelection(role)
            } label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text(role.title)
                            .font(.headline)
                        if role.isStandardRole {
                            Text("Standard Role")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    Spacer()
                    Image(systemName: isSelected(role) ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected(role) ? .blue : .gray)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        
        // MARK: - Helper Methods
        
        private func isSelected(_ role: Role) -> Bool {
            guard let id = role.id else { return false }
            return selectedRoleIds.contains(id)
        }
        
        private func toggleSelection(_ role: Role) {
            guard let id = role.id else { return }
            
            if selectedRoleIds.contains(id) {
                selectedRoleIds.removeAll { $0 == id }
            } else {
                selectedRoleIds.append(id)
            }
        }
        
        private func loadRoles() async {
            isLoading = true
            errorMessage = ""
            
            taskManager.startTaskWithHandlers(
                id: "loadRoles",
                operation: {
                    try await roleService.fetchRoles(forCompany: companyId)
                },
                onSuccess: { fetchedRoles in
                    self.roles = fetchedRoles.sorted { $0.title < $1.title }
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
