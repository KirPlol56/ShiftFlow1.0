//
//  PaginatedListView.swift
//  ShiftFlow
//
//  Created by Kirill P on 08/05/2025.
//

import SwiftUI

struct PaginatedListView<Item: Identifiable, Content: View, EmptyContent: View>: View {
    // Data
    let items: [Item]
    let hasMorePages: Bool
    let isLoading: Bool
    
    // Actions
    let loadMore: () async -> Void
    let refresh: () async -> Void
    
    // View builders
    @ViewBuilder let content: (Item) -> Content
    @ViewBuilder let emptyContent: () -> EmptyContent
    
    // State
    @State private var loadMoreTask: Task<Void, Never>? = nil
    
    var body: some View {
        List {
            // Show empty state if there are no items and we're not loading initially
            if items.isEmpty && !isLoading {
                emptyContent()
                    .listRowBackground(Color.clear)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                // Show items
                ForEach(items) { item in
                    content(item)
                        .onAppear {
                            // Check if this is one of the last 3 items
                            if let index = items.firstIndex(where: { $0.id == item.id }),
                               index >= items.count - 3,
                               hasMorePages && !isLoading {
                                
                                // Cancel previous task if it exists
                                loadMoreTask?.cancel()
                                
                                // Start a new task to load more
                                loadMoreTask = Task {
                                    await loadMore()
                                }
                            }
                        }
                }
                
                // Show a loading indicator at bottom when loading more
                if isLoading && !items.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView("Loading more...")
                        Spacer()
                    }
                    .padding()
                    .listRowSeparator(.hidden)
                }
                
                // Show end of list message when no more pages
                if !hasMorePages && !items.isEmpty {
                    Text("No more shifts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .refreshable {
            // Pull to refresh functionality
            await refresh()
        }
        .overlay {
            if isLoading && items.isEmpty {
                ProgressView("Loading...")
                    .background(Color(.systemBackground).opacity(0.8))
                    .cornerRadius(8)
                    .padding()
            }
        }
        .onDisappear {
            // Clean up when view disappears
            loadMoreTask?.cancel()
            loadMoreTask = nil
        }
    }
}
