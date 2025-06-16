//
//  CompletedTasksViewRepo.swift
//  ShiftFlow
//
//  Created by Kirill P on 25/03/2025.
//

import SwiftUI
import FirebaseFirestore

@MainActor
struct CompletedTasksViewRepo: View {
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var authService: FirebaseAuthenticationServiceWithRepo
    @EnvironmentObject var shiftService: ShiftServiceWithRepo

    @State private var completedTaskViewModels: [CompletedTaskViewModel] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var selectedTaskViewModel: CompletedTaskViewModel?
    @State private var showingTaskDetail = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    // Cache for user names to reduce Firestore reads
    @State private var userNameCache: [String: String] = [:]
    
    // Task management
    @State private var loadTask: Task<Void, Never>? = nil
    @State private var userNameTasks: [String: Task<Void, Never>] = [:]
    
    // Filtered and grouped tasks
    var filteredTasks: [CompletedTaskViewModel] {
        if searchText.isEmpty {
            return completedTaskViewModels
        } else {
            let lowercasedSearch = searchText.lowercased()
            return completedTaskViewModels.filter {
                $0.title.lowercased().contains(lowercasedSearch) ||
                $0.baristaName.lowercased().contains(lowercasedSearch)
            }
        }
    }
    
    var groupedTasks: [String: [CompletedTaskViewModel]] {
        Dictionary(grouping: filteredTasks, by: { $0.formattedDate })
    }
    
