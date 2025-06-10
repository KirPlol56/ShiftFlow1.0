//
//  ShiftsViewWithRepo.swift
//  ShiftFlow
//
//  Created by Kirill P on 13/03/2025.
//
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth

// MARK: - ShiftRow (Top Level)
struct ShiftRow: View {
    let shift: Shift
    let currentDate: Date // Date corresponding to the shift's dayOfWeek for display

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(shift.dayOfWeek.displayName)
                    .font(.headline)

                Spacer()

                Text(formatDate(currentDate)) // Display the specific date for this row
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            HStack(spacing: 4) { // Reduced spacing for time
                Image(systemName: "clock")
                    .foregroundColor(.blue)
                Text("\(formatTime(shift.startTime.dateValue())) - \(formatTime(shift.endTime.dateValue()))")
                    .font(.subheadline)
            }

            // Assigned Baristas Info
            HStack(spacing: 4) { // Reduced spacing
                Image(systemName: shift.assignedToUIDs.isEmpty ? "person.fill.questionmark" : "person.2.fill")
                    .foregroundColor(shift.assignedToUIDs.isEmpty ? .gray : .orange)
                Text(shift.assignedToUIDs.isEmpty ? "Unassigned" : "\(shift.assignedToUIDs.count) assigned")
                    .font(.subheadline)
                    .foregroundColor(shift.assignedToUIDs.isEmpty ? .gray : .primary)

            }


            HStack {
                // Task Info
                HStack(spacing: 4) { // Reduced spacing
                    Image(systemName: "list.bullet.rectangle.portrait")
                        .foregroundColor(.purple)
                    Text("\(shift.tasks.count) task\(shift.tasks.count == 1 ? "" : "s")")
                        .font(.subheadline)
                }

                Spacer()

                // Status Badge
                Text(shift.status.displayValue)
                    .font(.caption.weight(.medium)) // Make caption slightly bolder
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(shift.status.color.opacity(0.15)) // Use background opacity
                    .foregroundColor(shift.status.color) // Use foreground color
                    .clipShape(Capsule()) // Use capsule shape
            }
        }
        .padding(.vertical, 8) // Consistent vertical padding
    }

    // Date Formatting Helpers (Keep private to this view)
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d" // Shorter date format
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}


// MARK: - Main Shifts View
@MainActor
struct ShiftsViewWithRepo: View {
    // Environment
    @EnvironmentObject var shiftService: ShiftServiceWithRepo
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var roleService: RoleServiceWithRepo
    @EnvironmentObject var authService: FirebaseAuthenticationServiceWithRepo
    
    // Input
    let user: User
    
    // State
    @State private var selectedShift: Shift? = nil
    @StateObject var taskManager = TaskManager()
    
    var body: some View {
        NavigationView {
            PaginatedListView(
                items: shiftService.shifts,
                hasMorePages: shiftService.hasMorePages,
                isLoading: shiftService.isLoading || shiftService.isLoadingMore,
                loadMore: {
                    if user.isManager {
                        await loadMoreShifts(for: user.companyId ?? "")
                    } else {
                        await loadMoreUserShifts(for: user.uid, in: user.companyId ?? "")
                    }
                },
                refresh: {
                    // Full refresh (resets pagination)
                    await refreshData()
                }
            ) { shift in
                // Shift row
                ShiftRow(shift: shift, currentDate: shift.dayOfWeek.dateForCurrentWeek())
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedShift = shift
                    }
                    .if(user.isManager) { view in
                        view.swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button { selectedShift = shift } label: {
                                Label("View/Edit", systemImage: "pencil")
                            }.tint(.blue)
                        }
                    }
            } emptyContent: {
                VStack(spacing: 15) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.7))
                    Text("No Shifts Found")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text(user.isManager ?
                        "Weekly shifts will appear here once created." :
                        "Your assigned shifts for the week will appear here.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .navigationTitle("Weekly Schedule")
            .sheet(item: $selectedShift) { shift in
                NavigationView {
                    ShiftDetailViewRepo(shift: shift, isManager: user.isManager)
                        .environmentObject(shiftService)
                        .environmentObject(userState)
                        .environmentObject(roleService)
                        .environmentObject(authService)
                }
            }
            .task {
                // Initial data load
                await refreshData()
            }
            .onDisappear {
                taskManager.cancelAllTasks()
            }
        }
        .navigationViewStyle(.stack)
    }
    
    // MARK: - Data Loading Methods
    
    private func refreshData() async {
        guard let companyId = user.companyId else {
            print("Error: Company ID missing for user \(user.uid)")
            return
        }
        
        if user.isManager {
            await fetchShifts(for: companyId)
        } else {
            await fetchUserShifts(for: user.uid, in: companyId)
        }
    }
    
    private func fetchShifts(for companyId: String) async {
        taskManager.startTask(id: "fetchShifts") {
            await shiftService.fetchShifts(for: companyId)
        }
    }
    
    private func fetchUserShifts(for userId: String, in companyId: String) async {
        taskManager.startTask(id: "fetchUserShifts") {
            await shiftService.fetchUserShifts(for: userId, in: companyId)
        }
    }
    
    private func loadMoreShifts(for companyId: String) async {
        taskManager.startTask(id: "loadMoreShifts") {
            await shiftService.fetchNextShiftsPage(for: companyId)
        }
    }
    
    private func loadMoreUserShifts(for userId: String, in companyId: String) async {
        taskManager.startTask(id: "loadMoreUserShifts") {
            await shiftService.fetchNextUserShiftsPage(for: userId, in: companyId)
        }
    }
}

