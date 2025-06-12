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

                Text(formatDate(currentDate))
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .foregroundColor(.blue)
                Text("\(formatTime(shift.startTime.dateValue())) - \(formatTime(shift.endTime.dateValue()))")
                    .font(.subheadline)
            }

            HStack(spacing: 4) {
                Image(systemName: shift.assignedToUIDs.isEmpty ? "person.fill.questionmark" : "person.2.fill")
                    .foregroundColor(shift.assignedToUIDs.isEmpty ? .gray : .orange)
                Text(shift.assignedToUIDs.isEmpty ? "Unassigned" : "\(shift.assignedToUIDs.count) assigned")
                    .font(.subheadline)
                    .foregroundColor(shift.assignedToUIDs.isEmpty ? .gray : .primary)
            }

            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "list.bullet.rectangle.portrait")
                        .foregroundColor(.purple)
                    Text("\(shift.tasks.count) task\(shift.tasks.count == 1 ? "" : "s")")
                        .font(.subheadline)
                }

                Spacer()

                Text(shift.status.displayValue)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(shift.status.color.opacity(0.15))
                    .foregroundColor(shift.status.color)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 8)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
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
    @EnvironmentObject var shiftService: ShiftServiceWithRepo
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var roleService: RoleServiceWithRepo
    @EnvironmentObject var authService: FirebaseAuthenticationServiceWithRepo
    
    let user: User
    
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
                    await refreshData()
                }
            ) { shift in
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
            try await shiftService.fetchShifts(for: companyId)
        }
    }
    
    private func fetchUserShifts(for userId: String, in companyId: String) async {
        taskManager.startTask(id: "fetchUserShifts") {
            try await shiftService.fetchUserShifts(for: userId, in: companyId)
        }
    }
    
    private func loadMoreShifts(for companyId: String) async {
        taskManager.startTask(id: "loadMoreShifts") {
            do {
                try await shiftService.fetchNextShiftsPage(for: companyId)
            } catch {
                print("Error loading more shifts: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadMoreUserShifts(for userId: String, in companyId: String) async {
        taskManager.startTask(id: "loadMoreUserShifts") {
            do {
                try await shiftService.fetchNextUserShiftsPage(for: userId, in: companyId)
            } catch {
                print("Error loading more user shifts: \(error.localizedDescription)")
            }
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

// MARK: - ShiftDetailViewRepo & Subviews
@MainActor
struct ShiftDetailViewRepo: View {
    @State var shift: Shift
    let isManager: Bool

    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var shiftService: ShiftServiceWithRepo
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var roleService: RoleServiceWithRepo
    @EnvironmentObject var authService: FirebaseAuthenticationServiceWithRepo

    enum ActiveSheet: Identifiable {
        case addTask, assignUsers
        case editShift
        case editTask(ShiftTask)
        case viewTask(ShiftTask)

        var id: String {
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
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    @StateObject private var taskManager = TaskManager()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ShiftInfoSection(shift: shift)
                    .padding(.horizontal)
                    .if(isManager) { view in
                        view.onTapGesture { activeSheet = .editShift }
                    }

                AssignedUsersSection(
                    assignedUserIds: shift.assignedToUIDs,
                    onAssignTap: isManager ? { activeSheet = .assignUsers } : nil
                )
                .padding(.horizontal)

                TaskSection(
                    shift: $shift,
                    tasks: shift.tasks,
                    isManager: isManager,
                    onTaskSelect: { task in
                        if isManager {
                            activeSheet = .editTask(task)
                        } else {
                            activeSheet = .viewTask(task)
                        }
                    },
                    onDeleteTask: { task in
                        deleteTask(task: task)
                    }
                )

                TaskCompletionSummary(tasks: shift.tasks)
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Shift Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") { presentationMode.wrappedValue.dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                if isManager {
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
        .sheet(item: $activeSheet, onDismiss: refreshShiftData) { item in
            SheetViewProvider(item: item, shift: $shift)
                .environmentObject(shiftService)
                .environmentObject(userState)
                .environmentObject(roleService)
                .environmentObject(authService)
        }
        .task {
            refreshShiftData()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { errorMessage = "" }
        } message: {
            Text(errorMessage)
        }
        .onDisappear {
            taskManager.cancelAllTasks()
        }
        .refreshable {
            refreshShiftData()
        }
    }

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
                self.shift = updatedShift
                self.isLoading = false
            },
            onError: { error in setError("Failed to delete task '\(task.title)': \(error.localizedDescription)") }
        )
    }

    private func refreshShiftData() {
        guard let shiftId = shift.id else { return }
        taskManager.startTaskWithHandlers(
            id: "refreshShift_\(shiftId)",
            operation: { try await shiftService.shiftRepository.get(byId: shiftId) },
            onSuccess: { updatedShift in
                self.shift = updatedShift
                print("Refreshed shift data for \(shiftId)")
            },
            onError: { error in setError("Error refreshing shift details: \(error.localizedDescription)") }
        )
    }

    private func setError(_ message: String) {
        print("Error: \(message)")
        self.errorMessage = message
        self.showError = true
        self.isLoading = false
    }

    struct SheetViewProvider: View {
        let item: ActiveSheet
        @Binding var shift: Shift

        @EnvironmentObject var shiftService: ShiftServiceWithRepo
        @EnvironmentObject var userState: UserState
        @EnvironmentObject var roleService: RoleServiceWithRepo
        @EnvironmentObject var authService: FirebaseAuthenticationServiceWithRepo

        @ViewBuilder
        var body: some View {
            switch item {
            case .addTask:
                NavigationView {
                    AddTaskViewRepo { _ in }
                        .environmentObject(userState)
                        .environmentObject(roleService)
                        .navigationTitle("Add New Task")
                        .navigationBarTitleDisplayMode(.inline)
                }
            case .assignUsers:
                NavigationView {
                    AssignUsersViewRepo(
                        assignedIds: $shift.assignedToUIDs,
                        companyId: userState.currentUser?.companyId ?? ""
                    )
                    .environmentObject(authService)
                    .environmentObject(userState)
                }
            case .editShift:
                NavigationView {
                    EditShiftViewWithTaskEditingRepo(shift: shift)
                        .environmentObject(shiftService)
                        .environmentObject(userState)
                        .environmentObject(roleService)
                        .environmentObject(authService)
                }
            case .editTask(let task):
                EditShiftTaskViewRepo(task: task, shiftId: shift.id ?? "")
                    .environmentObject(shiftService)
                    .environmentObject(userState)
                    .environmentObject(roleService)
            case .viewTask(let task):
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

    struct ShiftInfoSection: View {
        let shift: Shift
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
        private func formatDate(_ date: Date) -> String {
            let formatter = DateFormatter(); formatter.dateFormat = "MMM d, yyyy"; return formatter.string(from: date)
        }
        private func formatTime(_ date: Date) -> String {
            let formatter = DateFormatter(); formatter.timeStyle = .short; return formatter.string(from: date)
        }
    }

    struct AssignedUsersSection: View {
        let assignedUserIds: [String]
        let onAssignTap: (() -> Void)?
        @EnvironmentObject var authService: FirebaseAuthenticationServiceWithRepo
        @EnvironmentObject var userState: UserState
        @State private var userNames: [String: String] = [:]
        @State private var isLoadingNames = false

        var displayNames: String {
            if assignedUserIds.isEmpty { return "No one assigned" }
            let namesToShow = assignedUserIds.prefix(3).compactMap { userNames[$0] ?? $0 }.joined(separator: ", ")
            let remainingCount = assignedUserIds.count - 3
            return namesToShow + (remainingCount > 0 ? " +\(remainingCount) others" : "")
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Assigned Baristas")
                    .font(.title3).fontWeight(.semibold)
                HStack {
                    if isLoadingNames && !assignedUserIds.isEmpty {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: assignedUserIds.isEmpty ? "person.fill.questionmark" : "person.2.fill")
                            .foregroundColor(assignedUserIds.isEmpty ? .gray : .orange)
                        Text(displayNames)
                            .font(.subheadline)
                            .foregroundColor(assignedUserIds.isEmpty ? .gray : .primary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if let action = onAssignTap {
                        Button(assignedUserIds.isEmpty ? "Assign" : "Change", action: action)
                    }
                }
                .padding(.top, 4)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .task { await loadUserNames() }
        }
        private func loadUserNames() async {
            guard !assignedUserIds.isEmpty else {
                self.userNames = [:]; return
            }
            let usersToLoad = assignedUserIds.filter { userNames[$0] == nil }
            guard !usersToLoad.isEmpty else { return }
            guard let companyId = userState.currentUser?.companyId else { return }
            isLoadingNames = true
            do {
                let members = try await authService.fetchTeamMembers(companyId: companyId)
                var updatedNames = self.userNames
                for member in members where assignedUserIds.contains(member.uid) {
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
        let onDeleteTask: (ShiftTask) -> Void
        @State private var taskToDelete: ShiftTask?
        @State private var showingDeleteConfirmation = false

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Tasks")
                        .font(.title3).fontWeight(.semibold)
                    Spacer()
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
                            TaskRow(task: task)
                                .padding(.horizontal)
                                .padding(.vertical, 10)
                                .background(Color(.secondarySystemGroupedBackground))
                                .contentShape(Rectangle())
                                .onTapGesture { onTaskSelect(task) }
                                .if(isManager) { view in
                                    view.swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            taskToDelete = task
                                            showingDeleteConfirmation = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        Button { onTaskSelect(task) } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }.tint(.blue)
                                    }
                                }
                            if task.id != tasks.last?.id {
                                Divider().padding(.leading)
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
            }
            .alert("Confirm Delete Task", isPresented: $showingDeleteConfirmation, presenting: taskToDelete) { task in
                Button("Delete", role: .destructive) {
                    onDeleteTask(task)
                }
                Button("Cancel", role: .cancel) {}
            } message: { task in
                Text("Are you sure you want to delete the task '\(task.title)'?")
            }
        }
    }

    struct TaskCompletionSummary: View {
        let tasks: [ShiftTask]
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
