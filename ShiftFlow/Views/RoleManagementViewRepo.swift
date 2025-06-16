//
//  RoleManagementViewRepo.swift
//  ShiftFlow
//
//  Created by Kirill P on 02/04/2025.
//

import SwiftUI
import FirebaseFirestore

@MainActor
struct RoleManagementViewRepo: View {
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var roleService: RoleServiceWithRepo

    @State private var companyRoles: [Role] = []
    @State private var isLoading = false
    @State private var showingAddRoleSheet = false
    @State private var errorMessage = ""
    @State private var showError = false

    // Task management
    @State private var loadTask: Task<Void, Never>? = nil

    var body: some View {
        List {
            if isLoading {
                ProgressView("Loading roles...")
            } else if companyRoles.isEmpty {
                Text("No roles found")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(companyRoles) { role in
                    RoleRowRepo(role: role)
                }
            }
        }
        .navigationTitle("Role Management")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddRoleSheet = true }) {
                    Label("Add Role", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddRoleSheet, onDismiss: {
            // Reload after adding new role
            Task {
                await loadCompanyRoles()
            }
        }) {
            AddRoleViewRepo(companyId: userState.currentUser?.companyId ?? "")
                .environmentObject(roleService)
                .environmentObject(userState)
        }
        .task {
            // Initial loading using task modifier
            await loadCompanyRoles()
        }
        .alert(isPresented: $showError) {
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
        .onDisappear {
            // Cancel task when view disappears
            loadTask?.cancel()
        }
    }

    // MARK: - Async Methods

    private func loadCompanyRoles() async {
        guard let companyId = userState.currentUser?.companyId else {
            errorMessage = "Company ID not found"
            showError = true
            isLoading = false
            return
        }

        // Cancel previous task if it exists
        loadTask?.cancel()

        // Update UI state
        isLoading = true
        errorMessage = ""

        // Create a new task
        loadTask = Task {
            do {
                // Using modern async/await API directly
                let roles = try await roleService.fetchRoles(forCompany: companyId)
                // Only update UI if task wasn't cancelled
                if !Task.isCancelled {
                    isLoading = false
                    self.companyRoles = roles.sorted { $0.title < $1.title }
                }
            } catch {
                // Only update UI if task wasn't cancelled
                if !Task.isCancelled {
                    isLoading = false
                    errorMessage = "Failed to load roles: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

struct RoleRowRepo: View {
    let role: Role

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(role.title)
                    .font(.headline)
                HStack {
                    if role.isStandardRole {
                        Text("Standard")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    } else {
                        Text("Custom")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// Updated AddRoleViewRepo with Swift concurrency
@MainActor
struct AddRoleViewRepo: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var roleService: RoleServiceWithRepo

    let companyId: String

    // State variables
    @State private var roleTitle = ""
    @State private var selectedStandardRole: StandardRoles?
    @State private var isCustomRole = false
    @State private var isLoading = false
    @State private var alertType: AlertType = .none
    @State private var showingAlert = false

    // Task management
    @State private var addRoleTask: Task<Void, Error>? = nil

    // Alert type enum
    enum AlertType {
        case none
        case error(String)
        case success
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Role Type")) {
                    Picker("Role Type", selection: $isCustomRole) {
                        Text("Standard Role").tag(false)
                        Text("Custom Role").tag(true)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                if !isCustomRole {
                    Section(header: Text("Standard Role")) {
                        Picker("Role", selection: $selectedStandardRole) {
                            Text("Select a role").tag(Optional<StandardRoles>.none)
                            ForEach(StandardRoles.allCases, id: \.self) { role in
                                Text(role.rawValue).tag(Optional(role))
                            }
                        }
                    }
                } else {
                    Section(header: Text("Custom Role")) {
                        TextField("Role Title", text: $roleTitle)
                            .autocapitalization(.words)
                    }
                }

                Section {
                    AsyncButton("Add Role Definition") {
                        await addRoleAsync()
                    } onError: { error in
                        alertType = .error(error.localizedDescription)
                        showingAlert = true
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(!isFormValid)
                }
            }
            .navigationTitle("Add Role Definition")
            .navigationBarItems(trailing: Button("Cancel") {
                // Cancel ongoing task
                addRoleTask?.cancel()
                presentationMode.wrappedValue.dismiss()
            })
            .alert(isPresented: $showingAlert) {
                switch alertType {
                case .error(let message):
                    return Alert(
                        title: Text("Error Adding Role"),
                        message: Text(message),
                        dismissButton: .default(Text("OK"))
                    )
                case .success:
                    return Alert(
                        title: Text("Success"),
                        message: Text("Role added successfully"),
                        dismissButton: .default(Text("OK")) {
                            presentationMode.wrappedValue.dismiss()
                        }
                    )
                case .none:
                    return Alert(title: Text(""))
                }
            }
            .onDisappear {
                // Cancel task when view disappears
                addRoleTask?.cancel()
            }
        }
    }

    private var isFormValid: Bool {
        if isCustomRole {
            return !roleTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            return selectedStandardRole != nil
        }
    }

    // MARK: - Async Methods

    private func addRoleAsync() async {
        guard let creatorUid = userState.currentUser?.uid else {
            alertType = .error("User ID is missing.")
            showingAlert = true
            return
        }

        let titleToAdd = isCustomRole ? roleTitle.trimmingCharacters(in: .whitespacesAndNewlines) : selectedStandardRole?.rawValue ?? ""

        // Cancel previous task if it exists
        addRoleTask?.cancel()
        isLoading = true

        // Create a new task
        addRoleTask = Task {
            do {
                // Using modern async/await API directly
                let _ = try await roleService.addRole(title: titleToAdd, companyId: companyId, createdBy: creatorUid)
                // Only update UI if task wasn't cancelled
                if !Task.isCancelled {
                    isLoading = false
                    print("Role '\(titleToAdd)' added successfully via roleService.")
                    alertType = .success
                    showingAlert = true
                }
            } catch {
                // Only update UI if task wasn't cancelled
                if !Task.isCancelled {
                    isLoading = false
                    alertType = .error(error.localizedDescription)
                    showingAlert = true
                }
            }
        }
        // Let errors propagate to AsyncButton's error handler
        try? await addRoleTask?.value
    }
}
