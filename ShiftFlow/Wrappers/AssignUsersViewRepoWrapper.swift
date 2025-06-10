//
//  AssignUsersViewRepoWrapper.swift
//  ShiftFlow
//
//  Created by Kirill P on 29/04/2025.
//

import SwiftUI

// Wrapper view to simplify the sheet presentation of AssignUsersViewRepo
struct AssignUsersViewRepoWrapper: View {
    @Binding var assignedUserIds: [String]
    let companyId: String
    
    @EnvironmentObject var authService: FirebaseAuthenticationServiceWithRepo
    @EnvironmentObject var userState: UserState
    
    var body: some View {
        AssignUsersViewRepo(
            assignedIds: $assignedUserIds,
            companyId: companyId
        )
        .environmentObject(authService)
        .environmentObject(userState)
    }
}
