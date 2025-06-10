//
//  UserState.swift
//  ShiftFlow
//
//  Created by Kirill P on 11/03/2025.
//

import Foundation
import SwiftUI
import Combine

class UserState: ObservableObject {
    @Published var currentUser: User? = nil
}
