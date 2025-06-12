//
//  CheckListTask.swift
//  ShiftFlow
//
//  Created by Kirill P on 17/03/2025.
//

import Foundation
import FirebaseFirestore      


struct CheckListTask: Identifiable, Codable {
    @DocumentID var id: String? 
    var title: String
    var description: String

    // Initializer: id is optional
    init(id: String? = UUID().uuidString,
         title: String,
         description: String = "") {
         self.id = id
         self.title = title
         self.description = description
    }}
