//
//  InfoRowView.swift
//  ShiftFlow
//
//  Created by Kirill P on 21/04/2025.
//

import SwiftUI


struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}