// MARK: - Conditional Modifier Helper
extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}


// MARK: - ShiftDetailViewRepo (Handles both Manager and Barista views)

@MainActor
struct ShiftDetailViewRepo: View {
    // Use @State because child sheets (EditTask, AssignUsers) might modify the shift data,
    // and we want this view to reflect those changes upon sheet dismissal.
    @State var shift: Shift
    let isManager: Bool // Determine UI based on role

    // Environment Objects
    @Environment(\.presentationMode) var presentationMode // To dismiss if needed
    @EnvironmentObject var shiftService: ShiftServiceWithRepo
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var roleService: RoleServiceWithRepo
    @EnvironmentObject var authService: FirebaseAuthenticationServiceWithRepo

    // Sheet Presentation State using Identifiable Enum
    enum ActiveSheet: Identifiable {
        case addTask, assignUsers
        case editShift // Added case for editing the entire shift
        case editTask(ShiftTask)
        case viewTask(ShiftTask) // Handles both regular detail and photo proof

        var id: String { // Conformance to Identifiable
            switch self {
            case .addTask: return "add_task"
            case .assignUsers: return "assign_users"
            case .editShift: return "edit_shift"
            case .editTask(let task): return "edit_\(task.id ?? UUID().uuidString)"
            case .viewTask(let task): return "view_\(task.id ?? UUID().uuidString)"
            }
        }
    }
    @State private var activeSheet: ActiveSheet? = nil

    // Loading and Error State
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false

