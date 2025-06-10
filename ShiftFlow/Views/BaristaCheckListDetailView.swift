//
//  BaristaCheckListDetailView.swift
//  ShiftFlow
//
//  Created by Kirill P on 21/04/2025.
//

import SwiftUI

struct BaristaCheckListDetailView: View {
    let checkList: CheckList
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var roleService: RoleServiceWithRepo
    
    // Track completions by title rather than ID since we're displaying unique titles
    @State private var completedTaskTitles = Set<String>()
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(Array(Set(checkList.tasks.map { $0.title })), id: \.self) { uniqueTitle in
                        if let task = checkList.tasks.first(where: { $0.title == uniqueTitle }) {
                            Button {
                                toggleTaskByTitle(uniqueTitle)
                            } label: {
                                TaskCheckRow(
                                    task: task,
                                    isCompleted: completedTaskTitles.contains(uniqueTitle)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } footer: {
                    Text(completionStatusText)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 10)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle(checkList.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
    
    private var completionStatusText: String {
        if checkList.tasks.isEmpty { return "No tasks in this check list." }
        
        // Get unique tasks by title for correct count
        let uniqueTasks = Set(checkList.tasks.map { $0.title })
        let totalTasks = uniqueTasks.count
        let completedCount = completedTaskTitles.count
        
        if completedCount == totalTasks {
            return "All \(totalTasks) tasks completed!"
        } else {
            return "\(completedCount) of \(totalTasks) tasks completed."
        }
    }
    
    // Toggle completion state using title instead of ID
    private func toggleTaskByTitle(_ title: String) {
        if completedTaskTitles.contains(title) {
            completedTaskTitles.remove(title)
        } else {
            completedTaskTitles.insert(title)
        }
    }
}

