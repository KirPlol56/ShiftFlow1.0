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
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .strikethrough(task.isCompleted, color: .gray)

                if !task.description.isEmpty {
                    Text(task.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    Circle()
                        .fill(task.priority.color)
                        .frame(width: 8, height: 8)
                    Text(task.priority.displayValue)
                        .font(.caption)
                        .foregroundColor(.gray)

                    if task.requiresPhotoProof {
                        Image(systemName: "camera.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.leading, 5)
                    }
                }
            }
            
            Spacer()
            
            // Show photo icon only if completed and required
            if task.isCompleted && task.photoURL != nil && task.requiresPhotoProof {
                Image(systemName: "photo.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 6)
    }
}