    var sortedDates: [String] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"
        return groupedTasks.keys.sorted { dateStr1, dateStr2 in
            guard let date1 = dateFormatter.date(from: dateStr1),
                  let date2 = dateFormatter.date(from: dateStr2) else { return false }
            return date1 > date2 // Sort descending (most recent first)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SearchBar(text: $searchText)
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))

            if isLoading {
                ProgressView("Loading completed tasks...")
                    .frame(maxHeight: .infinity)
            } else if completedTaskViewModels.isEmpty {
                ContentUnavailableView(
                    "No Completed Tasks",
                    systemImage: "checkmark.circle.trianglebadge.exclamationmark",
                    description: Text("Tasks completed by team members will appear here.")
                )
            } else if filteredTasks.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List {
                    ForEach(sortedDates, id: \.self) { dateString in
                        Section(header: Text(dateString).font(.headline)) {
                            ForEach(groupedTasks[dateString] ?? []) { taskVM in
                                Button {
                                    selectedTaskViewModel = taskVM
                                    showingTaskDetail = true
                                } label: {
                                    CompletedTaskRow(taskVM: taskVM)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .refreshable {
                    await loadCompletedTasks()
                }
            }
        }
        .task {
            await loadCompletedTasks()
        }
        .sheet(isPresented: $showingTaskDetail) {
            if let taskVM = selectedTaskViewModel {
                CompletedTaskDetailViewRepo(taskVM: taskVM)
            }
        }
        .alert("Error Loading Tasks", isPresented: $showError) {
            Button("OK") { errorMessage = "" }
        } message: {
            Text(errorMessage)
        }
        .onDisappear {
            // Cancel all tasks on disappear
            loadTask?.cancel()
            for (_, task) in userNameTasks {
                task.cancel()
            }
            userNameTasks.removeAll()
        }
    }
    
    // MARK: - Async Methods
    
    private func loadCompletedTasks() async {
        guard let companyId = userState.currentUser?.companyId,
              let currentUser = userState.currentUser else {
            errorMessage = "User information not found."
            showError = true
            isLoading = false
            return
        }
        
        // Cancel previous task if it exists
        loadTask?.cancel()
        
        // Show loading only if list is empty initially
        if completedTaskViewModels.isEmpty {
            isLoading = true
        }
        errorMessage = ""
        
        // Create a new task
        loadTask = Task {
            do {
                // Using modern async/await API
                let shifts = try await shiftService.fetchShiftsForWeek(companyId: companyId)
                
                // Check if task was cancelled
                if Task.isCancelled { return }
                
                // Continue processing
                await processShifts(shifts, currentUser: currentUser)
            } catch {
                // Only update UI if task wasn't cancelled
                if !Task.isCancelled {
                    errorMessage = "Error loading completed tasks: \(error.localizedDescription)"
                    showError = true
                    isLoading = false
                }
            }
        }
    }
    
    // Process shifts to extract completed tasks
    private func processShifts(_ shifts: [Shift], currentUser: User) async {
        var allCompletedTaskVMs: [CompletedTaskViewModel] = []
        
        // 2. Iterate through shifts and extract completed tasks
        var tasksToProcess: [(task: ShiftTask, shift: Shift)] = []
        for shift in shifts {
            // Find completed tasks within this shift
            let completedInShift = shift.tasks.filter { task in
                task.isCompleted && task.completedBy != nil && task.completedAt != nil
            }
            
            for task in completedInShift {
                tasksToProcess.append((task, shift))
            }
        }
        
        // 3. Process tasks with role-based filtering
        for item in tasksToProcess {
            let task = item.task
            let shift = item.shift
            
            guard let baristaId = task.completedBy,
                  let completionTimestamp = task.completedAt else { continue }
            
            // Only process tasks if:
            // - User is a manager OR
            // - User completed the task OR
            // - Task is assigned to user's role
            let isUserManager = currentUser.isManager
            let isUserTask = baristaId == currentUser.uid
            let isAssignedToUserRole = task.assignedRoleIds?.contains(currentUser.roleId) ?? false
            
            if isUserManager || isUserTask || isAssignedToUserRole {
                // Get user name asynchronously
                let baristaName = await fetchUserName(userId: baristaId)
                
                // Check if task was cancelled before creating the ViewModel
                if Task.isCancelled { return }
                
                // Create the ViewModel
                let viewModel = CompletedTaskViewModel(
                    id: task.id ?? UUID().uuidString,
                    title: task.title,
                    description: task.description,
                    priority: task.priority,
                    baristaName: baristaName,
                    baristaId: baristaId,
                    completionDate: completionTimestamp.dateValue(),
                    photoURL: task.photoURL,
                    shiftDay: shift.dayOfWeek.displayName
                )
                
                allCompletedTaskVMs.append(viewModel)
            }
        }
        
        // Only update UI if task wasn't cancelled
        if !Task.isCancelled {
            // Sort all collected VMs by date descending
            self.completedTaskViewModels = allCompletedTaskVMs.sorted { $0.completionDate > $1.completionDate }
            self.isLoading = false
            print("Loaded \(self.completedTaskViewModels.count) completed task view models.")
        }
    }
    
    // Helper to fetch user names with caching
    private func fetchUserName(userId: String) async -> String {
        // Check cache first
        if let cachedName = userNameCache[userId] {
            return cachedName
        }
        
        // Cancel any existing task for this user
        userNameTasks[userId]?.cancel()
        
        // Create a new task for this user with correct return type
        let task = Task<String, Never> {
            do {
                // Using modern async/await API
                let user = try await authService.fetchUser(byId: userId)
                
                // Only update cache if task wasn't cancelled
                if !Task.isCancelled {
                    // Cache the result
                    userNameCache[userId] = user.name
                    return user.name
                } else {
                    return "Unknown User"
                }
            } catch {
                print("Error fetching user name for \(userId): \(error)")
                return "Unknown User"
            }
        }
        
        // Convert the task type for storage and type safety
        let voidTask = Task<Void, Never> {
            _ = await task.value
        }
        
        // Store the void task
        userNameTasks[userId] = voidTask
        
        // Await the result from the original task
        return await task.value
    }
}

// MARK: - Helper Views

struct CompletedTaskRow: View {
    let taskVM: CompletedTaskViewModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(taskVM.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text("By: \(taskVM.baristaName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    Text(taskVM.shiftDay)
                    Text("•").foregroundColor(.gray)
                    Text(taskVM.formattedTime)
                }
                .font(.caption)
                .foregroundColor(.gray)
            }
            
            Spacer()
            
            if taskVM.photoURL != nil {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundColor(.blue)
                    .imageScale(.large)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Repository-based CompletedTaskDetailView
@MainActor
struct CompletedTaskDetailViewRepo: View {
    let taskVM: CompletedTaskViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var image: UIImage?
    @State private var isLoadingImage = false
    @State private var imageLoadError = false
    
    // Task management
    @State private var imageLoadTask: Task<Void, Never>? = nil
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Task details
                    VStack(alignment: .leading, spacing: 10) {
                        Text(taskVM.title)
                            .font(.title2).fontWeight(.bold)
                        if !taskVM.description.isEmpty {
                            Text(taskVM.description).foregroundColor(.secondary)
                        }
                        Divider().padding(.vertical, 4)
                        InfoRow(label: "Completed by", value: taskVM.baristaName)
                        InfoRow(label: "Date", value: taskVM.formattedDate)
                        InfoRow(label: "Time", value: taskVM.formattedTime)
                        InfoRow(label: "Shift", value: taskVM.shiftDay)
                        HStack {
                            Label("Priority", systemImage: "exclamationmark.triangle").font(.subheadline)
                            Spacer()
                            Text(taskVM.priority.displayValue)
                                .font(.subheadline).padding(.horizontal, 8).padding(.vertical, 2)
                                .background(taskVM.priority.color.opacity(0.2))
                                .foregroundColor(taskVM.priority.color)
                                .cornerRadius(4)
                        }
                    }
                    .padding().background(Color(.systemGray6)).cornerRadius(12)
                    
                    // Photo proof section
                    if let photoURL = taskVM.photoURL {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Photo Proof").font(.headline)
                            if isLoadingImage {
                                HStack { Spacer(); ProgressView("Loading image..."); Spacer() }.padding()
                            } else if let image = image {
                                Image(uiImage: image)
                                    .resizable().scaledToFit().cornerRadius(8)
                                    .frame(maxHeight: 250)
                            } else if imageLoadError {
                                Label("Could not load image", systemImage: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                            } else {
                                Text("Loading...")
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .center).padding()
                            }
                        }
                        .padding(.horizontal)
                        .task { await loadImage(from: photoURL) }
                    }
                }
                .padding()
            }
            .navigationTitle("Completed Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
        .onDisappear {
            // Cancel image loading task when view disappears
            imageLoadTask?.cancel()
        }
    }
    
    // Load image from URL using async/await
    private func loadImage(from urlString: String) async {
        // Cancel previous task if it exists
        imageLoadTask?.cancel()
        
        guard let url = URL(string: urlString) else {
            imageLoadError = true
            return
        }
        
        isLoadingImage = true
        imageLoadError = false
        
        // Create a new task
        imageLoadTask = Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                
                // Check if task was cancelled
                if Task.isCancelled { return }
                
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                
                if let loadedImage = UIImage(data: data) {
                    // Only update UI if task wasn't cancelled
                    if !Task.isCancelled {
                        self.image = loadedImage
                        self.isLoadingImage = false
                    }
                } else {
                    // Only update UI if task wasn't cancelled
                    if !Task.isCancelled {
                        self.imageLoadError = true
                        self.isLoadingImage = false
                    }
                }
            } catch {
                // Only update UI if task wasn't cancelled
                if !Task.isCancelled {
                    print("Error loading image (\(urlString)): \(error)")
                    self.imageLoadError = true
                    self.isLoadingImage = false
                }
            }
        }
    }
}
