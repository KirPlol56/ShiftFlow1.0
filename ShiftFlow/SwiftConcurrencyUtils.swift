//
//  SwiftConcurrencyUtils.swift
//  ShiftFlow
//
//  Created by Kirill P on 21/04/2025.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Generic Completion Handler to Async/Await Converters

/// Helper functions to convert callback-based APIs to async/await
enum AsyncHelpers {
    // MARK: - Actor Definitions
    
    /// Actor for isolating debouncer state
    actor DebouncerState<T> {
        var task: Task<T, Error>?
        var latestCall: Date = .distantPast
        
        init() {} // Explicit initializer to make it accessible
        
        func cancelTask() {
            task?.cancel()
            task = nil
        }
        
        func updateLatestCall(_ newTime: Date) {
            latestCall = newTime
        }
        
        func isLatestCall(_ callTime: Date) -> Bool {
            return callTime == latestCall
        }
        
        func createAndSetTask(_ newTask: Task<T, Error>) {
            task = newTask
        }
        
        func getTaskValue() async throws -> T {
            guard let task = task else {
                throw NSError(domain: "ShiftFlow", code: 2, userInfo: [NSLocalizedDescriptionKey: "Task was unexpectedly nil"])
            }
            return try await task.value
        }
    }
    
    /// Converts a callback-based API that returns a Result to async/await
    /// - Parameter body: The function that takes a Result callback
    /// - Returns: The successful value from the Result
    static func withResultCallback<Success, Failure: Error>(
        _ body: @escaping (@escaping (Result<Success, Failure>) -> Void) -> Void
    ) async throws -> Success {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Success, Error>) in
            body { result in
                switch result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Converts a callback-based API that returns a Bool and error string to async/await
    /// - Parameter body: The function that takes a (Bool, String?) -> Void callback
    static func withBoolCallback(
        _ body: @escaping (@escaping (Bool, String?) -> Void) -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            body { success, errorMessage in
                if success {
                    continuation.resume()
                } else {
                    let error = NSError(
                        domain: "ShiftFlow",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: errorMessage ?? "Operation failed"]
                    )
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Converts a completion handler with optional value and error to async/await
    /// - Parameter body: The function that takes a completion handler with value and error
    /// - Returns: The value if successful
    static func withCompletion<T>(
        _ body: @escaping (@escaping (T?, Error?) -> Void) -> Void
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            body { value, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let value = value {
                    continuation.resume(returning: value)
                } else {
                    continuation.resume(throwing: NSError(
                        domain: "ShiftFlow",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "No value returned and no error provided"]
                    ))
                }
            }
        }
    }
    
    /// Executes an operation with a specified timeout
    /// - Parameters:
    ///   - seconds: The timeout in seconds
    ///   - operation: The async operation to perform
    /// - Returns: The result of the operation
    /// - Throws: TimeoutError if the operation exceeds the specified timeout
    static func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
        return try await TaskTimeout.withTimeout(seconds: seconds, operation: operation)
    }
    
    /// Retries an async operation with exponential backoff
    /// - Parameters:
    ///   - maxAttempts: Maximum number of retry attempts
    ///   - initialDelay: Initial delay between retries in seconds
    ///   - operation: The async operation to retry
    /// - Returns: The result of the successful operation
    /// - Throws: The last error encountered after all retry attempts fail
    static func withRetry<T>(
        maxAttempts: Int = 3,
        initialDelay: Double = 1.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var currentDelay = initialDelay
        var attempts = 0
        
        while true {
            do {
                attempts += 1
                return try await operation()
            } catch {
                if attempts >= maxAttempts {
                    throw error
                }
                
                // Wait with exponential backoff before retrying
                try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                currentDelay *= 2 // Exponential backoff
            }
        }
    }
    
