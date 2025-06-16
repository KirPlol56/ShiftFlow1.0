//
//  AssignUsersViewRepo.swift
//  ShiftFlow
//
//  Created by Kirill P on [Date] // Update Date
//  Adapted from AssignRolesViewRepo
//

import SwiftUI
import FirebaseFirestore

@MainActor
struct AssignUsersViewRepo: View {
    @Binding var assignedIds: [String] // Renamed to be generic (holds User UIDs)
    let companyId: String

    @EnvironmentObject var authService: FirebaseAuthenticationServiceWithRepo // Use AuthService to get users
    @EnvironmentObject var userState: UserState // To exclude current user if needed
    @Environment(\.presentationMode) var presentationMode

    @State private var teamMembers: [User] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = "" // For filtering

    // Task Management
    @StateObject private var taskManager = TaskManager()

    // Filtered members based on search
    var filteredMembers: [User] {
        let membersToDisplay = teamMembers.filter { $0.uid != userState.currentUser?.uid } // Exclude self
        if searchText.isEmpty {
            return membersToDisplay
        } else {
            return membersToDisplay.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                ($0.email ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) { // Use VStack for search bar placement
            // Search Bar (Optional but recommended)
            SearchBar(text: $searchText) // Use the SearchBar from CompletedTasksViewRepo
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color(.systemGroupedBackground)) // Match form background


            // Main Content Area
            Group {
                if isLoading {
                    ProgressView("Loading Team Members...")
                        .frame(maxHeight: .infinity)
                } else if let errorMessage = errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxHeight: .infinity)
                } else if teamMembers.isEmpty { // Check original list before filtering
                    Text("No team members found for this company.")
                        .foregroundColor(.gray)
                        .padding()
                        .frame(maxHeight: .infinity)
                } else if filteredMembers.isEmpty && !searchText.isEmpty {
                     ContentUnavailableView.search(text: searchText)
                         .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredMembers) { user in
                            UserSelectionRow(
                                user: user,
                                isSelected: assignedIds.contains(user.uid),
                                onToggle: { isSelected in
                                    toggleSelection(user: user, isSelected: isSelected)
                                }
                            )
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
        }
        .navigationTitle("Assign Baristas")
         .navigationBarTitleDisplayMode(.inline)
         .toolbar {
             ToolbarItem(placement: .navigationBarLeading) {
                 Button("Cancel") { presentationMode.wrappedValue.dismiss() }
             }
             ToolbarItem(placement: .navigationBarTrailing) {
                 Button("Done") { presentationMode.wrappedValue.dismiss() }
             }
         }
        .task { // Use .task for initial load
            await loadTeamMembers()
        }
        .onDisappear {
             taskManager.cancelAllTasks()
        }
         // Remove searchable modifier if using custom SearchBar
         // .searchable(text: $searchText, prompt: "Search by name or email")
    }

    private func toggleSelection(user: User, isSelected: Bool) {
        let userId = user.uid
        if isSelected {
            if !assignedIds.contains(userId) {
                assignedIds.append(userId)
            }
        } else {
            assignedIds.removeAll { $0 == userId }
        }
        print("Assigned IDs: \(assignedIds)") // Debugging
    }

    private func loadTeamMembers() async {
        guard !companyId.isEmpty else {
            errorMessage = "Company ID is required."
            isLoading = false
            return
        }

        taskManager.startTaskWithHandlers(
            id: "loadTeamMembersForAssignment",
            operation: {
                 self.isLoading = true // Show loading indicator
                 self.errorMessage = nil
                 // Fetch users using AuthService
                 return try await authService.fetchTeamMembers(companyId: companyId)
            },
            onSuccess: { members in
                 self.isLoading = false
                 // Sort members alphabetically by name
                 self.teamMembers = members.sorted { $0.name.lowercased() < $1.name.lowercased() }
            },
            onError: { error in
                 self.isLoading = false
                 self.errorMessage = "Failed to load team: \(error.localizedDescription)"
            }
        )
    }
}

// MARK: - User Selection Row Helper
struct UserSelectionRow: View {
    let user: User
    let isSelected: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        Button(action: { onToggle(!isSelected) }) { // Toggle selection on tap
            HStack(spacing: 12) {
                // Basic avatar placeholder
                 Text(user.name.prefix(1))
                     .font(.headline)
                     .foregroundColor(.white)
                     .frame(width: 30, height: 30)
                     .background(Color.gray) // Use a color hash later if desired
                     .clipShape(Circle())

                VStack(alignment: .leading) {
                    Text(user.name)
                         .font(.headline)
                    Text(user.email ?? "No email")
                        .font(.caption)
                        .foregroundColor(.gray)
                     // Optionally display role title
                     Text(user.roleTitle)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title2) // Make checkmark slightly larger
            }
            .padding(.vertical, 4) // Add padding
        }
        .foregroundColor(.primary) // Ensure text color is standard
    }
}
