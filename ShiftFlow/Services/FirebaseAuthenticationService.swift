//
//  FirebaseAuthenticationServiceWithRepo.swift
//  ShiftFlow
//
//  Created by Kirill P on 09/03/2025.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

/// Protocol defining authentication operations with async/await first approach
protocol AuthenticationServiceProtocol: ObservableObject {
    // MARK: - Published State
    
    var currentUser: User? { get }
    
    // MARK: - Primary Async API
    
    /// Register a new user and company
    func registerUser(email: String, password: String, name: String, companyName: String) async throws
    
    /// Sign in a user
    func signIn(email: String, password: String) async throws
    
    /// Register a team member
    func registerTeamMember(email: String, password: String, name: String, companyId: String, companyName: String, roleId: String, roleTitle: String, isManager: Bool) async throws
    
    /// Fetch team members for a company
    func fetchTeamMembers(companyId: String) async throws -> [User]
    
    /// Delete a team member
    func deleteTeamMember(userId: String) async throws
    
    /// Send invitation to join the company
    func sendInvitation(email: String, name: String, companyId: String, companyName: String, roleId: String, roleTitle: String, isManager: Bool) async throws
    
    /// Fetch a user by ID
    func fetchUser(byId userId: String) async throws -> User
    
    /// Sign out the current user
    func signOut() async throws
    
    // MARK: - Legacy Completion Handler API
    
    /// Register a new user and company
    func registerUser(email: String, password: String, name: String, companyName: String, completion: @escaping (Result<Void, ShiftFlowAuthenticationError>) -> Void)
    
    /// Sign in a user
    func signInUser(email: String, password: String, completion: @escaping (Result<Void, ShiftFlowAuthenticationError>) -> Void)
    
    /// Sign out the current user
    func signOutUser()
    
    /// Register a team member
    func registerTeamMember(email: String, password: String, name: String, companyId: String, companyName: String, roleId: String, roleTitle: String, isManager: Bool, completion: @escaping (Result<Void, ShiftFlowAuthenticationError>) -> Void)
    
    /// Fetch team members for a company
    func fetchTeamMembers(companyId: String, completion: @escaping (Result<[User], Error>) -> Void)
    
    /// Delete a team member
    func deleteTeamMember(userId: String, completion: @escaping (Result<Void, Error>) -> Void)
    
    /// Send invitation to join the company
    func sendInvitation(email: String, name: String, companyId: String, companyName: String, roleId: String, roleTitle: String, isManager: Bool, completion: @escaping (Result<Void, Error>) -> Void)
}

/// Implementation of AuthenticationService using Firebase and the repository pattern
class FirebaseAuthenticationServiceWithRepo: ObservableObject, AuthenticationServiceProtocol {
    // MARK: - Published State
    
    @Published var currentUser: User? = nil
    
    // MARK: - Private Properties
    
    private let db = Firestore.firestore()
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var isProcessingTeamMemberRegistration = false
    
    /// Repositories for data access
    private let userRepository: any UserRepository
    private let shiftRepository: any ShiftRepository
    
    // MARK: - Lifecycle
    
    /// Initialize with repositories
    init(repositoryProvider: RepositoryProvider = RepositoryFactory.shared) {
        self.userRepository = repositoryProvider.userRepository()
        self.shiftRepository = repositoryProvider.shiftRepository()
        
        // Set up auth state listener
        setupAuthStateListener()
    }
    