    /// Debounces an async operation by delaying execution until after a specified time period
    /// - Parameters:
    ///   - milliseconds: The debounce time period in milliseconds
    ///   - operation: The async operation to debounce
    /// - Returns: A new async operation that debounces the original
    static func debounce<T>(
        milliseconds: Int,
        operation: @escaping () async throws -> T
    ) -> (@Sendable () async throws -> T) {
        // Create a state actor outside the returned closure to isolate mutable state
        let state = DebouncerState<T>()
        
        return {
            // Cancel any previous task
            await state.cancelTask()
            
            // Update latest call time
            let callTime = Date()
            await state.updateLatestCall(callTime)
            
            // Create a debounce delay
            try await Task.sleep(nanoseconds: UInt64(milliseconds * 1_000_000))
            
            // If this isn't the latest call anymore, don't execute
            guard await state.isLatestCall(callTime) else {
                throw CancellationError()
            }
            
            // Create and return the task
            let newTask = Task<T, Error> {
                try await operation()
            }
            
            await state.createAndSetTask(newTask)
            
            return try await state.getTaskValue()
        }
    }
}

/// Helper for handling tasks with timeouts
enum TaskTimeout {
    /// Execute a task with a timeout
    /// - Parameters:
    ///   - seconds: Timeout in seconds
    ///   - operation: The async operation to perform
    /// - Returns: The result of the operation
    /// - Throws: TimeoutError if the operation times out
    static func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: Result<T, Error>.self) { group in
            // Add the actual operation task
            group.addTask {
                do {
                    let result = try await operation()
                    return .success(result)
                } catch {
                    return .failure(error)
                }
            }
            
            // Add the timeout task
            group.addTask {
                do {
                    try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                } catch {
                    // Ignore cancellation errors
                }
                return .failure(TimeoutError(seconds: seconds))
            }
            
            // Wait for the first task to complete
            if let firstResult = try await group.next() {
                // Cancel any remaining tasks
                group.cancelAll()
                
                // Return the result or throw the error
                switch firstResult {
                case .success(let value):
                    return value
                case .failure(let error):
                    throw error
                }
            } else {
                // This shouldn't happen, but just in case
                throw TimeoutError(seconds: seconds)
            }
        }
    }
    
    /// Error thrown when a task times out
    struct TimeoutError: LocalizedError {
        let seconds: Double
        
        var errorDescription: String? {
            "Operation timed out after \(String(format: "%.1f", seconds)) seconds"
        }
    }
}

// MARK: - SwiftUI Async Extensions

/// Extensions for working with async operations in SwiftUI
extension View {
    /// Applies an async operation to a view with automatic loading state management
    /// - Parameters:
    ///   - isLoading: Binding to a loading state
    ///   - operation: The async operation to perform
    /// - Returns: The modified view
    func asyncOperation<T>(isLoading: Binding<Bool>, operation: @escaping () async throws -> T) -> some View {
        self.modifier(AsyncOperationModifier(isLoading: isLoading, operation: operation))
    }
    
    /// Applies async loading with full error handling
    /// - Parameters:
    ///   - isLoading: Binding to a loading state
    ///   - errorMessage: Binding to an error message
    ///   - showError: Binding to control error alert visibility
    ///   - operation: The async operation to perform
    /// - Returns: The modified view
    func asyncOperationWithErrorHandling<T>(
        isLoading: Binding<Bool>,
        errorMessage: Binding<String>,
        showError: Binding<Bool>,
        operation: @escaping () async throws -> T
    ) -> some View {
        self.modifier(AsyncOperationWithErrorHandlingModifier(
            isLoading: isLoading,
            errorMessage: errorMessage,
            showError: showError,
            operation: operation
        ))
    }
    
