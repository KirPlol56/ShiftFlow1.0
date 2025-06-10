//
//  Shift.swift
//  ShiftFlow
//
//  Created by Kirill P on 13/03/2025.
//

import Foundation
import FirebaseFirestore
import SwiftUI

struct Shift: Identifiable, Codable {
    @DocumentID var id: String? // Firestore populates this when fetched
    var dayOfWeek: DayOfWeek    // Enum conforms to Codable
    var startTime: Timestamp    // Use Timestamp
    var endTime: Timestamp      // Use Timestamp
    var assignedToUIDs: [String]
    var companyId: String
    var tasks: [ShiftTask]      // Assumes ShiftTask is Codable
    var status: ShiftStatus     // Enum conforms to Codable
    var lastUpdatedBy: String
    var lastUpdatedAt: Timestamp // Use Timestamp
    var assignedRoleIds: [String]?

    // DayOfWeek enum (already Codable)
    enum DayOfWeek: String, CaseIterable, Codable {
        case monday = "monday", tuesday = "tuesday", wednesday = "wednesday",
             thursday = "thursday", friday = "friday", saturday = "saturday", sunday = "sunday"

        var displayName: String { rawValue.capitalized }

        func dateForCurrentWeek() -> Date {
                    let calendar = Calendar.current // Use current calendar
                    let today = calendar.startOfDay(for: Date())
                    // Use standard .weekday (1=Sun, 2=Mon, ..., 7=Sat)
                    let weekdayOrdinal = calendar.component(.weekday, from: today)
                    // Adjust to: 1 = Mon, 7 = Sun
                    let todayWeekday = weekdayOrdinal == 1 ? 7 : weekdayOrdinal - 1

                    let targetWeekday: Int
                    switch self {
                    case .monday: targetWeekday = 1
                    case .tuesday: targetWeekday = 2
                    case .wednesday: targetWeekday = 3
                    case .thursday: targetWeekday = 4
                    case .friday: targetWeekday = 5
                    case .saturday: targetWeekday = 6
                    case .sunday: targetWeekday = 7
                    }

                    let daysToAdd = targetWeekday - todayWeekday
                    return calendar.date(byAdding: .day, value: daysToAdd, to: today) ?? today
                }
    }

    // ShiftStatus enum (already Codable)
    enum ShiftStatus: String, Codable {
        case scheduled = "scheduled"
        case inProgress = "inProgress"
        case completed = "completed"
        case cancelled = "cancelled"

        // Keep display helpers
        var displayValue: String { rawValue.capitalized }
        var color: Color {
            switch self {
            case .scheduled: return .blue
            case .inProgress: return .orange
            case .completed: return .green
            case .cancelled: return .red
            }
        }
    }

    // Initializer accepting Dates, converting to Timestamps
    init(id: String? = nil, // ID is optional
         dayOfWeek: DayOfWeek,
         startTime: Date,          // Accept Date
         endTime: Date,            // Accept Date
         assignedToUIDs: [String] = [],
         companyId: String,
         tasks: [ShiftTask] = [],
         status: ShiftStatus = .scheduled,
         lastUpdatedBy: String,
         lastUpdatedAt: Date = Date(), // Accept Date
         assignedRoleIds: [String]? = nil) {
        self.id = id // Store if provided
        self.dayOfWeek = dayOfWeek
        // Convert Dates to Timestamps
        self.startTime = Timestamp(date: startTime)
        self.endTime = Timestamp(date: endTime)
        self.assignedToUIDs = assignedToUIDs
        self.companyId = companyId
        self.tasks = tasks
        self.status = status
        self.lastUpdatedBy = lastUpdatedBy
        self.lastUpdatedAt = Timestamp(date: lastUpdatedAt)
        self.assignedRoleIds = assignedRoleIds ?? [] // Ensure non-nil
    }
}
