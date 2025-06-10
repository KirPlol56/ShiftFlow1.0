//
//  AppError.swift
//  ShiftFlow
//
//  Created by Kirill P on 22/04/2025.
//

import Foundation
import SwiftUI

/// Base error protocol for application-wide error handling
protocol AppError: Error, Identifiable {
    var id: String { get }
    var errorTitle: String { get }
    var errorDescription: String? { get }
    var recoverySuggestion: String? { get }
}

// Default implementation for AppError
extension AppError {
    // Default id implementation using type and description
    var id: String {
        return "\(String(describing: self))"
    }
    
    // Default title if not specified
    var errorTitle: String {
        return "Error"
    }
    
    // Default empty recovery suggestion
    var recoverySuggestion: String? {
        return nil
    }
}

// Common repository errors
enum ShiftFlowRepositoryError: AppError, Equatable {
    case documentNotFound
    case decodingFailed
    case encodingFailed
    case networkError(Error)
    case permissionDenied
    case invalidData(String)
    case operationFailed(String)
    case unexpectedError(Error?)
    
    // Error title based on error type
    var errorTitle: String {
        switch self {
        case .documentNotFound:
            return "Not Found"
        case .decodingFailed:
            return "Data Error"
        case .encodingFailed:
            return "Encoding Error"
        case .networkError:
            return "Network Error"
        case .permissionDenied:
            return "Access Denied"
        case .invalidData:
            return "Invalid Data"
        case .operationFailed:
            return "Operation Failed"
        case .unexpectedError:
            return "Unexpected Error"
        }
    }
    
    // Detailed error description
    var errorDescription: String? {
        switch self {
        case .documentNotFound:
            return "The requested document was not found."
        case .decodingFailed:
            return "Failed to process the data received from the server."
        case .encodingFailed:
            return "Failed to encode the data for the server."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .permissionDenied:
            return "You don't have permission to perform this operation."
        case .invalidData(let details):
            return details.isEmpty ? "The provided data is invalid." : details
        case .operationFailed(let reason):
            return reason.isEmpty ? "The operation failed." : reason
        case .unexpectedError(let error):
            return "An unexpected error occurred: \(error?.localizedDescription ?? "Unknown error")"
        }
    }
    
    // Recovery suggestion when applicable
    var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "Please check your internet connection and try again."
        case .permissionDenied:
            return "Please contact your manager if you need access."
        case .documentNotFound:
            return "The item may have been deleted or moved."
        default:
            return nil
        }
    }
    
    // Make ShiftFlowRepositoryError Equatable
    static func == (lhs: ShiftFlowRepositoryError, rhs: ShiftFlowRepositoryError) -> Bool {
        switch (lhs, rhs) {
        case (.documentNotFound, .documentNotFound),
             (.decodingFailed, .decodingFailed),
             (.encodingFailed, .encodingFailed),
             (.permissionDenied, .permissionDenied):
            return true
            
        case (.invalidData(let lhsDetails), .invalidData(let rhsDetails)):
            return lhsDetails == rhsDetails
            
        case (.operationFailed(let lhsReason), .operationFailed(let rhsReason)):
            return lhsReason == rhsReason
            
        case (.networkError(let lhsError), .networkError(let rhsError)):
            // For errors containing other errors, compare by description
            return lhsError.localizedDescription == rhsError.localizedDescription
            
        case (.unexpectedError(let lhsError?), .unexpectedError(let rhsError?)):
            // Both errors are non-nil, compare by description
            return lhsError.localizedDescription == rhsError.localizedDescription
            
        case (.unexpectedError(nil), .unexpectedError(nil)):
            // Both errors are nil
            return true
            
        default:
            return false
        }
    }
}

// Authentication specific errors
enum ShiftFlowAuthenticationError: AppError {
    case invalidEmail
    case invalidPassword
    case emailAlreadyInUse
    case userNotFound
    case wrongPassword
    case notAuthenticated
    case sessionExpired
    case unknownError(Error?)
    
