//
//  ContentView.swift
//  ShiftFlow
//
//  Created by Kirill P on 09/03/2025.
//

import SwiftUI

struct ContentViewWithRepo: View {
    @EnvironmentObject var authService: FirebaseAuthenticationServiceWithRepo
    @StateObject var userState = UserState()
    
    var body: some View {
        if let user = authService.currentUser {
            ManagerOrBaristaViewWithRepo(user: user)
                .environmentObject(userState)
                .onAppear {
                    userState.currentUser = user
                }
        } else {
            NavigationView {
                VStack(spacing: 20) {
                    LoginViewWithRepo()
                    
                    NavigationLink(
                        destination: RegistrationViewWithRepo(),
                        label: {
                            Text("Register New Account")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    )
                }
                .padding()
            }
        }
    }
}

struct ManagerOrBaristaViewWithRepo: View {
    let user: User
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var authService: FirebaseAuthenticationServiceWithRepo
    @EnvironmentObject var shiftService: ShiftServiceWithRepo
    @EnvironmentObject var roleService: RoleServiceWithRepo
    @EnvironmentObject var checkListService: CheckListServiceWithRepo
    
    @State private var selectedTab = 0
    @State private var showingCreateShiftSheet = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Check Lists Tab
            VStack {
                Text("Shift Check Lists")
                    .font(.title)
                    .padding()
                
                if user.isManager {
                    CheckListsViewRepo()
                        .environmentObject(userState)
                        .environmentObject(checkListService)
                        .environmentObject(roleService)
                } else {
                    BaristaCheckListViewWithRepo()
                        .environmentObject(userState)
                        .environmentObject(shiftService)
                        .environmentObject(checkListService)
                }
            }
            .tabItem {
                Label("Check Lists", systemImage: "checklist")
            }
            .tag(0)
            
            // Shifts Tab
            ShiftsViewWithRepo(user: user)
                .environmentObject(shiftService)
                .environmentObject(userState)
                .environmentObject(roleService)
                .environmentObject(authService)
                .tabItem {
                    Label("Shifts", systemImage: "calendar")
                }
                .tag(1)
            
            // Team Management Tab (Managers Only)
            if user.isManager {
                TeamManagementViewRepo()
                    .environmentObject(userState)
                    .environmentObject(authService)
                    .environmentObject(roleService)
                    .tabItem {
                        Label("Team", systemImage: "person.3")
                    }
                    .tag(2)
            }
            
            // Dashboard Tab
            DashboardViewRepo()
                .environmentObject(userState)
                .environmentObject(authService)
                .environmentObject(shiftService)
                .tabItem {
                    Label("Dashboard", systemImage: "gauge")
                }
                .tag(user.isManager ? 3 : 2)
        }
        .onAppear {
            // Load shifts when view appears - using Task to handle async calls
            if let companyId = user.companyId {
                Task {
                    do {
                        if user.isManager {
                            try await shiftService.fetchShifts(for: companyId)
                        } else {
                            try await shiftService.fetchUserShifts(for: user.uid, in: companyId)
                        }
                    } catch {
                        // Handle fetch error, e.g., show an alert or log
                        print("Error loading shifts: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}
