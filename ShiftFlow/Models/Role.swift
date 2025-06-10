//
//  Role.swift
//  ShiftFlow
//
//  Created by Kirill P on 07/04/2025.
//

import Foundation
import FirebaseFirestore

// Represents a specific role within a company.
struct Role: Identifiable, Codable, Hashable {
    @DocumentID var id: String? // Firestore will automatically populate this with the document ID when fetched
    let title: String         // Display name of the role (e.g., "Barista", "Head Chef")
    let companyId: String     // ID of the company this role belongs to
    let createdBy: String     // UID of the user who created the role
    let createdAt: Timestamp  // When the role was created

    // Initializer - id is no longer set here, Firestore handles it via addDocument
    init(title: String,
         companyId: String,
         createdBy: String,
         createdAt: Timestamp = Timestamp(date: Date())) {
        // self.id = id // Removed - Firestore assigns this
        self.title = title
        self.companyId = companyId
        self.createdBy = createdBy
        self.createdAt = createdAt
    }

    // Check if this role's title matches one of the standard predefined roles
    var isStandardRole: Bool {
        StandardRoles.allCases.map { $0.rawValue }.contains(title)
    }

    // MARK: - Codable & Hashable

    // Basic Hashable conformance - Use title and companyId for hashing before ID is assigned
    func hash(into hasher: inout Hasher) {
        // If id exists, use it for hashing, otherwise use other unique properties
        if let id = id {
            hasher.combine(id)
        } else {
            hasher.combine(title)
            hasher.combine(companyId)
            hasher.combine(createdAt) // Add timestamp to differentiate roles with same title/company created at slightly different times before saving
        }
    }

    // Basic Equatable conformance
    static func == (lhs: Role, rhs: Role) -> Bool {
        // If both have IDs, compare them. Otherwise, compare content.
        if let lhsId = lhs.id, let rhsId = rhs.id {
            return lhsId == rhsId
        }
        // Fallback comparison if IDs aren't available yet (e.g., before saving)
        return lhs.title == rhs.title &&
               lhs.companyId == rhs.companyId &&
               lhs.createdAt == rhs.createdAt
    }

    // MARK: - Firestore Serialization/Deserialization (Handled by Codable)
    // No need for manual toDictionary or fromDictionary when using Codable and FirebaseFirestoreSwift

}

// Enum defining the standard, predefined roles available across companies.
// (StandardRoles enum remains the same as before)
enum StandardRoles: String, CaseIterable, Identifiable, Codable {
    case barista = "Barista"
    case baker = "Baker"
    case chefBarista = "Chef Barista"
    case chefBaker = "Chef Baker"
    case cleaner = "Cleaner"
    case executiveChef = "Executive Chef"
    case sousChef = "Sous Chef/Second Chef"
    case headWaiter = "Head Waiter"
    case waiter = "Waiter/Waitress/Server"
    case host = "Host/Hostess"
    case banquetManager = "Banquet Manager"
    case kitchenManager = "Kitchen Manager"
    case kitchenStaff = "Kitchen Staff"
    case housekeepingDirector = "Housekeeping Director"
    case housekeeping = "Housekeeping"
    case roomAttendant = "Room Attendant"
    case engineer = "Engineer"
    case security = "Security"
    case facilityOperations = "Facility Operations"
    case manager = "Manager" // Example title

    var id: String { self.rawValue }
}

extension Role {
    // Helper method to create a Role object from a StandardRoles enum value
    static func fromStandardRole(_ standardRole: StandardRoles, companyId: String) -> Role {
        // Create a consistent ID format for standard roles
        let roleId = "std_\(standardRole.rawValue.lowercased().replacingOccurrences(of: " ", with: "_"))"
        var role = Role(
            title: standardRole.rawValue,
            companyId: companyId,
            createdBy: "system",
            createdAt: Timestamp(date: Date())
        )
        role.id = roleId
        return role
    }
    
    // Helper to check if this is a standard role by ID format
    var isStandardRoleById: Bool {
        return id?.hasPrefix("std_") ?? false
    }
    
    // Get the actual role title if this is a standard role ID
    var standardRoleTitleFromId: String? {
        guard let id = id, id.hasPrefix("std_") else { return nil }
        return String(id.dropFirst(4))
    }
}