    // Error title based on authentication error type
    var errorTitle: String {
        switch self {
        case .invalidEmail, .invalidPassword:
            return "Invalid Input"
        case .emailAlreadyInUse:
            return "Account Exists"
        case .userNotFound, .wrongPassword:
            return "Login Failed"
        case .notAuthenticated, .sessionExpired:
            return "Authentication Required"
        case .unknownError:
            return "Authentication Error"
        }
    }
    
    // Detailed error description
    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address."
        case .invalidPassword:
            return "Password must be at least 6 characters long."
        case .emailAlreadyInUse:
            return "This email is already registered."
        case .userNotFound:
            return "User not found. Please check your email."
        case .wrongPassword:
            return "Incorrect password. Please try again."
        case .notAuthenticated:
            return "You need to log in to perform this action."
        case .sessionExpired:
            return "Your session has expired. Please log in again."
        case .unknownError(let error):
            return "Authentication error: \(error?.localizedDescription ?? "Unknown error")"
        }
    }
    
    // Recovery suggestion when applicable
    var recoverySuggestion: String? {
        switch self {
        case .invalidEmail:
            return "Make sure your email includes an @ symbol and a domain."
        case .invalidPassword:
            return "Your password should be at least 6 characters long."
        case .emailAlreadyInUse:
            return "Try logging in instead, or use a different email address."
        case .userNotFound:
            return "Make sure you've registered before trying to log in."
        case .wrongPassword:
            return "Double-check your password and try again."
        case .notAuthenticated, .sessionExpired:
            return "Please log in to continue."
        default:
            return nil
        }
    }
}

// Service-specific errors
enum ServiceError: AppError {
    case missingId(String)
    case invalidOperation(String)
    case dataConflict(String)
    case resourceLimit(String)
    case dependencyFailed(String)
    
    // Error title based on service error type
    var errorTitle: String {
        switch self {
        case .missingId:
            return "Missing ID"
        case .invalidOperation:
            return "Invalid Operation"
        case .dataConflict:
            return "Data Conflict"
        case .resourceLimit:
            return "Resource Limit"
        case .dependencyFailed:
            return "Dependency Error"
        }
    }
    
    // Detailed error description
    var errorDescription: String? {
        switch self {
        case .missingId(let entity):
            return "\(entity) ID is required."
        case .invalidOperation(let details):
            return details
        case .dataConflict(let details):
            return details
        case .resourceLimit(let details):
            return details
        case .dependencyFailed(let details):
            return details
        }
    }
}

// UI/View-specific errors
enum UIError: AppError {
    case inputValidation(String)
    case missingSelection(String)
    case uploadFailed(String)
    case downloadFailed(String)
    
    // Error title based on UI error type
    var errorTitle: String {
        switch self {
        case .inputValidation:
            return "Invalid Input"
        case .missingSelection:
            return "Selection Required"
        case .uploadFailed:
            return "Upload Failed"
        case .downloadFailed:
            return "Download Failed"
        }
    }
    
    // Detailed error description
    var errorDescription: String? {
        switch self {
        case .inputValidation(let details):
            return details
        case .missingSelection(let what):
            return "Please select a \(what)."
        case .uploadFailed(let details):
            return "Failed to upload: \(details)"
        case .downloadFailed(let details):
            return "Failed to download: \(details)"
        }
    }
    
    // Recovery suggestion when applicable
    var recoverySuggestion: String? {
        switch self {
        case .uploadFailed, .downloadFailed:
            return "Check your internet connection and try again."
        default:
            return nil
        }
    }
}

// MARK: - SwiftUI Error Handling Extensions

