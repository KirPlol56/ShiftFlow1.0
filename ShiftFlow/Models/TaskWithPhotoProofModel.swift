//
//  TaskWithPhotoProof.swift
//  ShiftFlow
//
//  Created by Kirill P on 27/03/2025.
//

// TaskWithPhotoProofModel.swift

import Foundation
import FirebaseFirestore       // Core SDK
import SwiftUI

/// A specialized task model for tasks that require photo proof
// Make it Codable as well for consistency
struct TaskWithPhotoProof: Identifiable, Codable {
    // Keep @DocumentID if you fetch these directly, otherwise optional String is fine
    @DocumentID var id: String? // Optional ID
    var title: String
    var description: String
    var isCompleted: Bool
    var priority: TaskPriority // Enum conforms to Codable
    var photoURL: String?
    var completedBy: String?
    var completedAt: Timestamp? // Use Timestamp
    var createdAt: Timestamp   // Use Timestamp

    // TaskPriority enum remains the same (already Codable)
    enum TaskPriority: String, Codable, CaseIterable {
        case low = "low", medium = "medium", high = "high"
        var displayValue: String { rawValue.capitalized }
        var color: Color {
            switch self {
            case .low: return .green
            case .medium: return .orange
            case .high: return .red
            }
        }
    }

    // Initializer accepting Dates, converting to Timestamps
    init(id: String? = nil, // ID is optional
         title: String,
         description: String = "",
         isCompleted: Bool = false,
         priority: TaskPriority = .medium,
         photoURL: String? = nil,
         completedBy: String? = nil,
         completedAt: Date? = nil, // Accept Date
         createdAt: Date = Date()) { // Accept Date
        self.id = id // Store if provided
        self.title = title
        self.description = description
        self.isCompleted = isCompleted
        self.priority = priority
        self.photoURL = photoURL
        self.completedBy = completedBy
        self.completedAt = completedAt.map { Timestamp(date: $0) } // Convert Date to Timestamp
        self.createdAt = Timestamp(date: createdAt) // Convert Date to Timestamp
    }

    // --- FIX Conversion Methods ---

    /// Convert to a regular ShiftTask (which now uses Timestamps)
    func toShiftTask(requiresPhotoProof: Bool = true) -> ShiftTask {
        return ShiftTask(
            id: id, // Pass optional ID
            title: title,
            description: description,
            isCompleted: isCompleted,
            priority: ShiftTask.TaskPriority(rawValue: priority.rawValue) ?? .medium,
            requiresPhotoProof: requiresPhotoProof,
            photoURL: photoURL,
            completedBy: completedBy,
            // Pass Dates to ShiftTask initializer (it converts them back to Timestamp)
            completedAt: completedAt?.dateValue(),
            createdAt: createdAt.dateValue(),
            assignedRoleIds: nil // Or handle assigned roles if needed
        )
    }

    // Create a TaskWithPhotoProof instance from a regular ShiftTask (which now uses Timestamps)
    // This method should likely reside in ShiftTask.swift, but if needed here:
    static func fromShiftTask(_ task: ShiftTask) -> TaskWithPhotoProof {
         // Ensure ShiftTask has necessary data (including an ID)
         guard let taskId = task.id else {
             // Handle error: ShiftTask must have an ID to be converted
             fatalError("Cannot convert ShiftTask without an ID to TaskWithPhotoProof")
             // Or return nil / throw an error
         }
         return TaskWithPhotoProof(
             id: taskId,
             title: task.title,
             description: task.description,
             isCompleted: task.isCompleted,
             priority: TaskPriority(rawValue: task.priority.rawValue) ?? .medium,
             photoURL: task.photoURL,
             completedBy: task.completedBy,
             // Pass Dates to the initializer (it converts them to Timestamp)
             completedAt: task.completedAt?.dateValue(),
             createdAt: task.createdAt.dateValue()
         )
     }
}
