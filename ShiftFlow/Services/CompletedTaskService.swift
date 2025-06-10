//
//  CompletedTaskViewModel.swift
//  ShiftFlow
//
//  Created by Kirill P on 25/03/2025.
//

import Foundation

struct CompletedTaskViewModel: Identifiable {
    let id: String
    let title: String
    let description: String
    let priority: ShiftTask.TaskPriority
    let baristaName: String
    let baristaId: String
    let completionDate: Date
    let photoURL: String?
    let shiftDay: String
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: completionDate)
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: completionDate)
    }
}

