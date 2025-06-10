//
//  TeamManagementViewRepo.swift
//  ShiftFlow
//
//  Created by Kirill P on 12/03/2025.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

@MainActor
struct TeamManagementViewRepo: View {
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var authService: FirebaseAuthenticationServiceWithRepo
    @EnvironmentObject var roleService: RoleServiceWithRepo
    @State private var showingBaristaManagementSheet = false
    @State private var teamMembers: [User] = []
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    // Task management
    @StateObject private var taskManager = TaskManager()
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content area
            if isLoading {
                ProgressView("Loading team members...")
                    .padding()
            } else if teamMembers.isEmpty {
                Spacer()
                // Empty state view
                VStack(spacing: 20) {
                    Image(systemName: "person.3")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.7))
                    
                    Text("No Team Members Yet")
                        .font(.title2)
                    
                    Text("Tap '+' to add members and assign roles.")
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                Spacer()
            } else {
                List {
                    ForEach(teamMembers, id: \.uid) { member in
                        TeamMemberRowView(member: member)
                    }
                }
                .refreshable {
                    // Modern refreshable with async/await
                    await loadTeamMembers()
                }
            }
            
            Spacer(minLength: 20)
            
            // Add Team Member Button - Always visible
            Button(action: {
                showingBaristaManagementSheet = true
            }) {
                HStack {
                    Image(systemName: "person.badge.plus")
                    Text("Add Team Member")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .navigationTitle("Manage Team")
        .task {
            // Initial load with task manager
            await loadTeamMembers()
        }
        .sheet(isPresented: $showingBaristaManagementSheet, onDismiss: {
            // Reload after sheet dismisses
            Task {
                await loadTeamMembers()
            }
        }) {
            NavigationView {
                BaristaManagementViewRepo()
                    .environmentObject(userState)
                    .environmentObject(authService)
                    .environmentObject(roleService)
            }
        }
        .alert(isPresented: $showError) {
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
        .onDisappear {
            // Cancel all tasks when view disappears
            taskManager.cancelAllTasks()
        }
    }
    
    // MARK: - Async Methods
    
    private func loadTeamMembers() async {
        guard let companyId = userState.currentUser?.companyId else {
            setError("Company ID not found")
            return
        }
        
        // Use task manager to handle task lifecycle
        taskManager.startTaskWithHandlers(
            id: "loadTeamMembers",
            operation: {
                // Show loading indicator for initial load
                if self.teamMembers.isEmpty {
                    self.isLoading = true
                }
                
                // Using modern async/await API directly
                return try await authService.fetchTeamMembers(companyId: companyId)
            },
            onSuccess: { members in
                // Process results
                self.isLoading = false
                self.teamMembers = members
                    .filter { $0.uid != self.userState.currentUser?.uid }
                    .sorted { $0.name.lowercased() < $1.name.lowercased() }
            },
            onError: { error in
                self.setError("Failed to load team: \(error.localizedDescription)")
            }
        )
    }
    
    // Helper to set error state
    private func setError(_ message: String) {
        print("Error: \(message)")
        self.errorMessage = message
        self.showError = true
        self.isLoading = false
    }
}

// Team member row view
struct TeamMemberRowView: View {
    let member: User
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(member.name)
                    .font(.headline)
                Text(member.email ?? "")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Updated to use isManager instead of role
            Text(member.roleTitle)
                .font(.caption)
                .padding(5)
                .background(member.isManager ? Color.blue : Color.green)
                .foregroundColor(.white)
                .cornerRadius(5)
        }
        .padding(.vertical, 5)
    }
}
