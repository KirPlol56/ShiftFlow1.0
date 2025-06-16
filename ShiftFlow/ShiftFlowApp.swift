//
//  ShiftFlowApp.swift
//  ShiftFlow
//
//  Created by Kirill P on 09/03/2025.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        print("Firebase configured successfully")
        return true
    }
}

@main
struct ShiftFlowApp: App {
    // Register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // Initialize DI container
    @StateObject private var diContainer = DIContainer.shared
    
    var body: some Scene {
        WindowGroup {
            ContentViewWithRepo()
                .withDIContainer(diContainer)
        }
    }
}
