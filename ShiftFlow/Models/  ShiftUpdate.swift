//
//    ShiftUpdate.swift
//  ShiftFlow
//
//  Created by Kirill P on 10/06/2025.
//

import Foundation
import FirebaseFirestore

/// Represents a single update operation on a shift
enum ShiftUpdate {
    case addTask(ShiftTask)
    case updateTask(ShiftTask)
    case removeTask(String) // taskId
    case markTaskCompleted(taskId: String, completedBy: String, photoURL: String?)
    case updateAssignees([String]) // userIds
    case updateShiftStatus(Shift.ShiftStatus)
    case updateShiftTime(startTime: Date, endTime: Date)
}

/// Represents a batch update for multiple shifts
struct ShiftBatchUpdate {
    let shiftId: String
    let updates: [ShiftUpdate]
}
