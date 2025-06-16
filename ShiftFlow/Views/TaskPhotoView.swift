//
//  TaskPhotoView.swift
//  ShiftFlow
//
//  Created by Kirill P on 23/05/2025.
//




import SwiftUI

struct TaskPhotoView: View {
    let photoURL: String?
    let tappable: Bool
    @State private var showFullScreen = false
    
    init(photoURL: String?, tappable: Bool = true) {
        self.photoURL = photoURL
        self.tappable = tappable
    }
    
    var body: some View {
        ZStack {
            CachedAsyncImageView(url: URL(string: photoURL ?? "")) {
                VStack {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    
                    Text("No Image")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.gray.opacity(0.1))
            }
            .frame(maxHeight: 200)
            .cornerRadius(10)
            .clipped()
            
            // Photo indicator
            if tappable && photoURL != nil {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("Tap to view")
                            .font(.caption)
                            .padding(6)
                            .background(Color.black.opacity(0.6))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                            .padding(8)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if tappable && photoURL != nil {
                showFullScreen = true
            }
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            FullScreenImageView(url: URL(string: photoURL ?? ""))
        }
    }
}

struct FullScreenImageView: View {
    @Environment(\.presentationMode) var presentationMode
    let url: URL?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .edgesIgnoringSafeArea(.all)
                
                CachedAsyncImageView(url: url, contentMode: .fit)
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                scale *= delta
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                                // Limit scale range
                                if scale < 1.0 {
                                    withAnimation { scale = 1.0 }
                                } else if scale > 5.0 {
                                    withAnimation { scale = 5.0 }
                                }
                            }
                    )
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(item: url ?? URL(string: "https://example.com")!) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
}

struct TaskPhotoView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            TaskPhotoView(photoURL: "https://example.com/photo.jpg")
                .frame(width: 300, height: 200)
            
            TaskPhotoView(photoURL: nil)
                .frame(width: 300, height: 200)
        }
        .padding()
    }
}
