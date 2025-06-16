//
//  TaskDetailViewRepo.swift
//  ShiftFlow
//
//  Created by Kirill P on 25/03/2025.
//

import SwiftUI
import FirebaseCore
import FirebaseStorage
import FirebaseFirestore

@MainActor
struct TaskDetailViewRepo: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var shiftService: ShiftServiceWithRepo
    @EnvironmentObject var userState: UserState

    let task: ShiftTask
    let shiftId: String

    // Task state
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var isUpdating = false
    
    // Task management
    @State private var completeTask: Task<Void, Never>? = nil
    @State private var markIncompleteTask: Task<Void, Never>? = nil

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Task Information Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text(task.title)
                            .font(.title2).fontWeight(.bold)
                        if !task.description.isEmpty {
                            Text(task.description).foregroundColor(.secondary)
                        }
                        HStack {
                             Label("Priority", systemImage: "exclamationmark.triangle")
                             Spacer()
                             Text(task.priority.displayValue)
                                 .font(.subheadline).padding(.horizontal, 8).padding(.vertical, 2)
                                 .background(task.priority.color.opacity(0.2))
                                 .foregroundColor(task.priority.color)
                                 .cornerRadius(4)
                         }
                    }
                    .padding().background(Color(.systemGray6)).cornerRadius(12)

                    // Status Section (If Completed)
                    if task.isCompleted {
                        CompletedTaskSection(task: task)
                    }

                    // Action Buttons Section
                    VStack(spacing: 12) {
                        if isUpdating {
                             ProgressView("Updating...")
                                 .padding()
                         } else {
                             if task.isCompleted {
                                 // Mark as Incomplete Button
                                 AsyncButton("Mark as Incomplete", role: .destructive) {
                                     await markAsIncomplete()
                                 } onError: { error in
                                     errorMessage = error.localizedDescription
                                     showError = true
                                 }
                                 .buttonStyle(.borderedProminent)
                                 .tint(.red)
                                 .frame(maxWidth: .infinity)
                             } else {
                                 // Complete Task Button
                                 AsyncButton("Complete Task") {
                                     await completeTask()
                                 } onError: { error in
                                     errorMessage = error.localizedDescription
                                     showError = true
                                 }
                                 .buttonStyle(.borderedProminent)
                                 .tint(.green)
                                 .frame(maxWidth: .infinity)
                             }
                         }
                    }
                    .padding(.top)
                }
                .padding()
            }
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                 ToolbarItem(placement: .confirmationAction) {
                     Button("Close") {
                         // Cancel any running tasks when closing
                         completeTask?.cancel()
                         markIncompleteTask?.cancel()
                         presentationMode.wrappedValue.dismiss()
                     }
                 }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { errorMessage = "" }
            } message: {
                Text(errorMessage)
            }
        }
        .navigationViewStyle(.stack)
        .onDisappear {
            // Clean up running tasks
            completeTask?.cancel()
            markIncompleteTask?.cancel()
        }
    }

    // MARK: - Async Methods

    private func completeTask() async {
        print("DEBUG: Completing regular task \(task.id ?? "N/A")")
        guard let userId = userState.currentUser?.uid else {
            errorMessage = "Cannot complete task: User not found."
            showError = true
            return
        }
        
        // Cancel previous task if it exists
        completeTask?.cancel()
        
        isUpdating = true
        
        // Create a new task
        completeTask = Task {
            do {
                // Using async/await API directly
                _ = try await shiftService.markTaskCompleted(
                    in: shiftId,
                    taskId: task.id ?? "",
                    completedBy: userId,
                    photoURL: nil
                )
                
                // Only update UI if task wasn't cancelled
                if !Task.isCancelled {
                    isUpdating = false
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                // Only update UI if task wasn't cancelled
                if !Task.isCancelled {
                    isUpdating = false
                    errorMessage = "Failed to complete task: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }

    private func markAsIncomplete() async {
        print("DEBUG: Marking task \(task.id ?? "N/A") as incomplete")
        
        // Cancel previous task if it exists
        markIncompleteTask?.cancel()
        
        isUpdating = true
        
        // Create updated task
        var updatedTask = task
        updatedTask.isCompleted = false
        updatedTask.photoURL = nil
        updatedTask.completedBy = nil
        updatedTask.completedAt = nil
        
        // Create a new task
        markIncompleteTask = Task {
            do {
                // Using async/await API directly
                _ = try await shiftService.updateTask(in: shiftId, task: updatedTask)
                
                // Only update UI if task wasn't cancelled
                if !Task.isCancelled {
                    isUpdating = false
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                // Only update UI if task wasn't cancelled
                if !Task.isCancelled {
                    isUpdating = false
                    errorMessage = "Failed to mark task as incomplete: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

// MARK: - Completed Task Section Helper View
@MainActor
struct CompletedTaskSection: View {
    let task: ShiftTask
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)
                Text("Completed")
                    .font(.headline)
                    .foregroundColor(.green)
                
                Spacer()
                
                if let completedAt = task.completedAt {
                    Text(completedAt.dateValue(), style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let completedBy = task.completedBy, !completedBy.isEmpty {
                HStack {
                    Text("Completed by:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(completedBy) // In a real app, you'd lookup the user name
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }
            
            if let photoURL = task.photoURL, !photoURL.isEmpty {
                TaskPhotoView(photoURL: photoURL)
                    .frame(height: 180)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }



