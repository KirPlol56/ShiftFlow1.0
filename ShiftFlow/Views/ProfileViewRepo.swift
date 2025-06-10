//
//  ProfileViewRepo.swift
//  ShiftFlow
//
//  Created by Kirill P on 11/03/2025.
//

import SwiftUI

import SwiftUI

struct ProfileViewRepo: View {
    @EnvironmentObject var userState: UserState
    @EnvironmentObject var authService: FirebaseAuthenticationServiceWithRepo

    var body: some View {
        // Use a List for better structure if more items are added later
        List {
            Section(header: Text("User Information")) {
                if let user = userState.currentUser {
                    InfoRow(label: "Name", value: user.name)
                    InfoRow(label: "Email", value: user.email ?? "N/A")
                    InfoRow(label: "Role", value: user.roleTitle)
                    InfoRow(label: "Company", value: user.companyName ?? "N/A")
                    // Optionally display isManager status
                    InfoRow(label: "Permissions", value: user.isManager ? "Manager" : "Standard")
                } else {
                    Text("Not logged in")
                        .foregroundColor(.gray)
                }
            }

            Section { // Logout Button Section
                Button(role: .destructive) { // Use destructive role for logout button
                    print("Logout button tapped")
                    authService.signOutUser()
                } label: {
                    HStack {
                        Spacer() // Center the text
                        Text("Logout")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Profile") // Set title if used in NavigationView
    }
}