extension View {
    /// Add an error alert to a view
    /// - Parameters:
    ///   - isPresented: Binding to control alert visibility
    ///   - error: The error to display
    ///   - onDismiss: Optional action to perform when the alert is dismissed
    /// - Returns: A view with an error alert
    func errorAlert(
        isPresented: Binding<Bool>,
        error: (any AppError)?,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        self.alert(
            error?.errorTitle ?? "Error",
            isPresented: isPresented,
            actions: {
                Button("OK", action: {
                    onDismiss?()
                })
            },
            message: {
                if let error = error {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(error.errorDescription ?? "An unknown error occurred")
                        
                        if let suggestion = error.recoverySuggestion {
                            Text(suggestion)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        )
    }
    
    /// Add an error alert to a view with a binding to the error
    /// - Parameters:
    ///   - isPresented: Binding to control alert visibility
    ///   - error: Binding to the error
    ///   - onDismiss: Optional action to perform when the alert is dismissed
    /// - Returns: A view with an error alert
    func errorAlert(
        isPresented: Binding<Bool>,
        error: Binding<(any AppError)?>,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        self.alert(
            error.wrappedValue?.errorTitle ?? "Error",
            isPresented: isPresented,
            actions: {
                Button("OK", action: {
                    onDismiss?()
                })
            },
            message: {
                if let currentError = error.wrappedValue {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(currentError.errorDescription ?? "An unknown error occurred")
                        
                        if let suggestion = currentError.recoverySuggestion {
                            Text(suggestion)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        )
    }
}

// MARK: - Error Conversion Extensions

extension Error {
    /// Convert any Error to an AppError
    func asAppError() -> any AppError {
        // If it's already an AppError, return it
        if let appError = self as? any AppError {
            return appError
        }
        
        // Specific error type conversions
        if let urlError = self as? URLError {
            return ShiftFlowRepositoryError.networkError(urlError)
        } else if self is DecodingError {
            return ShiftFlowRepositoryError.decodingFailed
        } else if self is EncodingError {
            return ShiftFlowRepositoryError.encodingFailed
        } else if let nsError = self as NSError? {
            // Map Firebase errors or other NSErrors
            return mapNSError(nsError)
        }
        
        // Generic fallback
        return ShiftFlowRepositoryError.operationFailed("An unexpected error occurred: \(localizedDescription)")
    }
}

/// Maps NSError to appropriate AppError types
func mapNSError(_ error: NSError) -> any AppError {
    // Handle Firebase Auth errors
    if error.domain == "FIRAuthErrorDomain" {
        return mapFirebaseAuthError(error)
    }
    
    // Handle Firestore errors
    if error.domain == "FIRFirestoreErrorDomain" {
        return mapFirestoreError(error)
    }
    
    // Handle network errors
    if error.domain == NSURLErrorDomain {
        return ShiftFlowRepositoryError.networkError(error)
    }
    
    // Default case
    return ShiftFlowRepositoryError.operationFailed(error.localizedDescription)
}

/// Maps Firebase Auth NSError to AuthenticationError
func mapFirebaseAuthError(_ error: NSError) -> any AppError {
    switch error.code {
    case 17004: // Invalid email
        return ShiftFlowAuthenticationError.invalidEmail
    case 17005, 17026: // User not found
        return ShiftFlowAuthenticationError.userNotFound
    case 17009: // Wrong password
        return ShiftFlowAuthenticationError.wrongPassword
    case 17007: // Email already in use
        return ShiftFlowAuthenticationError.emailAlreadyInUse
    case 17008: // Invalid password (weak password)
        return ShiftFlowAuthenticationError.invalidPassword
    default:
        return ShiftFlowAuthenticationError.unknownError(error)
    }
}

/// Maps Firestore NSError to RepositoryError
func mapFirestoreError(_ error: NSError) -> any AppError {
    switch error.code {
    case 7: // Permission denied
        return ShiftFlowRepositoryError.permissionDenied
    case 5: // Document not found
        return ShiftFlowRepositoryError.documentNotFound
    case 3: // Invalid argument
        return ShiftFlowRepositoryError.invalidData("Invalid data provided to Firestore")
    default:
        return ShiftFlowRepositoryError.operationFailed("Firestore error: \(error.localizedDescription)")
    }
}
