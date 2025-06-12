//
//  CheckListRowBarista.swift
//  ShiftFlow
//
//  Created by Kirill P on 21/04/2025.
//

import SwiftUI

struct CheckListRowBarista: View {
    let checkList: CheckList
    let isActiveToday: Bool
    let isCurrentSection: Bool
    @Binding var roleNameCache: [String: String] // Use cache for role names

    // Helper to get display names for assigned roles
    private var assignedRoleNames: String? {
        guard let ids = checkList.assignedRoleIds, !ids.isEmpty else { return nil }
        return ids.compactMap { roleNameCache[$0] ?? $0 }.joined(separator: ", ") // Show ID if name not found
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(checkList.title)
                    .font(.headline)
                    .foregroundColor(isActiveToday ? .primary : .gray) // Dim if not today

                HStack(spacing: 12) { // Use spacing
                    Label(checkList.frequency.displayName, systemImage: "calendar.arrow.counterclockwise")
                    Label("\(checkList.tasks.count) Tasks", systemImage: "list.bullet.rectangle.portrait")
                    // Display assigned roles if any
                    if let roleNames = assignedRoleNames {
                         Label(roleNames, systemImage: "person.2")
                             .lineLimit(1) // Prevent excessive wrapping
                    }
                }
                .font(.subheadline)
                .foregroundColor(isActiveToday ? .secondary : .gray.opacity(0.7)) // Dim further if not today
            }

            Spacer() // Pushes content left

            // Indicators
            if isActiveToday {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.caption)
                    .help("Active Today")
            }
            if isCurrentSection && isActiveToday { // Only show section indicator if also active today
                Image(systemName: "figure.walk.circle.fill") // Example icon for current section
                     .foregroundColor(.blue)
                     .font(.caption)
                     .padding(.leading, -4) // Adjust spacing slightly
                     .help("Current Section")
            }
        }
        .padding(.vertical, 8) // Add padding to row
        .opacity(isActiveToday ? 1.0 : 0.6) // Reduce opacity if not active today
    }
}
