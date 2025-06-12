//
//  BaristaCheckListViewWithRepo.swift
//  ShiftFlow
//
//  Created by Kirill P on 14/03/2025.
//

import SwiftUI
import FirebaseFirestore

@MainActor
struct BaristaCheckListViewWithRepo: View {
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var shiftService: ShiftServiceWithRepo
    @EnvironmentObject var checkListService: CheckListServiceWithRepo
    @EnvironmentObject var roleService: RoleServiceWithRepo

    @State private var checkLists: [CheckList] = []
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var selectedCheckList: CheckList?
    @State private var showingDetailView = false

    // Cache role names if needed for display
    @State private var roleNameCache: [String: String] = [:]
    
    // Task management
    @StateObject private var taskManager = TaskManager()

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading check lists...")
                    .frame(maxHeight: .infinity)
            } else if checkLists.isEmpty {
                ContentUnavailableView(
                     "No Check Lists Assigned",
                     systemImage: "checklist.unchecked",
                     description: Text("No check lists are currently assigned to your role for today.")
                 )
            } else {
                List {
                    ForEach(CheckList.ShiftSection.allCases, id: \.self) { section in
                        let sectionCheckLists = checkListsForSection(section)
                        let isSectionCurrent = isCurrentSection(section)

                        if !sectionCheckLists.isEmpty {
                            Section { // Removed header text, using row styling instead
                                ForEach(sectionCheckLists) { checkList in
                                    Button {
                                        selectedCheckList = checkList
                                        showingDetailView = true
                                    } label: {
                                         CheckListRowBarista(
                                             checkList: checkList,
                                             isActiveToday: checkList.frequency.isActiveToday(),
                                             isCurrentSection: isSectionCurrent,
                                             roleNameCache: $roleNameCache
                                         )
                                    }
                                    .buttonStyle(.plain) // Use plain style for tappable row
                                    // Apply subtle background highlight for current section/today
                                    .listRowBackground(
                                         (isSectionCurrent && checkList.frequency.isActiveToday())
                                             ? Color.blue.opacity(0.1)
                                             : Color.clear
                                     )
                                }
                            } header: { // Use header for section title
                                HStack {
                                     Text(section.displayName).font(.headline)
                                     if isSectionCurrent {
                                         Image(systemName: "smallcircle.filled.circle.fill")
                                             .foregroundColor(.blue)
                                             .font(.caption)
                                             .help("Current Section")
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
        }
        .task {
            // Load data with task manager
            await loadCheckLists()
            await loadRoleNames()
        }
        .sheet(isPresented: $showingDetailView) {
            if let checkList = selectedCheckList {
                BaristaCheckListDetailView(checkList: checkList)
                    .environmentObject(userState)
                    .environmentObject(checkListService)
                    .environmentObject(roleService)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { errorMessage = "" }
        } message: {
            Text(errorMessage)
        }
        .onDisappear {
            // Cancel all tasks when view disappears
            taskManager.cancelAllTasks()
        }
    }

    // Helper to group checklists by section
    private func checkListsForSection(_ section: CheckList.ShiftSection) -> [CheckList] {
        return checkLists
            .filter { $0.shiftSection == section }
            .sorted { $0.title < $1.title } // Sort alphabetically within section
    }

    // Helper to determine if a section is the current one based on shift times
    private func isCurrentSection(_ section: CheckList.ShiftSection) -> Bool {
        guard let currentShift = getCurrentShift() else { return false }

        let currentShiftStartTimeDate = currentShift.startTime.dateValue()
        let currentShiftEndTimeDate = currentShift.endTime.dateValue()
        let now = Date()
        let calendar = Calendar.current

        switch section {
        case .opening:
            let openingEnd = calendar.date(byAdding: .minute, value: 30, to: currentShiftStartTimeDate) ?? currentShiftStartTimeDate
            return now >= currentShiftStartTimeDate && now <= openingEnd
        case .closing:
            let closingStart = calendar.date(byAdding: .minute, value: -30, to: currentShiftEndTimeDate) ?? currentShiftEndTimeDate
            return now >= closingStart && now <= currentShiftEndTimeDate
        case .during:
            let openingEnd = calendar.date(byAdding: .minute, value: 30, to: currentShiftStartTimeDate) ?? currentShiftStartTimeDate
            let closingStart = calendar.date(byAdding: .minute, value: -30, to: currentShiftEndTimeDate) ?? currentShiftEndTimeDate
            if openingEnd < closingStart { return now > openingEnd && now < closingStart }
            else { return now >= currentShiftStartTimeDate && now <= currentShiftEndTimeDate }
        }
    }

    // Helper to get the user's currently active shift
    private func getCurrentShift() -> Shift? {
        guard let userId = userState.currentUser?.uid else { return nil }
        let now = Date()
        
        // Access shifts fetched by the service
        return shiftService.shifts.first { shift in
            shift.assignedToUIDs.contains(userId) &&
            now >= shift.startTime.dateValue() && // Compare Dates
            now <= shift.endTime.dateValue()      // Compare Dates
        }
    }

    // MARK: - Async Methods

    private func loadCheckLists() async {
        guard let user = userState.currentUser,
              // Fix: Replace unused 'companyId' with '_'
              let _ = user.companyId else {
            setError("User or Company ID not found")
            return
        }

        // Use task manager to handle task lifecycle
        taskManager.startTaskWithHandlers(
            id: "loadCheckLists",
            operation: {
                // Show loading indicator for initial load, not refreshes
                if self.checkLists.isEmpty {
                    self.isLoading = true
                }
                
                // Using modern async/await API directly
                return try await checkListService.fetchCheckListsForCurrentUser(user: user)
            },
            onSuccess: { lists in
                self.checkLists = lists
                self.isLoading = false
                print("Loaded \(lists.count) checklists for user role \(user.roleId)")
            },
            onError: { error in
                self.setError("Failed to load check lists: \(error.localizedDescription)")
            }
        )
    }

    // Async version of role name loading
    private func loadRoleNames() async {
        guard let companyId = userState.currentUser?.companyId,
              roleNameCache.isEmpty else { return }
        
        print("Fetching role names for cache...")
        
        // Use task manager to handle task lifecycle
        taskManager.startTaskWithHandlers(
            id: "loadRoleNames",
            operation: {
                // Using modern async/await API directly
                return try await roleService.fetchRoles(forCompany: companyId)
            },
            onSuccess: { roles in
                var newCache: [String: String] = [:]
                for role in roles {
                    if let id = role.id {
                        newCache[id] = role.title
                    }
                }
                
                self.roleNameCache = newCache
                print("Role name cache updated with \(newCache.count) entries")
            },
            onError: { error in
                // Only log error, don't show alert since this is background loading
                print("Error fetching role names: \(error.localizedDescription)")
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

// MARK: - Task Check Row Helper
struct TaskCheckRow: View {
    let task: CheckListTask
    let isCompleted: Bool
    
    var body: some View {
        HStack(spacing: 12) { // Add spacing
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isCompleted ? .green : .gray)
                .font(.title2) // Slightly larger toggle
            
            VStack(alignment: .leading, spacing: 2) { // Adjust spacing
                Text(task.title)
                    .font(.body) // Use body font
                    .foregroundColor(.primary)
                    .strikethrough(isCompleted, color: .gray) // Apply strikethrough
                
                if !task.description.isEmpty {
                    Text(task.description)
                        .font(.caption) // Use caption for description
                        .foregroundColor(.gray)
                        .lineLimit(2) // Limit description lines shown in list
                }
            }
            .padding(.vertical, 4) // Add slight vertical padding
        }
    }
}