    /// Applies a loading overlay when isLoading is true
    /// - Parameter isLoading: Loading state
    /// - Returns: The modified view
    func loadingOverlay(isLoading: Bool) -> some View {
        self.overlay(
            Group {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.4)
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Loading...")
                                .foregroundColor(.white)
                        }
                        .padding(20)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                }
            }
        )
        .allowsHitTesting(!isLoading)
    }
    
    /// Adds an error alert to the view
    /// - Parameters:
    ///   - showError: Binding to control error alert visibility
    ///   - errorMessage: Binding to an error message
    /// - Returns: The modified view with an alert
    func errorAlert(isPresented: Binding<Bool>, errorMessage: Binding<String>) -> some View {
        self.alert("Error", isPresented: isPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage.wrappedValue)
        }
    }
    
    /// Creates a view that runs an async task and displays its result
    /// - Parameters:
    ///   - priority: Task priority
    ///   - operation: The async operation to perform
    ///   - content: Content to display when the operation completes successfully
    ///   - placeholder: Content to display while the operation is running
    ///   - failureContent: Content to display if the operation fails
    /// - Returns: The view displaying appropriate content based on task state
    func asyncContent<T, C: View, P: View, F: View>(
        priority: TaskPriority? = nil,
        @ViewBuilder content: @escaping (T) -> C,
        @ViewBuilder placeholder: @escaping () -> P,
        @ViewBuilder failureContent: @escaping (Error) -> F,
        operation: @escaping () async throws -> T
    ) -> some View {
        AsyncContentView(
            priority: priority,
            content: content,
            placeholder: placeholder,
            failureContent: failureContent,
            operation: operation
        )
    }
    
    /// Creates a view that automatically refreshes at a specified interval
    /// - Parameters:
    ///   - interval: The refresh interval in seconds
    ///   - operation: The async operation to perform
    /// - Returns: The modified view
    func refreshEvery(_ interval: TimeInterval, perform operation: @escaping () async -> Void) -> some View {
        self.modifier(AutoRefreshModifier(interval: interval, operation: operation))
    }
    
    /// Creates a view that performs an operation when the value changes
    /// - Parameters:
    ///   - value: The value to observe
    ///   - debounceTime: The debounce time to wait after the value changes (nil for no debounce)
    ///   - operation: The async operation to perform
    /// - Returns: The modified view
    func onChange<V: Equatable>(of value: V, debounceTime: TimeInterval? = nil, perform operation: @escaping (V) async -> Void) -> some View {
        self.modifier(OnChangeAsyncModifier(value: value, debounceTime: debounceTime, operation: operation))
    }
}

// MARK: - Implementation Modifiers

/// Modifier for basic async operations
struct AsyncOperationModifier<T>: ViewModifier {
    @Binding var isLoading: Bool
    let operation: () async throws -> T
    
