//
//  User.swift
//  ShiftFlow
//
//  Created by Kirill P on 09/03/2025.
//

import Foundation
import FirebaseFirestore

struct User: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    let uid: String
    var email: String? // Changed from let to var
    var name: String // Changed from let to var
    var isManager: Bool // Changed from let to var
    var roleTitle: String // Changed from let to var
    var roleId: String // Changed from let to var
    var companyId: String? // Changed from let to var
    var companyName: String? // Changed from let to var
    let createdAt: Timestamp?

    func hash(into hasher: inout Hasher) {
        hasher.combine(uid)
    }
    
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.uid == rhs.uid
    }

    // Fixed initializer (changed Date? to Date)
    init(id: String? = nil,
         uid: String,
         email: String?,
         name: String,
         isManager: Bool,
         roleTitle: String,
         roleId: String,
         companyId: String?,
         companyName: String?,
         createdAt: Date) { // Changed from Date? to Date
        self.id = id ?? uid
        self.uid = uid
        self.email = email
        self.name = name
        self.isManager = isManager
        self.roleTitle = roleTitle
        self.roleId = roleId
        self.companyId = companyId
        self.companyName = companyName
        self.createdAt = Timestamp(date: createdAt) // No need for .map
    }
}
