//
//  LoginViewWithRepo.swift
//  ShiftFlow
//
//  Created by Kirill P on 09/03/2025.
//

import SwiftUI

@MainActor
struct LoginViewWithRepo: View {
    @EnvironmentObject var authService: FirebaseAuthenticationServiceWithRepo
    @State private var email = ""
    @State private var password = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    
    // Task management
    @State private var loginTask: Task<Void, Never>? = nil

    var body: some View {
        VStack {
            // App Logo or Title
            Text("ShiftFlow")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 30)
            
            // Email Field
            TextField("Email", text: $email)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .textContentType(.emailAddress)
                .disableAutocorrection(true)
                
            // Password Field
            SecureField("Password", text: $password)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .textContentType(.password)

            // Login Button
            AsyncButton("Log In") {
                try await handleLogin()
            } onError: { error in
                alertMessage = error.localizedDescription
                showingAlert = true
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding(.top, 20)
            
            // Forgot Password (could be implemented later)
            Button("Forgot Password?") {
                // Handle forgot password action
            }
            .padding(.top, 10)
            .foregroundColor(.blue)
        }
        .padding(.horizontal, 30)
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("Login"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .onDisappear {
            // Cancel any ongoing tasks
            loginTask?.cancel()
        }
    }
    
    private func handleLogin() async throws {
        guard !email.isEmpty && !password.isEmpty else {
            throw NSError(
                domain: "LoginError",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Please enter both email and password."]
            )
        }
        
        // Cancel any previous task
        loginTask?.cancel()
        
        // Using modern async/await API directly
        try await authService.signIn(email: email, password: password)
        
        // Authentication successful, show success message
        alertMessage = "Login successful!"
        showingAlert = true
    }
}