    deinit {
        if let authStateListener = authStateListener {
            Auth.auth().removeStateDidChangeListener(authStateListener)
        }
    }
    
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] (auth, user) in
            guard let self = self else { return }
            
            // Skip auth state changes during team member registration
            if self.isProcessingTeamMemberRegistration {
                print("Ignoring auth state change during team member registration")
                return
            }
            
            if let firebaseUser = user {
                print("Auth state changed: User logged in (\(firebaseUser.uid)). Fetching user data...")
                Task {
                    await self.fetchCurrentUser(userId: firebaseUser.uid)
                }
            } else {
                print("Auth state changed: User logged out.")
                Task { @MainActor in
                    self.currentUser = nil
                }
            }
        }
    }
    
    // MARK: - Primary Async API Implementation
    
    /// Register a new user and company
    /// - Parameters:
    ///   - email: User's email
    ///   - password: User's password
    ///   - name: User's name
    ///   - companyName: Company name
    func registerUser(email: String, password: String, name: String, companyName: String) async throws {
        do {
            // Validate inputs
            guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ShiftFlowAuthenticationError.invalidEmail
            }
            
            guard password.count >= 6 else {
                throw ShiftFlowAuthenticationError.invalidPassword
            }
            
            guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ServiceError.invalidOperation("Name is required")
            }
            
            guard !companyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ServiceError.invalidOperation("Company name is required")
            }
            
            // Create Auth user
            let authResult = try await Auth.auth().createUserAsync(withEmail: email, password: password)
            let userId = authResult.user.uid
            
            // Create company and user
            try await createInitialManagerAndCompany(
                userId: userId,
                email: email,
                name: name,
                companyName: companyName
            )
            
            // Create default shifts
            let companyId = UUID().uuidString
            try await createDefaultShifts(companyId: companyId, managerId: userId)
        } catch {
            throw mapFirebaseError(error)
        }
    }
    
    /// Sign in a user
    /// - Parameters:
    ///   - email: User's email
    ///   - password: User's password
    func signIn(email: String, password: String) async throws {
        do {
            guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ShiftFlowAuthenticationError.invalidEmail
            }
            
            guard !password.isEmpty else {
                throw ShiftFlowAuthenticationError.invalidPassword
            }
            
            try await Auth.auth().signInAsync(withEmail: email, password: password)
            // Auth state listener will handle fetching user data
        } catch {
            throw mapFirebaseError(error)
        }
    }
    
    /// Register a team member
    /// - Parameters:
    ///   - email: User's email
    ///   - password: User's password
    ///   - name: User's name
    ///   - companyId: Company ID
    ///   - companyName: Company name
    ///   - roleId: Role ID
    ///   - roleTitle: Role title
    ///   - isManager: Whether the user is a manager
    func registerTeamMember(email: String, password: String, name: String, companyId: String, companyName: String, roleId: String, roleTitle: String, isManager: Bool) async throws {
        // Validate inputs
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ShiftFlowAuthenticationError.invalidEmail
        }
        
        guard password.count >= 6 else {
            throw ShiftFlowAuthenticationError.invalidPassword
        }
        
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ServiceError.invalidOperation("Name is required")
        }
        
        guard !companyId.isEmpty else {
            throw ServiceError.invalidOperation("Company ID is required")
        }
        
        guard !companyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ServiceError.invalidOperation("Company name is required")
        }
        
        guard !roleId.isEmpty else {
            throw ServiceError.invalidOperation("Role ID is required")
        }
        
        guard !roleTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ServiceError.invalidOperation("Role title is required")
        }
        
        // Set flag to prevent auth state listener from responding
        self.isProcessingTeamMemberRegistration = true
        
        // Store current auth user before creating the new one
        let currentAuthUser = Auth.auth().currentUser
        
        do {
            // Create Auth user
            let authResult = try await Auth.auth().createUserAsync(withEmail: email, password: password)
            let newUserId = authResult.user.uid
            
            // Create the team member user
            let teamMemberUser = User(
                uid: newUserId,
                email: email,
                name: name,
                isManager: isManager,
                roleTitle: roleTitle,
                roleId: roleId,
                companyId: companyId,
                companyName: companyName,
                createdAt: Date()
            )
            
            // Create user using repository
            _ = try await userRepository.create(teamMemberUser)
            
            // Reset flag
            self.isProcessingTeamMemberRegistration = false
        } catch {
            self.isProcessingTeamMemberRegistration = false
            throw mapFirebaseError(error)
        }
    }
    
    /// Fetch team members for a company
    /// - Parameter companyId: Company ID
    /// - Returns: Array of User objects
    func fetchTeamMembers(companyId: String) async throws -> [User] {
        guard !companyId.isEmpty else {
            throw ShiftFlowRepositoryError.invalidData("Company ID is required")
        }
        
        return try await userRepository.getTeamMembers(companyId: companyId)
    }
    
    /// Delete a team member
    /// - Parameter userId: User ID to delete
    func deleteTeamMember(userId: String) async throws {
        guard !userId.isEmpty else {
            throw ShiftFlowRepositoryError.invalidData("User ID is required")
        }
        
        try await userRepository.delete(id: userId)
    }
    
    /// Send invitation to join the company
    /// - Parameters:
    ///   - email: User's email
    ///   - name: User's name
    ///   - companyId: Company ID
    ///   - companyName: Company name
    ///   - roleId: Role ID
    ///   - roleTitle: Role title
    ///   - isManager: Whether the user is a manager
    func sendInvitation(email: String, name: String, companyId: String, companyName: String, roleId: String, roleTitle: String, isManager: Bool) async throws {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ShiftFlowAuthenticationError.invalidEmail
        }
        
        guard !companyId.isEmpty, !companyName.isEmpty, !roleId.isEmpty, !roleTitle.isEmpty else {
            throw ServiceError.invalidOperation("Missing required fields for invitation")
        }
        
        let inviteData: [String: Any] = [
            "email": email.lowercased().trimmingCharacters(in: .whitespaces),
            "name": name.trimmingCharacters(in: .whitespaces),
            "companyId": companyId,
            "companyName": companyName,
            "roleId": roleId,
            "roleTitle": roleTitle,
            "isManager": isManager,
            "status": "pending",
            "createdAt": Timestamp(date: Date())
        ]
        
        try await db.collection("invitations").addDocument(data: inviteData)
    }
    
    /// Fetch a user by ID
    /// - Parameter userId: User ID
    /// - Returns: User object
    func fetchUser(byId userId: String) async throws -> User {
        return try await userRepository.get(byId: userId)
    }
    
    /// Sign out the current user
    func signOut() async throws {
        do {
            try Auth.auth().signOut()
            print("User successfully signed out")
            // Auth state listener will handle setting currentUser to nil
        } catch {
            print("Error signing out: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Legacy Completion Handler API Implementation
    
    func registerUser(email: String, password: String, name: String, companyName: String, completion: @escaping (Result<Void, ShiftFlowAuthenticationError>) -> Void) {
        Task {
            do {
                try await registerUser(email: email, password: password, name: name, companyName: companyName)
                await MainActor.run {
                    completion(.success(()))
                }
            } catch let error as ShiftFlowAuthenticationError {
                await MainActor.run {
                    completion(.failure(error))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(.unknownError(error)))
                }
            }
        }
    }
    
    func signInUser(email: String, password: String, completion: @escaping (Result<Void, ShiftFlowAuthenticationError>) -> Void) {
        Task {
            do {
                try await signIn(email: email, password: password)
                await MainActor.run {
                    completion(.success(()))
                }
            } catch let error as ShiftFlowAuthenticationError {
                await MainActor.run {
                    completion(.failure(error))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(.unknownError(error)))
                }
            }
        }
    }
    
    func signOutUser() {
        Task {
            do {
                try await signOut()
            } catch {
                print("Error signing out: \(error.localizedDescription)")
            }
        }
    }
    
    func registerTeamMember(email: String, password: String, name: String, companyId: String, companyName: String, roleId: String, roleTitle: String, isManager: Bool, completion: @escaping (Result<Void, ShiftFlowAuthenticationError>) -> Void) {
        Task {
            do {
                try await registerTeamMember(email: email, password: password, name: name, companyId: companyId, companyName: companyName, roleId: roleId, roleTitle: roleTitle, isManager: isManager)
                await MainActor.run {
                    completion(.success(()))
                }
            } catch let error as ShiftFlowAuthenticationError {
                await MainActor.run {
                    completion(.failure(error))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(.unknownError(error)))
                }
            }
        }
    }
    
    func fetchTeamMembers(companyId: String, completion: @escaping (Result<[User], Error>) -> Void) {
        Task {
            do {
                let members = try await fetchTeamMembers(companyId: companyId)
                await MainActor.run {
                    completion(.success(members))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func deleteTeamMember(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                try await deleteTeamMember(userId: userId)
                await MainActor.run {
                    completion(.success(()))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func sendInvitation(email: String, name: String, companyId: String, companyName: String, roleId: String, roleTitle: String, isManager: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                try await sendInvitation(email: email, name: name, companyId: companyId, companyName: companyName, roleId: roleId, roleTitle: roleTitle, isManager: isManager)
                await MainActor.run {
                    completion(.success(()))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Fetch current user data
    /// - Parameter userId: User ID
    private func fetchCurrentUser(userId: String) async {
        do {
            let user = try await userRepository.get(byId: userId)
            
            await MainActor.run { [weak self] in
                self?.currentUser = user
                print("Current user updated: \(user.name)")
            }
        } catch {
            print("Error fetching user \(userId): \(error.localizedDescription)")
            
            // Sign out if we couldn't find the user
            await MainActor.run { [weak self] in
                self?.signOutUser()
            }
        }
    }
    
    /// Create the initial manager and company
    /// - Parameters:
    ///   - userId: User ID
    ///   - email: User's email
    ///   - name: User's name
    ///   - companyName: Company name
    private func createInitialManagerAndCompany(
        userId: String,
        email: String,
        name: String,
        companyName: String
    ) async throws {
        let companyId = UUID().uuidString
        
        // Create the manager user
        let managerUser = User(
            uid: userId,
            email: email,
            name: name,
            isManager: true,
            roleTitle: "Manager",
            roleId: "std_manager",
            companyId: companyId,
            companyName: companyName,
            createdAt: Date()
        )
        
        // Create the company
        let companyData: [String: Any] = [
            "id": companyId,
            "name": companyName,
            "createdAt": Timestamp(date: Date()),
            "createdBy": userId
        ]
        
        // Create company in Firestore
        try await db.collection("companies").document(companyId).setData(companyData)
        
        // Create user in the repository
        _ = try await userRepository.create(managerUser)
    }
    
    /// Create default shifts for a new company
    /// - Parameters:
    ///   - companyId: Company ID
    ///   - managerId: Manager ID
    private func createDefaultShifts(companyId: String, managerId: String) async throws {
        let defaultStartTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
        let defaultEndTime = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()
        
        // Create shifts for each day of the week
        for day in Shift.DayOfWeek.allCases {
            let shift = Shift(
                dayOfWeek: day,
                startTime: defaultStartTime,
                endTime: defaultEndTime,
                assignedToUIDs: [],
                companyId: companyId,
                tasks: [],
                status: .scheduled,
                lastUpdatedBy: managerId,
                lastUpdatedAt: Date()
            )
            
            // Add the shift using the repository
            _ = try await shiftRepository.create(shift)
        }
    }
    
    // MARK: - Error Mapping
    
    /// Map Firebase errors to AuthenticationError
    /// - Parameter error: Original error
    /// - Returns: Mapped AuthenticationError
    private func mapFirebaseError(_ error: Error) -> ShiftFlowAuthenticationError {
        guard let errorCode = AuthErrorCode(rawValue: error._code) else {
            return .unknownError(error)
        }
        
        switch errorCode {
        case .invalidEmail:
            return .invalidEmail
        case .emailAlreadyInUse:
            return .emailAlreadyInUse
        case .weakPassword:
            return .invalidPassword
        case .userNotFound:
            return .userNotFound
        case .wrongPassword:
            return .wrongPassword
        default:
            return .unknownError(error)
        }
    }
}
