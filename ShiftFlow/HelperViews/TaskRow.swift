//
//  TaskRow.swift
//  ShiftFlow
//
//  Created by Kirill P on 29/04/2025.
//

import SwiftUI

struct TaskRow: View {
    let task: ShiftTask
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(task.isCompleted ? .green : .gray)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .gray : .primary)
                
                if !task.description.isEmpty {
                    Text(task.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                HStack(spacing: 8) {
                    if task.requiresPhotoProof {
                        Label("Photo Required", systemImage: "camera")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    if task.isCompleted, let completedBy = task.completedBy {
                        Label("Completed by \(completedBy)", systemImage: "person.check")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            Spacer()
            
            if task.isCompleted {
                Image(systemName: "checkmark")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
    }
}
