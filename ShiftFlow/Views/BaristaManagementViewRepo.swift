//
//  BaristaManagementViewRepo.swift
//  ShiftFlow
//
//  Created by Kirill P on 12/03/2025.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Helper for TeamMemberRow
struct TeamMemberRowViewRepo: View {
    let member: User

    var body: some View {
        HStack(spacing: 12) {
             // Simple circle with initials or placeholder
            Text(member.name.prefix(1))
                 .font(.headline)
                 .foregroundColor(.white)
                 .frame(width: 40, height: 40)
                 .background(Color.gray) // Use a color hash later if desired
                 .clipShape(Circle())

            VStack(alignment: .leading) {
                Text(member.name).font(.headline)
                // Display the specific role title
                Text(member.roleTitle)
                    .font(.subheadline)
                    .foregroundColor(.blue) // Color code roles?
                Text(member.email ?? "No Email")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            // Display Manager status clearly
            if member.isManager {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.orange)
                    .imageScale(.large)
                    .help("Manager Permissions") // Tooltip for macOS/iPadOS
            }
        }
        .padding(.vertical, 4) // Add some vertical padding
    }
}

struct BaristaManagementViewRepo: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var authService: FirebaseAuthenticationServiceWithRepo
    @EnvironmentObject var roleService: RoleServiceWithRepo

    @State private var teamMembers: [User] = []
    @State private var isLoading = false
    @State private var showingAddSheet = false
    @State private var errorMessage: String?
    @State private var showError = false

    @State private var companyRolesForSheet: [Role] = []
    @State private var isLoadingRolesForSheet = false

    // State for deletion confirmation
    @State private var showingDeleteConfirmation = false
    @State private var memberToDelete: User? = nil

    // Custom error type for RoleService if needed
    enum RoleServiceError: Error, LocalizedError {
        case companyIdMissing
        case roleNotFound
        case userIdMissing
        
        var errorDescription: String? {
            switch self {
            case .companyIdMissing:
                return "Company ID is missing."
            case .roleNotFound:
                return "Role not found."
            case .userIdMissing:
                return "User ID is missing."
            }
        }
    }

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading Team...")
                    .padding()
            } else if teamMembers.isEmpty {
                 // Improved empty state view
                 VStack(spacing: 15) {
                     Image(systemName: "person.3.sequence")
                         .font(.system(size: 60))
                         .foregroundColor(.gray.opacity(0.7))
                     Text("No Team Members Yet")
                         .font(.title2)
                         .foregroundColor(.secondary)
                     Text("Tap '+' to add members and assign roles.")
                         .font(.subheadline)
                         .foregroundColor(.gray)
                         .multilineTextAlignment(.center)
                         .padding(.horizontal)
                 }
                 .frame(maxHeight: .infinity)
                 .padding()
            } else {
                List {
                    ForEach(teamMembers) { member in
                        TeamMemberRowViewRepo(member: member)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    memberToDelete = member // Set the member to delete
                                    showingDeleteConfirmation = true // Trigger confirmation
                                } label: {
                                    Label("Delete", systemImage: "trash.fill")
                                }
                            }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                 .refreshable { // Add pull-to-refresh
                     loadTeamMembers()
                 }
            }
             Spacer() // Ensures content pushes up
        }
        .navigationTitle("Team Members")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    loadRolesAndShowSheet()
                } label: {
                    Label("Add Member", systemImage: "plus.circle.fill")
                }
                .disabled(isLoadingRolesForSheet)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationView {
                AddTeamMemberViewRepo(companyRoles: $companyRolesForSheet)
                    .environmentObject(userState)
                    .environmentObject(authService)
                    .environmentObject(roleService)
            }
        }
        .alert("Confirm Delete", isPresented: $showingDeleteConfirmation, presenting: memberToDelete) { member in
             // Confirmation Alert Actions
             Button("Delete \(member.name)", role: .destructive) {
                 deleteMemberConfirmed(member: member)
             }
             Button("Cancel", role: .cancel) {}
         } message: { member in
             Text("Are you sure you want to remove \(member.name) from the team? This only removes their access and data within ShiftFlow.")
         }
        .alert(isPresented: $showError) { // General error alert
            Alert(title: Text("Error"), message: Text(errorMessage ?? "An unknown error occurred."), dismissButton: .default(Text("OK")))
        }
        .onAppear {
            // Load initial team list if needed (listener might handle this)
            if teamMembers.isEmpty { // Only load if empty, listener handles updates
                loadTeamMembers()
            }
        }
    }

    // --- Data Loading ---

    private func loadTeamMembers() {
        guard let companyId = userState.currentUser?.companyId else {
            setError("Company ID not found.")
            return
        }
        // Show loading indicator only if list is currently empty
        if teamMembers.isEmpty { isLoading = true }

        // Use the repository-based service to fetch team members
        authService.fetchTeamMembers(companyId: companyId) { result in
            // This might be called multiple times by the listener
            isLoading = false // Ensure loading indicator hides
            switch result {
            case .success(let members):
                // Update the list, filtering self and sorting
                self.teamMembers = members
                    .filter { $0.uid != userState.currentUser?.uid }
                    .sorted { $0.name.lowercased() < $1.name.lowercased() }
            case .failure(let error):
                // Don't overwrite members array on listener error, just show message
                 setError(error.localizedDescription)
            }
        }
    }

    // Load roles for the Add sheet
    private func loadRolesAndShowSheet() {
        guard let companyId = userState.currentUser?.companyId else {
            setError(RoleServiceError.companyIdMissing.localizedDescription)
            return
        }
        isLoadingRolesForSheet = true
        errorMessage = nil

        roleService.fetchRoles(forCompany: companyId) { result in
            isLoadingRolesForSheet = false
            switch result {
            case .success(let roles):
                self.companyRolesForSheet = roles
                self.showingAddSheet = true
            case .failure(let error):
                print("⚠️ Error loading roles: \(error.localizedDescription). Proceeding with empty list for Add Sheet.")
                self.companyRolesForSheet = [] // Clear roles
                self.showingAddSheet = true    // Still show the sheet
            }
        }
    }

    // --- Actions ---

    // Called after user confirms deletion in the alert
    private func deleteMemberConfirmed(member: User) {
        print("Proceeding with deletion of \(member.name) (UID: \(member.uid))")
        isLoading = true // Show loading indicator during delete
        
        authService.deleteTeamMember(userId: member.uid) { result in
            isLoading = false
            switch result {
            case .success:
                print("Successfully deleted Firestore data for \(member.name).")
                // The listener in fetchTeamMembers should automatically update the list.
                // If not using a listener, manually remove here:
                // self.teamMembers.removeAll { $0.uid == member.uid }
            case .failure(let error):
                setError("Failed to delete \(member.name): \(error.localizedDescription)")
            }
        }
    }

    // --- Error Helper ---
    private func setError(_ message: String) {
        print("Error: \(message)")
        self.errorMessage = message
        self.showError = !message.isEmpty
    }
}

