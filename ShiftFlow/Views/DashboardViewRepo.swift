//
//  DashboardViewRepo.swift
//  ShiftFlow
//
//  Created by Kirill P on 24/03/2025.
//

import SwiftUI

struct DashboardViewRepo: View {
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var authService: FirebaseAuthenticationServiceWithRepo
    @EnvironmentObject var shiftService: ShiftServiceWithRepo
    @State private var selectedTab = 0
    
    var body: some View {
        VStack {
            // Header with user name
            HStack {
                Spacer()
                Text(userState.currentUser?.name ?? "User")
                    .font(.headline)
                    .padding()
            }
            
            // Tab selector
            Picker("", selection: $selectedTab) {
                Text("Completed Tasks").tag(0)
                Text("Settings").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            // Tab content
            if selectedTab == 0 {
                CompletedTasksViewRepo()
                    .environmentObject(userState)
                    .environmentObject(authService)
                    .environmentObject(shiftService)
            } else {
                SettingsViewRepo()
                    .environmentObject(authService)
            }
        }
    }
}
