//
//  ShiftFlowAuthenticationError+Extensions.swift
//  ShiftFlowTests
//
//  Created by Kirill P on 18/06/2025.
//

import Foundation
@testable import ShiftFlow

extension ShiftFlowAuthenticationError: Equatable {
    public static func == (lhs: ShiftFlowAuthenticationError, rhs: ShiftFlowAuthenticationError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidEmail, .invalidEmail),
             (.invalidPassword, .invalidPassword),
             (.emailAlreadyInUse, .emailAlreadyInUse),
             (.userNotFound, .userNotFound),
             (.wrongPassword, .wrongPassword),
             (.notAuthenticated, .notAuthenticated),
             (.sessionExpired, .sessionExpired):
            return true
            
        case (.unknownError(let lhsError), .unknownError(let rhsError)):
            // Compare error descriptions for unknown errors
            return lhsError?.localizedDescription == rhsError?.localizedDescription
            
        default:
            return false
        }
    }
    
    // Helper method for tests to check error types
    static func isEqual(_ lhs: ShiftFlowAuthenticationError, _ rhs: ShiftFlowAuthenticationError) -> Bool {
        return lhs == rhs
    }
}