// MARK: - Add Team Member Sheet View

struct AddTeamMemberViewRepo: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var authService: FirebaseAuthenticationServiceWithRepo
    @EnvironmentObject var roleService: RoleServiceWithRepo

    @Binding var companyRoles: [Role] // Receive fetched roles

    // Form State
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    // Registration Type for UI Switching
    @State private var registrationType = RegistrationType.manual

    // Role State
    @State private var selectedRoleId: String? = nil
    @State private var customRoleTitle = ""
    @State private var isCustomRole = false
    @State private var isManager = false // Manager permissions toggle

    // Operation State
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showSuccess = false
    @State private var successMessage = ""

    // Enum to control UI
    enum RegistrationType: String, CaseIterable, Identifiable {
        case manual = "Create Account"
        case invite = "Send Invitation"
        var id: String { self.rawValue }
    }
    
    // Helper property to generate standard role options
    private var standardRoleOptions: [StandardRoles] {
        return StandardRoles.allCases
    }

    // Updated Form Validation
    private var isFormValid: Bool {
        let basicInfoValid = !name.trimmingCharacters(in: .whitespaces).isEmpty &&
                             !email.trimmingCharacters(in: .whitespaces).isEmpty &&
                             email.contains("@") // Basic email check
        // Password only required for manual creation
        let passwordValid = registrationType == .manual ? (password.count >= 6 && password == confirmPassword) : true
        let roleValid = (isCustomRole && !customRoleTitle.trimmingCharacters(in: .whitespaces).isEmpty) || (!isCustomRole && selectedRoleId != nil)

        return basicInfoValid && passwordValid && roleValid
    }


    var body: some View {
        NavigationView {
            Form {
                // Type Selector
                Section(header: Text("Action")) {
                    Picker("Action", selection: $registrationType) {
                        ForEach(RegistrationType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                Section(header: Text("Team Member Information")) {
                    TextField("Full Name", text: $name)
                        .autocapitalization(.words)

                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textContentType(.emailAddress) // Help autofill

                    // Show password fields only for Manual
                    if registrationType == .manual {
                        SecureField("Password (min 6 characters)", text: $password)
                            .textContentType(.newPassword) // Help password managers
                        SecureField("Confirm Password", text: $confirmPassword)
                            .textContentType(.newPassword)
                    }
                }

                // Role & Permissions Section
                Section(header: Text("Role & Permissions")) {
                    Toggle("Assign Manager Permissions", isOn: $isManager)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))

                    if !isCustomRole {
                        Picker("Select Role", selection: $selectedRoleId) {
                            Text("Choose a role...").tag(nil as String?)
                            
                            // First show company roles if available
                            if !companyRoles.isEmpty {
                                ForEach(companyRoles) { role in
                                    Text(role.title).tag(role.id as String?)
                                }
                            }
                            
                            // Then show standard roles
                            ForEach(standardRoleOptions, id: \.self) { standardRole in
                                Text(standardRole.rawValue).tag("std_\(standardRole.rawValue.lowercased().replacingOccurrences(of: " ", with: "_"))" as String?)
                            }
                            
                            Divider()
                            Text("Create Custom Role").tag("CREATE_CUSTOM" as String?)
                        }
                        .onChange(of: selectedRoleId) { _, newValue in
                            if newValue == "CREATE_CUSTOM" {
                                isCustomRole = true
                                selectedRoleId = nil
                            }
                        }
                    } else {
                        TextField("Custom Role Title", text: $customRoleTitle)
                            .autocapitalization(.words)
                        Button("Use Existing Role") {
                            isCustomRole = false
                            customRoleTitle = ""
                            selectedRoleId = nil
                        }
                        .foregroundColor(.blue)
                    }
                } // End Role Section

                // Informational text for Invitation
                if registrationType == .invite {
                    Section {
                        Text("An invitation document will be created in the system. You'll need a separate process (like email) to notify the user.")
                            .font(.caption).foregroundColor(.gray)
                    }
                }

                Section {
                    Button(action: handleAddMemberAction) { // Single action button
                        HStack {
                           Spacer()
                           if isLoading {
                               ProgressView()
                           } else {
                               // Dynamic button text
                               Text(registrationType == .manual ? "Create Account" : "Create Invitation")
                           }
                           Spacer()
                       }
                    }
                    .disabled(!isFormValid || isLoading)
                }
            }
            .navigationTitle("Add Team Member")
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            .alert(isPresented: $showError) {
                Alert(title: Text("Error"), message: Text(errorMessage ?? "An unknown error occurred."), dismissButton: .default(Text("OK")))
            }
             .alert(isPresented: $showSuccess) {
                 Alert(
                     title: Text("Success"),
                     message: Text(successMessage),
                     dismissButton: .default(Text("OK")) {
                         presentationMode.wrappedValue.dismiss()
                     }
                 )
             }
        }
    }

    // --- Action Handling ---

    private func handleAddMemberAction() {
        // Hide keyboard
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        if registrationType == .manual {
            registerTeamMember()
        } else if registrationType == .invite {
            sendInviteAction() // Call the new invite function
        }
    }

    // Gets or Creates the Role using RoleService (Updated to handle standard roles)
    private func getOrCreateRoleInfo(companyId: String, creatorUid: String, completion: @escaping (Result<(id: String, title: String), Error>) -> Void) {
        if isCustomRole {
            // Custom role creation - same as before
            let title = customRoleTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            roleService.addRole(title: title, companyId: companyId, createdBy: creatorUid) { result in
                switch result {
                case .success(let newRole):
                    guard let newRoleId = newRole.id else {
                        completion(.failure(NSError(domain: "AppError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Created role is missing ID."])))
                        return
                    }
                    completion(.success((id: newRoleId, title: newRole.title)))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } else if let roleId = selectedRoleId {
            // Check if this is a standard role ID (has "std_" prefix)
            if roleId.hasPrefix("std_") {
                // Extract the title from the standard role ID
                let roleTitle = String(roleId.dropFirst("std_".count))
                    .replacingOccurrences(of: "_", with: " ")
                    .split(separator: "_")
                    .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
                    .joined(separator: " ")
                
                // Create a proper Role in Firestore for this standard role
                roleService.addRole(title: roleTitle, companyId: companyId, createdBy: creatorUid) { result in
                    switch result {
                    case .success(let newRole):
                        guard let newRoleId = newRole.id else {
                            completion(.failure(NSError(domain: "AppError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Created role is missing ID."])))
                            return
                        }
                        completion(.success((id: newRoleId, title: newRole.title)))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            } else {
                // This is a custom role from the company - look it up in the list
                guard let role = companyRoles.first(where: { $0.id == roleId }) else {
                    completion(.failure(BaristaManagementViewRepo.RoleServiceError.roleNotFound))
                    return
                }
                guard let fetchedRoleId = role.id else {
                    completion(.failure(NSError(domain: "AppError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Selected role is missing its ID."])))
                    return
                }
                completion(.success((id: fetchedRoleId, title: role.title)))
            }
        } else {
            completion(.failure(BaristaManagementViewRepo.RoleServiceError.roleNotFound))
        }
    }

    // --- Registration Logic using repository-based service ---
    private func registerTeamMember() {
         guard let companyId = userState.currentUser?.companyId,
               let companyName = userState.currentUser?.companyName,
               let creatorUid = userState.currentUser?.uid else {
             setError(BaristaManagementViewRepo.RoleServiceError.companyIdMissing.localizedDescription)
             return
         }
         isLoading = true; errorMessage = nil

         getOrCreateRoleInfo(companyId: companyId, creatorUid: creatorUid) { roleResult in
             switch roleResult {
             case .failure(let error): setError(error.localizedDescription)
             case .success(let roleInfo):
                 authService.registerTeamMember(
                     email: email.trimmingCharacters(in: .whitespaces).lowercased(),
                     password: password,
                     name: name.trimmingCharacters(in: .whitespaces),
                     companyId: companyId,
                     companyName: companyName,
                     roleId: roleInfo.id,
                     roleTitle: roleInfo.title,
                     isManager: isManager
                  ) { result in
                     isLoading = false
                     switch result {
                     case .success:
                         self.successMessage = "'\(name)' created as a \(roleInfo.title)."
                         self.showSuccess = true
                     case .failure(let error): setError(error.localizedDescription)
                     }
                 }
             }
         }
     }

    // --- New Invitation Logic ---
    private func sendInviteAction() {
        guard let companyId = userState.currentUser?.companyId,
              let companyName = userState.currentUser?.companyName,
              let creatorUid = userState.currentUser?.uid else {
            setError(BaristaManagementViewRepo.RoleServiceError.companyIdMissing.localizedDescription)
            return
        }
        isLoading = true; errorMessage = nil

        // Step 1: Get or Create Role Info
        getOrCreateRoleInfo(companyId: companyId, creatorUid: creatorUid) { roleResult in
            switch roleResult {
            case .failure(let error):
                setError(error.localizedDescription) // Display error from role service

            case .success(let roleInfo):
                // Step 2: Role info obtained, create invitation document via repository-based AuthService
                authService.sendInvitation(
                    email: email.trimmingCharacters(in: .whitespaces).lowercased(),
                    name: name.trimmingCharacters(in: .whitespaces),
                    companyId: companyId,
                    companyName: companyName,
                    roleId: roleInfo.id,       // Use ID from result
                    roleTitle: roleInfo.title, // Use Title from result
                    isManager: isManager       // Use the state toggle
                ) { result in
                    isLoading = false // Stop loading indicator
                    switch result {
                    case .success:
                        print("Invitation document created successfully for \(email).")
                        self.successMessage = "Invitation created for \(email)."
                        self.showSuccess = true
                    case .failure(let error):
                        setError("Failed to create invitation: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    // --- Error Helper ---
    private func setError(_ message: String) {
        DispatchQueue.main.async {
            self.errorMessage = message
            self.showError = true
            self.isLoading = false // Ensure loading stops on error
        }
    }
}

