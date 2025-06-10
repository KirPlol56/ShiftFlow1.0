//
//  CheckListModel.swift
//  ShiftFlow
//
//  Created by Kirill P on 14/03/2025.
//
// CheckList.swift

import Foundation
import FirebaseFirestore       // Core SDK
import SwiftUI

struct CheckList: Identifiable, Codable {
    @DocumentID var id: String? // Firestore populates this
    var title: String
    var frequency: Frequency // Frequency enum needs to be Codable
    var shiftSection: ShiftSection // ShiftSection enum needs to be Codable
    var tasks: [CheckListTask] // Assumes CheckListTask is Codable
    var companyId: String
    var createdByUID: String
    var createdAt: Timestamp // Use Timestamp
    var assignedRoleIds: [String]?

    // Frequency enum with Codable conformance
    enum Frequency: Codable {
        case everyShift
        case specificDay(dayOfWeek: Shift.DayOfWeek) // Shift.DayOfWeek is Codable
        case specificDate(date: Timestamp)          // Use Timestamp

        // --- Manual Codable Implementation ---
        private enum CodingKeys: String, CodingKey { case type, dayOfWeek, date }
        private enum FrequencyType: String, Codable { case everyShift, specificDay, specificDate }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(FrequencyType.self, forKey: .type)
            switch type {
            case .everyShift:   self = .everyShift
            case .specificDay:
                let day = try container.decode(Shift.DayOfWeek.self, forKey: .dayOfWeek)
                self = .specificDay(dayOfWeek: day)
            case .specificDate:
                let date = try container.decode(Timestamp.self, forKey: .date)
                self = .specificDate(date: date)
            }
        }
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .everyShift:
                try container.encode(FrequencyType.everyShift, forKey: .type)
            case .specificDay(let day):
                try container.encode(FrequencyType.specificDay, forKey: .type)
                try container.encode(day, forKey: .dayOfWeek)
            case .specificDate(let date):
                try container.encode(FrequencyType.specificDate, forKey: .type)
                try container.encode(date, forKey: .date)
            }
        }
        // --- End Codable Implementation ---

        // --- Display name and other helpers ---
        var displayName: String {
            switch self {
            case .everyShift: return "Every Shift"
            case .specificDay(let day): return "Every \(day.displayName)"
            case .specificDate(let ts):
                let formatter = DateFormatter(); formatter.dateFormat = "MMM d, yyyy"
                return formatter.string(from: ts.dateValue())
            }
        }
        func isActiveToday() -> Bool {
                    let today = Date()
                    let calendar = Calendar.current
                    switch self {
                    case .everyShift: return true
                    case .specificDay(let dayOfWeek):
                        // Use standard .weekday (1=Sun, 2=Mon, ..., 7=Sat)
                        let weekdayOrdinal = calendar.component(.weekday, from: today)
                        // Adjust to: 1 = Mon, 7 = Sun
                        let todayWeekday = weekdayOrdinal == 1 ? 7 : weekdayOrdinal - 1

                        // Map DayOfWeek enum to target weekday number (1-7)
                        let targetWeekday: Int
                        switch dayOfWeek {
                            case .monday: targetWeekday = 1; case .tuesday: targetWeekday = 2; case .wednesday: targetWeekday = 3;
                            case .thursday: targetWeekday = 4; case .friday: targetWeekday = 5; case .saturday: targetWeekday = 6; case .sunday: targetWeekday = 7;
                        }
                        return todayWeekday == targetWeekday // Compare adjusted weekdays
                    case .specificDate(let timestamp):
                        return calendar.isDate(today, inSameDayAs: timestamp.dateValue())
                    }
            }
    }

    // ShiftSection enum (already Codable via RawRepresentable)
    enum ShiftSection: String, CaseIterable, Codable {
        case opening = "opening", during = "during", closing = "closing"
        var displayName: String { rawValue.capitalized }
        func isCurrentSection(shift: Shift) -> Bool { /* ... logic using shift Timestamps ... */ return false } // Add logic later if needed
    }

    // Initializer accepting Date, converting to Timestamp
    init(id: String? = nil, // ID is optional
         title: String,
         frequency: Frequency,
         shiftSection: ShiftSection = .during,
         tasks: [CheckListTask] = [],
         companyId: String,
         createdByUID: String,
         createdAt: Date = Date(),     // Accept Date
         assignedRoleIds: [String]? = nil) {
        self.id = id // Store if provided
        self.title = title
        self.frequency = frequency
        self.shiftSection = shiftSection
        self.tasks = tasks
        self.companyId = companyId
        self.createdByUID = createdByUID
        self.createdAt = Timestamp(date: createdAt) // Convert to Timestamp
        self.assignedRoleIds = assignedRoleIds ?? []
    }
}