    func body(content: Content) -> some View {
        content
            .onChange(of: isLoading) { _, newValue in
                if newValue {
                    Task {
                        do {
                            _ = try await operation()
                            await MainActor.run {
                                isLoading = false
                            }
                        } catch is CancellationError {
                            // Handle cancellation gracefully
                            await MainActor.run {
                                isLoading = false
                            }
                        } catch {
                            await MainActor.run {
                                isLoading = false
                                print("AsyncOperation error: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
            .onDisappear {
                // No explicit task cancellation needed as we're using Task directly inside onChange
                if isLoading {
                    isLoading = false
                }
            }
    }
}

/// Modifier for async operations with error handling
struct AsyncOperationWithErrorHandlingModifier<T>: ViewModifier {
    @Binding var isLoading: Bool
    @Binding var errorMessage: String
    @Binding var showError: Bool
    let operation: () async throws -> T
    @State private var currentTask: Task<Void, Never>? = nil
    
    func body(content: Content) -> some View {
        content
            .task {
                if isLoading {
                    await executeOperation()
                }
            }
            .onChange(of: isLoading) { _, newValue in
                if newValue {
                    // Cancel previous task if it exists
                    currentTask?.cancel()
                    
                    // Create new task
                    currentTask = Task {
                        await executeOperation()
                    }
                }
            }
            .onDisappear {
                // Cancel task when view disappears
                currentTask?.cancel()
                currentTask = nil
            }
    }
    
    private func executeOperation() async {
        do {
            _ = try await operation()
            
            // Only update UI if task wasn't cancelled
            if !Task.isCancelled {
                await MainActor.run {
                    isLoading = false
                }
            }
        } catch is CancellationError {
            // Handle cancellation gracefully
            await MainActor.run {
                isLoading = false
            }
        } catch {
            // Only update UI if task wasn't cancelled
            if !Task.isCancelled {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

/// Modifier for automatic periodic refreshing
struct AutoRefreshModifier: ViewModifier {
    let interval: TimeInterval
    let operation: () async -> Void
    
    @State private var refreshTask: Task<Void, Never>? = nil
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                startRefreshTimer()
            }
            .onDisappear {
                cancelRefreshTimer()
            }
    }
    
    private func startRefreshTimer() {
        // Cancel existing task if any
        refreshTask?.cancel()
        
        // Start new refresh task
        refreshTask = Task {
            while !Task.isCancelled {
                await operation()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }
    
    private func cancelRefreshTimer() {
        refreshTask?.cancel()
        refreshTask = nil
    }
}

/// Modifier for handling async onChange with optional debounce
struct OnChangeAsyncModifier<V: Equatable>: ViewModifier {
    let value: V
    let debounceTime: TimeInterval?
    let operation: (V) async -> Void
    
    @State private var currentTask: Task<Void, Never>? = nil
    @State private var lastOperationTime: Date = .distantPast
    @State private var queuedValue: V?
    
    func body(content: Content) -> some View {
        content
            .onChange(of: value) { _, newValue in
                if let debounceTime = debounceTime {
                    // Debounced operation
                    handleDebouncedChange(newValue: newValue, debounceTime: debounceTime)
                } else {
                    // Immediate operation
                    handleImmediateChange(newValue: newValue)
                }
            }
            .onDisappear {
                // Cancel any pending tasks
                currentTask?.cancel()
                currentTask = nil
            }
    }
    
    private func handleImmediateChange(newValue: V) {
        // Cancel existing task if any
        currentTask?.cancel()
        
        // Create new task for this value
        currentTask = Task {
            await operation(newValue)
        }
    }
    
    private func handleDebouncedChange(newValue: V, debounceTime: TimeInterval) {
        // Save the latest value
        queuedValue = newValue
        
        // Cancel existing task if any
        currentTask?.cancel()
        
        // Create new debounce task
        currentTask = Task {
            // Store when we started this debounce
            let startTime = Date()
            lastOperationTime = startTime
            
            // Wait for the debounce duration
            try? await Task.sleep(nanoseconds: UInt64(debounceTime * 1_000_000_000))
            
            // Only proceed if we're still the latest debounce and not cancelled
            if startTime == lastOperationTime && !Task.isCancelled {
                // Use the latest queued value
                if let latestValue = queuedValue {
                    await operation(latestValue)
                }
            }
        }
    }
}

// MARK: - AsyncContentView

/// A view that displays content based on the state of an asynchronous operation
struct AsyncContentView<T, Content: View, Placeholder: View, FailureContent: View>: View {
    let priority: TaskPriority?
    let content: (T) -> Content
    let placeholder: () -> Placeholder
    let failureContent: (Error) -> FailureContent
    let operation: () async throws -> T
    
    enum LoadState {
        case loading
        case success(T)
        case failure(Error)
    }
    
    @State private var state: LoadState = .loading
    @State private var task: Task<Void, Never>? = nil
    
    var body: some View {
        Group {
            switch state {
            case .loading:
                placeholder()
            case .success(let value):
                content(value)
            case .failure(let error):
                failureContent(error)
            }
        }
        .task(priority: priority ?? .medium) {
            // Cancel previous task if exists
            task?.cancel()
            
            // Create new task
            task = Task(priority: priority ?? .medium) {
                do {
                    state = .loading
                    let result = try await operation()
                    
                    // Only update state if task wasn't cancelled
                    if !Task.isCancelled {
                        await MainActor.run {
                            state = .success(result)
                        }
                    }
                } catch is CancellationError {
                    // Handle cancellation gracefully
                } catch {
                    // Only update state if task wasn't cancelled
                    if !Task.isCancelled {
                        await MainActor.run {
                            state = .failure(error)
                        }
                    }
                }
            }
        }
        .onDisappear {
            // Cancel task when view disappears
            task?.cancel()
            task = nil
        }
    }
}