    // Task Management
    @StateObject private var taskManager = TaskManager()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) { // Add spacing between sections
                // Shift Info Section
                ShiftInfoSection(shift: shift)
                    .padding(.horizontal)
                    // Allow managers to tap to edit the whole shift
                    .if(isManager) { view in
                         view.onTapGesture { activeSheet = .editShift }
                    }


                // Assigned Users Section (Always visible, button action depends on role)
                AssignedUsersSection(
                     assignedUserIds: shift.assignedToUIDs,
                     // Only managers can trigger the assignment sheet
                     onAssignTap: isManager ? { activeSheet = .assignUsers } : nil
                 )
                 .padding(.horizontal)


                // Tasks Section
                TaskSection(
                    shift: $shift, // Pass binding to allow updates from deletion
                    tasks: shift.tasks,
                    isManager: isManager,
                    onTaskSelect: { task in // Determine which sheet to show
                        if isManager {
                             activeSheet = .editTask(task) // Manager edits task
                        } else {
                             activeSheet = .viewTask(task) // Barista views task (detail/photo)
                        }
                    },
                    onDeleteTask: { task in // Handle deletion callback
                         deleteTask(task: task)
                    }
                )
                 // No horizontal padding needed here if TaskSection handles it

                // Task Completion Summary
                TaskCompletionSummary(tasks: shift.tasks)
                    .padding(.horizontal)

            }
            .padding(.vertical) // Add padding for scroll content
        }
        .navigationTitle("Shift Details") // Set title for the view
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
             // Use leading placement for Done/Close button in sheets
             ToolbarItem(placement: .navigationBarLeading) {
                  Button("Done") { presentationMode.wrappedValue.dismiss() }
              }
             // Primary action depends on role
             ToolbarItem(placement: .primaryAction) {
                  if isManager {
                      // Manager gets Add Task and Edit Shift buttons
                      HStack {
                           Button { activeSheet = .addTask } label: {
                               Label("Add Task", systemImage: "plus")
                           }
                           Button { activeSheet = .editShift } label: {
                               Label("Edit Shift", systemImage: "pencil")
                           }
                      }
                  }
              }
        }
        .sheet(item: $activeSheet, onDismiss: refreshShiftData) { item in // Use single sheet modifier
             SheetViewProvider(item: item, shift: $shift) // Use helper
                .environmentObject(shiftService)
                .environmentObject(userState)
                .environmentObject(roleService)
                .environmentObject(authService)
        }
        .task { // Load initial data
            refreshShiftData()
        }
         .alert("Error", isPresented: $showError) { // Error Alert
            Button("OK") { errorMessage = "" }
         } message: {
            Text(errorMessage)
         }
        .onDisappear {
            taskManager.cancelAllTasks()
        }
        .refreshable { // Allow pull-to-refresh within the detail view
            refreshShiftData()
        }
    }

    // MARK: - Helper Methods

     private func deleteTask(task: ShiftTask) {
         guard let taskId = task.id, let shiftId = shift.id else {
             setError("Cannot delete task: Missing ID.")
             return
         }
         isLoading = true
         taskManager.startTaskWithHandlers(
             id: "deleteTask_\(taskId)",
             operation: { try await shiftService.removeTask(from: shiftId, taskId: taskId) },
             onSuccess: { updatedShift in
                 self.shift = updatedShift // Update local state
                 self.isLoading = false
             },
             onError: { error in setError("Failed to delete task '\(task.title)': \(error.localizedDescription)") }
         )
     }

    private func refreshShiftData() {
         guard let shiftId = shift.id else { return }
         // Only show global loading indicator briefly if needed
         // isLoading = true
         taskManager.startTaskWithHandlers(
             id: "refreshShift_\(shiftId)",
             operation: { try await shiftService.shiftRepository.get(byId: shiftId) },
             onSuccess: { updatedShift in
                 self.shift = updatedShift // Update the local @State variable
                 // self.isLoading = false
                 print("Refreshed shift data for \(shiftId)")
             },
             onError: { error in setError("Error refreshing shift details: \(error.localizedDescription)") }
         )
     }

     private func setError(_ message: String) {
         print("Error: \(message)")
         self.errorMessage = message
         self.showError = true
         self.isLoading = false // Ensure loading stops
     }

    // MARK: - Sheet View Provider Helper
    struct SheetViewProvider: View {
        let item: ActiveSheet
        @Binding var shift: Shift // Pass binding to allow modification

        // Environment Objects needed by presented views
        @EnvironmentObject var shiftService: ShiftServiceWithRepo
        @EnvironmentObject var userState: UserState
        @EnvironmentObject var roleService: RoleServiceWithRepo
        @EnvironmentObject var authService: FirebaseAuthenticationServiceWithRepo

        @ViewBuilder
        var body: some View {
            switch item {
            case .addTask:
                NavigationView {
                     AddTaskViewRepo { newTask in
                          // Add task logic might live here or be passed via callback
                          // For now, just showing the view. Parent handles add on dismiss.
                     }
                     .environmentObject(userState)
                     .environmentObject(roleService)
                      .navigationTitle("Add New Task")
                      .navigationBarTitleDisplayMode(.inline)
                      // Add Cancel button inside the sheet's view
                 }

            case .assignUsers:
                 NavigationView {
                      AssignUsersViewRepo(
                          assignedIds: $shift.assignedToUIDs, // Bind to shift's user IDs
                          companyId: userState.currentUser?.companyId ?? ""
                      )
                      .environmentObject(authService)
                      .environmentObject(userState)
                      // AssignUsersViewRepo handles its own Done/Cancel
                 }

            case .editShift:
                 NavigationView { // Wrap EditShiftView in NavView for title/buttons
                      EditShiftViewWithTaskEditingRepo(shift: shift)
                         // Pass all necessary services
                         .environmentObject(shiftService)
                         .environmentObject(userState)
                         .environmentObject(roleService)
                         .environmentObject(authService)
                 }

            case .editTask(let task):
                // Edit task view usually doesn't need its own NavView
                 EditShiftTaskViewRepo(task: task, shiftId: shift.id ?? "")
                     .environmentObject(shiftService)
                     .environmentObject(userState)
                     .environmentObject(roleService)

            case .viewTask(let task):
                 // These views might manage their own NavView if they have internal navigation
                 if task.requiresPhotoProof && !(userState.currentUser?.isManager ?? false) {
                     PhotoProofTaskViewRepo(task: task, shiftId: shift.id ?? "")
                         .environmentObject(userState)
                         .environmentObject(shiftService)
                 } else {
                     TaskDetailViewRepo(task: task, shiftId: shift.id ?? "")
                         .environmentObject(userState)
                         .environmentObject(shiftService)
                 }
            }
        }
    }


    // MARK: - Sub-Views for ShiftDetailViewRepo (Keep definitions here)

    struct ShiftInfoSection: View {
        let shift: Shift
        // ... (Implementation as before) ...
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(shift.dayOfWeek.displayName)
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer()

                    VStack(alignment: .trailing) {
                        let date = shift.dayOfWeek.dateForCurrentWeek()
                        Text(formatDate(date))
                            .font(.subheadline)
                            .foregroundColor(.gray)

                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .foregroundColor(.blue)
                            Text("\(formatTime(shift.startTime.dateValue())) - \(formatTime(shift.endTime.dateValue()))")
                                .font(.headline)
                        }
                    }
                }
                HStack {
                    Text("Status:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text(shift.status.displayValue)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(shift.status.color.opacity(0.15))
                        .foregroundColor(shift.status.color)
                        .clipShape(Capsule())
                    Spacer()
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        private func formatDate(_ date: Date) -> String { /* ... */
             let formatter = DateFormatter(); formatter.dateFormat = "MMM d, yyyy"; return formatter.string(from: date) }
        private func formatTime(_ date: Date) -> String { /* ... */
            let formatter = DateFormatter(); formatter.timeStyle = .short; return formatter.string(from: date) }

    }

     struct AssignedUsersSection: View {
          let assignedUserIds: [String]
          let onAssignTap: (() -> Void)? // Make optional, only provide for managers
          @EnvironmentObject var authService: FirebaseAuthenticationServiceWithRepo
          @EnvironmentObject var userState: UserState
          @State private var userNames: [String: String] = [:]
          @State private var isLoadingNames = false

          // ... (Display logic as before) ...
          var displayNames: String { /* ... */
                if assignedUserIds.isEmpty { return "No one assigned" }
                let namesToShow = assignedUserIds.prefix(3).compactMap { userNames[$0] ?? $0 }.joined(separator: ", ")
                let remainingCount = assignedUserIds.count - 3
                return namesToShow + (remainingCount > 0 ? " +\(remainingCount) others" : "")
          }

          var body: some View {
              VStack(alignment: .leading, spacing: 8) { // Added spacing
                  Text("Assigned Baristas")
                      .font(.title3).fontWeight(.semibold)

                  HStack {
                      if isLoadingNames && !assignedUserIds.isEmpty { // Show loading only if needed
                           ProgressView()
                               .scaleEffect(0.8) // Smaller progress view
                      } else {
                           Image(systemName: assignedUserIds.isEmpty ? "person.fill.questionmark" : "person.2.fill")
                               .foregroundColor(assignedUserIds.isEmpty ? .gray : .orange)
                           Text(displayNames)
                               .font(.subheadline)
                               .foregroundColor(assignedUserIds.isEmpty ? .gray : .primary)
                               .lineLimit(1)
                      }
                      Spacer()
                       // Show button only if action is provided (i.e., for manager)
                       if let action = onAssignTap {
                           Button(assignedUserIds.isEmpty ? "Assign" : "Change", action: action)
                       }
                  }
                  .padding(.top, 4) // Add a little space below title
              }
               .padding()
               .background(Color(.secondarySystemGroupedBackground))
               .cornerRadius(12)
               .task { await loadUserNames() }
          }
          // ... (loadUserNames func as before) ...
            private func loadUserNames() async {
                guard !assignedUserIds.isEmpty else {
                     self.userNames = [:] // Clear cache if no users assigned
                     return
                }
                // Avoid reloading if names for *all* assigned users are already cached
                let usersToLoad = assignedUserIds.filter { userNames[$0] == nil }
                guard !usersToLoad.isEmpty else { return }

                guard let companyId = userState.currentUser?.companyId else { return }
                isLoadingNames = true
                do {
                    // Optimize: Fetch only the members needed if possible, or fetch all and filter
                    let members = try await authService.fetchTeamMembers(companyId: companyId)
                    var updatedNames = self.userNames // Start with existing cache
                    for member in members where assignedUserIds.contains(member.uid) { // Filter fetched members
                        updatedNames[member.uid] = member.name
                    }
                    self.userNames = updatedNames
                } catch {
                    print("Error loading user names for shift detail: \(error)")
                }
                isLoadingNames = false
            }

      }

    struct TaskSection: View {
        @Binding var shift: Shift
        let tasks: [ShiftTask]
        let isManager: Bool
        let onTaskSelect: (ShiftTask) -> Void
        let onDeleteTask: (ShiftTask) -> Void // Use callback

        @State private var taskToDelete: ShiftTask?
        @State private var showingDeleteConfirmation = false

        // ... (Body using ForEach and swipeActions as before) ...
         var body: some View {
             VStack(alignment: .leading, spacing: 0) {
                 HStack {
                      Text("Tasks")
                         .font(.title3).fontWeight(.semibold)
                      Spacer()
                      // Show completion count only if there are tasks
                      if !tasks.isEmpty {
                           Text("\(tasks.filter(\.isCompleted).count)/\(tasks.count) Done")
                              .font(.subheadline)
                              .foregroundColor(.gray)
                      }
                 }
                 .padding([.horizontal, .top])
                 .padding(.bottom, tasks.isEmpty ? 15 : 5)

                 if tasks.isEmpty {
                     VStack(spacing: 10) {
                         Image(systemName: "list.bullet.clipboard")
                             .font(.system(size: 40))
                             .foregroundColor(.gray.opacity(0.7))
                         Text("No tasks assigned to this shift.")
                             .font(.subheadline)
                             .foregroundColor(.gray)
                     }
                     .frame(maxWidth: .infinity, minHeight: 100)
                     .padding()
                     .background(Color(.secondarySystemGroupedBackground))
                     .cornerRadius(10)
                     .padding(.horizontal)
                 } else {
                      VStack(spacing: 0) {
                          ForEach(tasks) { task in
                             TaskRow(task: task) // Use the TaskRow subview
                                 .padding(.horizontal)
                                 .padding(.vertical, 10)
                                 .background(Color(.secondarySystemGroupedBackground)) // Row background
                                 .contentShape(Rectangle())
                                 .onTapGesture { onTaskSelect(task) }
                                 .if(isManager) { view in // Apply swipe only for managers
                                     view.swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                         Button(role: .destructive) {
                                             taskToDelete = task
                                             showingDeleteConfirmation = true
                                         } label: {
                                             Label("Delete", systemImage: "trash")
                                         }
                                          Button { onTaskSelect(task) } label: { // Edit action
                                              Label("Edit", systemImage: "pencil")
                                          }.tint(.blue)
                                     }
                                 }
                              // Add divider conditionally, not after the last item
                              if task.id != tasks.last?.id {
                                   Divider().padding(.leading)
                              }
                          }
                      }
                       .clipShape(RoundedRectangle(cornerRadius: 12)) // Clip the VStack for rounded corners
                       .padding(.horizontal) // Padding around the task list block
                 }
             }
             .alert("Confirm Delete Task", isPresented: $showingDeleteConfirmation, presenting: taskToDelete) { task in
                  Button("Delete", role: .destructive) {
                      onDeleteTask(task) // Use callback
                  }
                  Button("Cancel", role: .cancel) {}
              } message: { task in
                  Text("Are you sure you want to delete the task '\(task.title)'?")
              }
        }

    }

     struct TaskCompletionSummary: View {
          let tasks: [ShiftTask]
          // ... (Implementation as before) ...
            var completedCount: Int { tasks.filter(\.isCompleted).count }
            var totalCount: Int { tasks.count }
            var progress: Double { totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0 }

            var body: some View {
                VStack(alignment: .leading, spacing: 8) {
                     Text("Completion Progress")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                     ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: progress >= 1.0 ? .green : .blue))
                     // Hide count if no tasks exist
                     if totalCount > 0 {
                          Text("\(completedCount) of \(totalCount) tasks completed")
                             .font(.caption)
                             .foregroundColor(.gray)
                     }
                }
                 .padding()
                 .background(Color(.secondarySystemGroupedBackground))
                 .cornerRadius(12)
            }

      }
}
