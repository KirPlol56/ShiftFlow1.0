//
//  CheckListsViewRepo.swift
//  ShiftFlow
//
//  Created by Kirill P on 14/03/2025.
//

import SwiftUI
import FirebaseFirestore

@MainActor
struct CheckListsViewRepo: View {
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var checkListService: CheckListServiceWithRepo
    @EnvironmentObject var roleService: RoleServiceWithRepo
    
    @State private var checkLists: [CheckList] = []
    @State private var isLoading = false
    @State private var showingAddSheet = false
    @State private var selectedCheckList: CheckList?
    @State private var showingEditSheet = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    // Add TaskManager for proper task lifecycle management
    @StateObject private var taskManager = TaskManager()
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView("Loading check lists...")
                    .padding()
            } else {
                if checkLists.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.7))
                        Text("No Check Lists Created")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("Use the '+' button below to add your first check list.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxHeight: .infinity)
                    .padding()
                } else {
                    List {
                        // Group by shift section
                        ForEach(CheckList.ShiftSection.allCases, id: \.self) { section in
                            let sectionCheckLists = checkListsForSection(section)
                            if !sectionCheckLists.isEmpty {
                                Section(header: Text(section.displayName).font(.headline)) {
                                    ForEach(sectionCheckLists) { checkList in
                                        HStack {
                                            // Checklist info content
                                            CheckListRow(checkList: checkList)
                                            
                                            // Add edit button for managers
                                            if userState.currentUser?.isManager == true {
                                                Button {
                                                    selectedCheckList = checkList
                                                    showingEditSheet = true
                                                } label: {
                                                    Image(systemName: "pencil")
                                                        .foregroundColor(.blue)
                                                }
                                                .buttonStyle(BorderlessButtonStyle())
                                            }
                                        }
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedCheckList = checkList
                                            if userState.currentUser?.isManager == true {
                                                showingEditSheet = true
                                            } else {
                                                // For non-managers, show view-only detail if needed
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                    .refreshable {
                        await loadCheckLists()
                    }
                }
                
                Spacer()
                
                // Only show Add button to managers
                if userState.currentUser?.isManager == true {
                    Button(action: { showingAddSheet = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add New Check List")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Check Lists")
        .task {
            await loadCheckLists()
        }
        .sheet(isPresented: $showingAddSheet, onDismiss: {
            Task {
                await loadCheckLists()
            }
        }) {
            AddCheckListViewRepo()
                .environmentObject(userState)
                .environmentObject(roleService)
                .environmentObject(checkListService)
        }
        .sheet(isPresented: $showingEditSheet, onDismiss: {
            Task {
                await loadCheckLists()
            }
        }) {
            if let checkList = selectedCheckList {
                EditCheckListViewRepo(checkList: checkList)
                    .environmentObject(userState)
                    .environmentObject(roleService)
                    .environmentObject(checkListService)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { errorMessage = "" }
        } message: {
            Text(errorMessage)
        }
        .onDisappear {
            // Cancel all tasks when view disappears to prevent memory leaks
            taskManager.cancelAllTasks()
        }
    }
    
    private func checkListsForSection(_ section: CheckList.ShiftSection) -> [CheckList] {
        return checkLists
            .filter { $0.shiftSection == section }
            .sorted { $0.title.lowercased() < $1.title.lowercased() }
    }
    
    private func loadCheckLists() async {
        guard let companyId = userState.currentUser?.companyId else {
            setError("Company ID not found")
            return
        }
        
        // Use TaskManager to handle task lifecycle
        taskManager.startTaskWithHandlers(
            id: "loadCheckLists",
            operation: {
                // Show loading indicator only if list is empty initially
                if self.checkLists.isEmpty {
                    await MainActor.run {
                        self.isLoading = true
                    }
                }
                
                await MainActor.run {
                    self.errorMessage = ""
                }
                
                // Using async/await API directly
                return try await checkListService.fetchCheckLists(for: companyId)
            },
            onSuccess: { lists in
                self.isLoading = false
                self.checkLists = lists
                print("Loaded \(lists.count) check lists.")
            },
            onError: { error in
                self.setError("Failed to load check lists: \(error.localizedDescription)")
            }
        )
    }
    
    private func setError(_ message: String) {
        print("Error: \(message)")
        self.errorMessage = message
        self.showError = true
        self.isLoading = false
    }
}

// CheckListRow helper view stays the same
struct CheckListRow: View {
    let checkList: CheckList
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(checkList.title)
                .font(.headline)
            
            HStack(spacing: 15) {
                Label(checkList.frequency.displayName, systemImage: "arrow.clockwise")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Label("\(checkList.tasks.count) tasks", systemImage: "list.bullet.rectangle")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                if let assignedIds = checkList.assignedRoleIds, !assignedIds.isEmpty {
                    Label("\(assignedIds.count) roles", systemImage: "person.2")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 6)
    }
}
