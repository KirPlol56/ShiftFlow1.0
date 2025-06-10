//
//  TaskManager.swift
//  ShiftFlow
//
//  Created by Kirill P on 24/04/2025.
//

import Foundation
import SwiftUI
import Combine

/// A utility class for managing multiple asynchronous tasks with proper cancellation
@MainActor
class TaskManager: ObservableObject {
    /// Dictionary of tasks by identifier
    @Published private var tasks: [String: Task<Void, Never>] = [:]
    
    /// Start a new task with an identifier
    /// - Parameters:
    ///   - id: Unique identifier for the task
    ///   - priority: Task priority (optional)
    ///   - operation: The async operation to perform
    /// - Returns: The created task
    @discardableResult
    func startTask(id: String, priority: TaskPriority? = nil, operation: @escaping () async throws -> Void) -> Task<Void, Never> {
        // Cancel existing task with the same ID if it exists
        cancelTask(id: id)
        
        // Create and store the new task
        let task = Task(priority: priority ?? .medium) {
            do {
                try await operation()
            } catch {
                if !Task.isCancelled {
                    print("Task \(id) failed with error: \(error.localizedDescription)")
                }
            }
            
            // Remove task from dictionary when completed if not cancelled
            if !Task.isCancelled {
                // Fix: Add underscore to discard the result of MainActor.run
                _ = await MainActor.run {
                    tasks.removeValue(forKey: id)
                }
            }
        }
        
        tasks[id] = task
        return task
    }
    
    /// Cancel a specific task by its identifier
    /// - Parameter id: The task identifier
    func cancelTask(id: String) {
        if let task = tasks[id] {
            task.cancel()
            tasks.removeValue(forKey: id)
        }
    }
    
    /// Cancel all tasks
    func cancelAllTasks() {
        for (_, task) in tasks {
            task.cancel()
        }
        tasks.removeAll()
    }
    
    /// The number of active tasks
    var activeTaskCount: Int {
        return tasks.count
    }
    
    /// Start a task and handle its result
    /// - Parameters:
    ///   - id: Unique identifier for the task
    ///   - priority: Task priority (optional)
    ///   - operation: The async operation to perform
    ///   - onSuccess: Callback for successful completion
    ///   - onError: Callback for error handling
    @discardableResult
    func startTaskWithHandlers<T>(
        id: String,
        priority: TaskPriority? = nil,
        operation: @escaping () async throws -> T,
        onSuccess: @escaping (T) -> Void,
        onError: @escaping (Error) -> Void
    ) -> Task<Void, Never> {
        return startTask(id: id, priority: priority) {
            do {
                let result = try await operation()
                if !Task.isCancelled {
                    await MainActor.run {
                        onSuccess(result)
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        onError(error)
                    }
                }
            }
        }
    }
    
    /// Load data from a URL with proper task management
    /// - Parameters:
    ///   - id: Unique identifier for the task
    ///   - url: URL to load data from
    ///   - onSuccess: Success handler
    ///   - onError: Error handler
    func loadData(id: String, from url: URL, onSuccess: @escaping (Data) -> Void, onError: @escaping (Error) -> Void) {
        startTask(id: id) {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                
                if !Task.isCancelled {
                    await MainActor.run {
                        onSuccess(data)
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        onError(error)
                    }
                }
            }
        }
    }
    
    /// Load an image from a URL with proper task management
    /// - Parameters:
    ///   - id: Unique identifier for the task
    ///   - url: URL to load image from
    ///   - onSuccess: Success handler
    ///   - onError: Error handler
    func loadImage(id: String, from url: URL, onSuccess: @escaping (UIImage) -> Void, onError: @escaping (Error) -> Void) {
        loadData(id: id, from: url, onSuccess: { data in
            if let image = UIImage(data: data) {
                onSuccess(image)
            } else {
                onError(NSError(domain: "TaskManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"]))
            }
        }, onError: onError)
    }
}
