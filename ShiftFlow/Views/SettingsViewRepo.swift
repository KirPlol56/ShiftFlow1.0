//
//  SettingsViewRepo.swift
//  ShiftFlow
//
//  Created by Kirill P on 24/03/2025.
//

import SwiftUI

struct SettingsViewRepo: View {
    @EnvironmentObject var authService: FirebaseAuthenticationServiceWithRepo
    @State private var showingLogoutConfirmation = false
    
    var body: some View {
        List {
            Section(header: Text("Account")) {
                Button(action: {
                    showingLogoutConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                        Text("Logout")
                            .foregroundColor(.red)
                    }
                }
            }
            
            Section(header: Text("App Information")) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.gray)
                }
                
                HStack {
                    Text("Build")
                    Spacer()
                    Text("2025.03.18")
                        .foregroundColor(.gray)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Settings")
        .alert(isPresented: $showingLogoutConfirmation) {
            Alert(
                title: Text("Logout"),
                message: Text("Are you sure you want to logout?"),
                primaryButton: .destructive(Text("Logout")) {
                    authService.signOutUser()
                },
                secondaryButton: .cancel()
            )
        }
    }
}
