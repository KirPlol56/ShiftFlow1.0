//
//  RoleSelectionContent.swift
//  ShiftFlow
//
//  Created by Kirill P on 29/04/2025.
//

import SwiftUI

struct RoleSelectionContent: View {
    @Binding var assignedRoleIds: [String]
    let companyId: String
    let roleService: RoleServiceWithRepo
    let onDismiss: () -> Void
    
    var body: some View {
        // Use the custom RoleSelectionSheet we created earlier
        RoleSelectionSheet(selectedRoleIds: $assignedRoleIds)
            .environmentObject(roleService)
            .navigationTitle("Assign Roles")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
    }
}
