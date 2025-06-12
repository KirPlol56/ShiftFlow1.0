//
//  EditShiftTaskViewRepoWrapper.swift
//  ShiftFlow
//
//  Created by Kirill P on 29/04/2025.
//

import SwiftUI
import FirebaseFirestore

// Wrapper view to simplify the sheet presentation of EditShiftTaskViewRepo
struct EditShiftTaskViewRepoWrapper: View {
    let task: ShiftTask
    let shiftId: String
    
    @EnvironmentObject var shiftService: ShiftServiceWithRepo
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var roleService: RoleServiceWithRepo
    
    var body: some View {
        EditShiftTaskViewRepo(task: task, shiftId: shiftId)
            .environmentObject(shiftService)
            .environmentObject(userState)
            .environmentObject(roleService)
    }
}
