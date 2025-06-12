//
//  CachedAsyncImageView.swift
//  ShiftFlow
//
//  Created by Kirill P on 23/05/2025.
//


import SwiftUI

/// A SwiftUI view that loads and displays images asynchronously with caching
struct CachedAsyncImageView: View {
    // Input properties
    let url: URL?
    let contentMode: ContentMode
    
    // Optional placeholder view
    var placeholder: AnyView?
    
    // State
    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var loadError: Error?
    @State private var loadTask: Task<Void, Never>?
    
    /// Initialize with URL and content mode
    init(url: URL?, contentMode: ContentMode = .fill) {
        self.url = url
        self.contentMode = contentMode
        self.placeholder = AnyView(Color.gray.opacity(0.3))
    }
    
    /// Initialize with URL, content mode, and custom placeholder
    init<P: View>(url: URL?, contentMode: ContentMode = .fill, @ViewBuilder placeholder: () -> P) {
        self.url = url
        self.contentMode = contentMode
        self.placeholder = AnyView(placeholder())
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if isLoading {
                placeholder ?? AnyView(ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity))
            } else if loadError != nil {
                placeholder ?? AnyView(
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                )
            } else {
                placeholder ?? AnyView(Color.gray.opacity(0.3))
            }
        }
        .onAppear {
            loadImage()
        }
        .onDisappear {
            // Cancel the task when the view disappears
            loadTask?.cancel()
        }
        // Fix: Update deprecated onChange with new syntax
        .onChange(of: url) { _, newURL in
            // If URL changes, reload the image
            if newURL != url {
                loadImage()
            }
        }
    }
    
    /// Load image from URL or cache
    private func loadImage() {
        guard let url = url, image == nil, !isLoading, loadTask == nil else { return }
        
        // Cancel previous task if any
        loadTask?.cancel()
        
        isLoading = true
        loadError = nil
        
        loadTask = Task {
            do {
                let loadedImage = try await ImageCacheService.shared.loadImage(from: url)
                
                if !Task.isCancelled {
                    await MainActor.run {
                        image = loadedImage
                        isLoading = false
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        loadError = error
                        isLoading = false
                    }
                }
            }
            
            loadTask = nil
        }
    }
}
