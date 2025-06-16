//
//  ShiftTask.swift
//  ShiftFlow
//
//  Created by Kirill P on 13/03/2025.
//

import Foundation
import FirebaseFirestore
import SwiftUI

struct ShiftTask: Identifiable, Codable {
    @DocumentID var id: String? // Firestore populates this when fetched
    var title: String
    var description: String
    var isCompleted: Bool
    var priority: TaskPriority
    var requiresPhotoProof: Bool
    var photoURL: String?
    var completedBy: String?
    var completedAt: Timestamp?
    var createdAt: Timestamp
    var assignedRoleIds: [String]?

   

    // TaskPriority enum (already Codable)
    enum TaskPriority: String, Codable, CaseIterable {
        case low = "low"
        case medium = "medium"
        case high = "high"

        // Keep display helpers
        var displayValue: String {
            switch self {
            case .low: return "Low"
            case .medium: return "Medium"
            case .high: return "High"
            }
        }
        var color: Color {
            switch self {
            case .low: return .green
            case .medium: return .orange
            case .high: return .red
            }
        }
    }

    // Initializer accepting Dates, converting to Timestamps
    init(id: String? = UUID().uuidString, // Generate a new UUID by default
             title: String,
             description: String = "",
             isCompleted: Bool = false,
             priority: TaskPriority = .medium,
             requiresPhotoProof: Bool = false,
             photoURL: String? = nil,
             completedBy: String? = nil,
             completedAt: Date? = nil,
             createdAt: Date = Date(),
             assignedRoleIds: [String]? = nil) {
            self.id = id // Use provided ID or generated UUID
            self.title = title
            self.description = description
            self.isCompleted = isCompleted
            self.priority = priority
            self.requiresPhotoProof = requiresPhotoProof
            self.photoURL = photoURL
            self.completedBy = completedBy
            self.completedAt = completedAt.map { Timestamp(date: $0) }
            self.createdAt = Timestamp(date: createdAt)
            self.assignedRoleIds = assignedRoleIds ?? []
        }

    // --- Keep Helper methods ---
    // These might need minor adjustments if TaskWithPhotoProof also becomes Codable
    // Ensure they handle Timestamp conversion if needed.
    func toPhotoProofTask() -> TaskWithPhotoProof {
             return TaskWithPhotoProof(
                 id: id, // Pass optional ID (TaskWithPhotoProof init handles nil)
                 title: title,
                 description: description,
                 isCompleted: isCompleted,
                 priority: TaskWithPhotoProof.TaskPriority(rawValue: priority.rawValue) ?? .medium,
                 photoURL: photoURL,
                 completedBy: completedBy,
                 // CORRECT: Convert Timestamp? -> Date? using .dateValue()
                 completedAt: completedAt?.dateValue(),
                 // CORRECT: Convert Timestamp -> Date using .dateValue()
                 createdAt: createdAt.dateValue()
             )
         }

        // --- fromPhotoProofTask and other helpers remain the same ---
         static func fromPhotoProofTask(_ photoTask: TaskWithPhotoProof, requiresPhotoProof: Bool = true) -> ShiftTask {
              // Use the ShiftTask initializer which accepts Dates
              return ShiftTask(
                  id: photoTask.id,
                  title: photoTask.title,
                  description: photoTask.description,
                  isCompleted: photoTask.isCompleted,
                  priority: TaskPriority(rawValue: photoTask.priority.rawValue) ?? .medium,
                  requiresPhotoProof: requiresPhotoProof,
                  photoURL: photoTask.photoURL,
                  completedBy: photoTask.completedBy,
                  // Pass Date? from TaskWithPhotoProof init (assuming it accepts Date?)
                  // If TaskWithPhotoProof stores Timestamp, convert here: photoTask.completedAt?.dateValue()
                  completedAt: photoTask.completedAt?.dateValue(),
                  // Pass Date from TaskWithPhotoProof init
                  // If TaskWithPhotoProof stores Timestamp, convert here: photoTask.createdAt.dateValue()
                  createdAt: photoTask.createdAt.dateValue(),
                  assignedRoleIds: nil
              )
          }

         func withPhotoInfo(photoURL: String, completedBy: String, completedAt: Date) -> ShiftTask {
             var updatedTask = self
             updatedTask.isCompleted = true
             updatedTask.photoURL = photoURL
             updatedTask.completedBy = completedBy
             updatedTask.completedAt = Timestamp(date: completedAt)
             return updatedTask
         }

         func asIncomplete() -> ShiftTask {
             var updatedTask = self
             updatedTask.isCompleted = false
             updatedTask.photoURL = nil
             updatedTask.completedBy = nil
             updatedTask.completedAt = nil
             return updatedTask
         }
}
