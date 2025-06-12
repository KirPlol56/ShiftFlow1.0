//
//  AsyncImageView.swift
//  ShiftFlow
//
//  Created by Kirill P on 24/04/2025.
//

import SwiftUI

/// A button that handles async operations with loading state and error handling
struct AsyncButton<Label: View>: View {
    var action: () async throws -> Void
    var role: ButtonRole?
    var onError: ((Error) -> Void)?
    @ViewBuilder var label: () -> Label
    
    @State private var isPerformingTask = false
    @State private var task: Task<Void, Never>? = nil
    
    var body: some View {
        Button(
            role: role,
            action: {
                // Cancel previous task if exists
                task?.cancel()
                
                isPerformingTask = true
                
                // Create new task
                task = Task {
                    do {
                        try await action()
                        
                        // Only update UI if task wasn't cancelled
                        if !Task.isCancelled {
                            await MainActor.run {
                                isPerformingTask = false
                            }
                        }
                    } catch is CancellationError {
                        // Handle cancellation gracefully
                        await MainActor.run {
                            isPerformingTask = false
                        }
                    } catch {
                        // Only update UI if task wasn't cancelled
                        if !Task.isCancelled {
                            await MainActor.run {
                                isPerformingTask = false
                                if let onError = onError {
                                    onError(error)
                                } else {
                                    print("AsyncButton error: \(error.localizedDescription)")
                                }
                            }
                        }
                    }
                }
            },
            label: {
                ZStack {
                    // The button label is made transparent when the task is being performed
                    label().opacity(isPerformingTask ? 0 : 1)
                    
                    if isPerformingTask {
                        ProgressView()
                    }
                }
            }
        )
        .disabled(isPerformingTask)
        .onDisappear {
            // Cancel task when view disappears
            task?.cancel()
            task = nil
        }
    }
}

extension AsyncButton where Label == Text {
    /// Convenience initializer for creating an AsyncButton with a text label
    init(_ titleKey: LocalizedStringKey, role: ButtonRole? = nil, action: @escaping () async throws -> Void, onError: ((Error) -> Void)? = nil) {
        self.action = action
        self.role = role
        self.onError = onError
        self.label = { Text(titleKey) }
    }
}

/// A button that executes an async operation with proper task management
struct ManagedAsyncButton<Label: View>: View {
    /// The task manager
    @ObservedObject var taskManager: TaskManager
    
    /// The task identifier
    let taskId: String
    
    /// The action to perform
    let action: () async throws -> Void
    
    /// The error handler
    let onError: ((Error) -> Void)?
    
    /// The label view builder
    @ViewBuilder let label: () -> Label
    
    /// Whether the button is currently performing its task
    @State private var isPerformingTask = false
    
    var body: some View {
        Button(
            action: {
                isPerformingTask = true
                
                // Use TaskManager for task lifecycle management
                taskManager.startTaskWithHandlers(
                    id: taskId,
                    operation: { try await action() },
                    onSuccess: { _ in
                        self.isPerformingTask = false
                    },
                    onError: { error in
                        self.isPerformingTask = false
                        if let onError = onError {
                            onError(error)
                        } else {
                            print("ManagedAsyncButton error: \(error.localizedDescription)")
                        }
                    }
                )
            },
            label: {
                ZStack {
                    // The button label is made transparent when the task is being performed
                    label().opacity(isPerformingTask ? 0 : 1)
                    
                    if isPerformingTask {
                        ProgressView()
                    }
                }
            }
        )
        .disabled(isPerformingTask)
    }
}

extension ManagedAsyncButton where Label == Text {
    /// Convenience initializer for creating a ManagedAsyncButton with a text label
    init(
        _ titleKey: LocalizedStringKey,
        taskManager: TaskManager,
        taskId: String,
        action: @escaping () async throws -> Void,
        onError: ((Error) -> Void)? = nil
    ) {
        self.taskManager = taskManager
        self.taskId = taskId
        self.action = action
        self.onError = onError
        self.label = { Text(titleKey) }
    }
}
