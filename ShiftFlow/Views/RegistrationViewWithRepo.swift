//
//  RegistrationViewWithRepo.swift
//  ShiftFlow
//
//  Created by Kirill P on 09/03/2025.
//


import SwiftUI
import FirebaseAuth
import FirebaseFirestore

@MainActor
struct RegistrationViewWithRepo: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authService: FirebaseAuthenticationServiceWithRepo
    
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var companyName = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var showSuccess = false
    
    // Invitation Handling State
    @State private var invitationId: String? = nil
    @State private var inviteData: [String: Any]? = nil
    @State private var isProcessingInvite = false
    
    // Task management
    @State private var checkInvitationTask: Task<Void, Never>? = nil
    @State private var registrationTask: Task<Void, Never>? = nil

    var isInvited: Bool {
        inviteData != nil
    }

    // Computed properties for invited data (safer access)
    private var invitedCompanyName: String? { inviteData?["companyName"] as? String }
    private var invitedCompanyId: String? { inviteData?["companyId"] as? String }
    private var invitedRoleTitle: String? { inviteData?["roleTitle"] as? String }
    private var invitedRoleId: String? { inviteData?["roleId"] as? String }
    private var invitedIsManager: Bool? { inviteData?["isManager"] as? Bool }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text(isInvited ? "Join \(invitedCompanyName ?? "Company")" : "Create New Account")
                    .font(.largeTitle).fontWeight(.bold)

                if isInvited {
                    Text("Enter your details to accept the invitation.")
                        .foregroundColor(.gray)
                }

                // Form fields (Name, Email, Password, Confirm Password)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Full Name").fontWeight(.medium)
                    TextField("Enter your full name", text: $name)
                        .padding().background(Color(.systemGray6)).cornerRadius(8)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email").fontWeight(.medium)
                    TextField("Enter your email", text: $email)
                        .padding().background(Color(.systemGray6)).cornerRadius(8)
                        .keyboardType(.emailAddress).autocapitalization(.none)
                        .disabled(isInvited) // Lock email if invited
                        .onChange(of: email) { oldValue, newValue in
                            // Re-check for invites if email changes and not already processing one
                            if !isProcessingInvite && !isInvited && oldValue != newValue {
                                Task {
                                   await checkForInvitation(email: newValue)
                                }
                            }
                        }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password").fontWeight(.medium)
                    SecureField("Create a password (min 6 characters)", text: $password)
                        .padding().background(Color(.systemGray6)).cornerRadius(8)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Confirm Password").fontWeight(.medium)
                    SecureField("Confirm your password", text: $confirmPassword)
                        .padding().background(Color(.systemGray6)).cornerRadius(8)
                }

                // Company Name field ONLY if NOT invited
                if !isInvited {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Company Name").fontWeight(.medium)
                        TextField("Enter your company name", text: $companyName)
                            .padding().background(Color(.systemGray6)).cornerRadius(8)
                    }
                } else {
                    // Display role if invited
                    if let roleTitle = invitedRoleTitle {
                         HStack {
                             Text("Invited Role:")
                                 .foregroundColor(.gray)
                             Text(roleTitle)
                                 .fontWeight(.medium)
                             if invitedIsManager == true {
                                 Image(systemName: "checkmark.shield.fill")
                                     .foregroundColor(.orange)
                                     .help("Manager Permissions Included")
                             }
                         }.padding(.top, 5)
                     }
                }

                AsyncButton(
                    isInvited ? "Accept Invitation & Register" : "Create Account & Company"
                ) {
                    try await handleRegistration()
                } onError: { error in
                    errorMessage = error.localizedDescription
                    showError = true
                }
                .foregroundColor(.white)
                .padding()
                .background(isFormValid ? Color.blue : Color.gray)
                .cornerRadius(10)
                .frame(maxWidth: .infinity)
                .disabled(!isFormValid)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
            }
            .padding()
            .task {
                await checkForInvitation(email: email)
            }
        }
        .navigationTitle("Register")
        .alert("Registration Error", isPresented: $showError) {
            Button("OK") { errorMessage = "" }
        } message: {
            Text(errorMessage)
        }
        .alert("Registration Successful", isPresented: $showSuccess) {
            Button("OK") {
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("Your account has been created successfully. You can now log in.")
        }
        .onDisappear {
            // Cancel any ongoing tasks
            checkInvitationTask?.cancel()
            registrationTask?.cancel()
        }
    }
    
    // Form Validation
    private var isFormValid: Bool {
        let nameValid = !name.trimmingCharacters(in: .whitespaces).isEmpty
        let emailValid = !email.trimmingCharacters(in: .whitespaces).isEmpty && email.contains("@")
        let passwordValid = password.count >= 6 && password == confirmPassword
        let companyValid = isInvited || !companyName.trimmingCharacters(in: .whitespaces).isEmpty

        return nameValid && emailValid && passwordValid && companyValid
    }
    
    // Check for invitation using async/await
    private func checkForInvitation(email: String) async {
        let checkEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard !checkEmail.isEmpty else { return }

        // Cancel previous task if exists
        checkInvitationTask?.cancel()
        
        isProcessingInvite = true // Prevent multiple checks
        
        // Create a new task
        checkInvitationTask = Task {
            do {
                // Using structured concurrency with direct Firestore call
                // Note: This should ideally be moved to a service layer method
                let db = Firestore.firestore()
                let snapshot = try await db.collection("invitations")
                    .whereField("email", isEqualTo: checkEmail)
                    .whereField("status", isEqualTo: "pending")
                    .limit(to: 1)
                    .getDocuments()

                // Only update UI if task wasn't cancelled
                if !Task.isCancelled {
                    if let document = snapshot.documents.first {
                        print("Pending invitation found for \(checkEmail)")
                        self.invitationId = document.documentID
                        self.inviteData = document.data()
                        
                        // Update name if provided in invite and current name is empty
                        if name.isEmpty, let invitedName = inviteData?["name"] as? String {
                            self.name = invitedName
                        }
                    } else {
                        print("No pending invitation found for \(checkEmail)")
                        self.invitationId = nil
                        self.inviteData = nil
                    }
                }
            } catch {
                // Only update UI if task wasn't cancelled
                if !Task.isCancelled {
                    print("Error checking for invitation: \(error.localizedDescription)")
                    self.invitationId = nil
                    self.inviteData = nil
                }
            }
            
            // Only update state if task wasn't cancelled
            if !Task.isCancelled {
                isProcessingInvite = false
            }
        }
    }
    
    // Registration Handler using async/await
    private func handleRegistration() async throws {
        // Hide keyboard
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        // Cancel any previous task
        registrationTask?.cancel()
        
        // Create a new task
        // Replace lines 235-246 with:
        AsyncButton(
            isInvited ? "Accept Invitation & Register" : "Create Account & Company",
            action: {
                try await handleRegistration()
            },
            onError: { error in
                errorMessage = error.localizedDescription
                showError = true
            }
        )
        .foregroundColor(.white)
        .padding()
        .background(isFormValid ? Color.blue : Color.gray)
        .cornerRadius(10)
        .frame(maxWidth: .infinity)
        .disabled(!isFormValid)
        }
    // Accept invite and register using async/await
    private func acceptInviteAndRegister() async throws {
        guard let companyId = invitedCompanyId,
              let companyName = invitedCompanyName,
              let roleId = invitedRoleId,
              let roleTitle = invitedRoleTitle,
              let isMgr = invitedIsManager else {
            throw NSError(
                domain: "RegistrationError",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Invitation details are incomplete. Please contact your manager."]
            )
        }

        // Using modern async/await API directly
        try await authService.registerTeamMember(
            email: email.trimmingCharacters(in: .whitespaces).lowercased(),
            password: password,
            name: name.trimmingCharacters(in: .whitespaces),
            companyId: companyId,
            companyName: companyName,
            roleId: roleId,
            roleTitle: roleTitle,
            isManager: isMgr
        )
        
        print("Successfully registered invited user.")
        
        // Update invitation status
        if let invId = self.invitationId {
            try await Firestore.firestore().collection("invitations").document(invId).updateData(["status": "accepted"])
        }
    }
    
    // Register new company and manager using async/await
    private func registerNewCompanyAndManager() async throws {
        try await authService.registerUser(
            email: email.trimmingCharacters(in: .whitespaces).lowercased(),
            password: password,
            name: name.trimmingCharacters(in: .whitespaces),
            companyName: companyName.trimmingCharacters(in: .whitespaces)
        )
        
        print("Successfully registered new manager and company.")
    }
}
