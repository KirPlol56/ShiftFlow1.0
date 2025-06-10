//
//  TaskCompletionView.swift
//  ShiftFlow
//
//  Created by Kirill P on 23/05/2025.
//

import SwiftUI
import PhotosUI

struct TaskCompletionView: View {
    let task: ShiftTask
    let shiftId: String
    @EnvironmentObject var shiftService: ShiftServiceWithRepo
    @EnvironmentObject var userState: UserState
    
    @Environment(\.presentationMode) var presentationMode
    
    @State private var isUploading = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var uploadTask: Task<Void, Never>?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Task Info
                VStack(alignment: .leading, spacing: 10) {
                    Text(task.title)
                        .font(.headline)
                    
                    Text(task.description ?? "No description")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                // Photo selection
                VStack(spacing: 12) {
                    Text("Add Photo (Optional)")
                        .font(.headline)
                    
                    if let selectedImageData = selectedImageData,
                       let uiImage = UIImage(data: selectedImageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 200)
                            .cornerRadius(10)
                            .overlay(
                                Button(action: {
                                    self.selectedImageData = nil
                                    self.selectedItem = nil
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title)
                                        .foregroundColor(.white)
                                        .background(Color.black.opacity(0.5))
                                        .clipShape(Circle())
                                }
                                .padding(8),
                                alignment: .topTrailing
                            )
                    } else {
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            VStack {
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundColor(.blue)
                                Text("Select a Photo")
                                    .font(.callout)
                                    .foregroundColor(.blue)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 150)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Complete Button
                Button(action: {
                    completeTask()
                }) {
                    if isUploading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("Mark as Complete")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(isUploading)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Complete Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onChange(of: selectedItem) { newItem in
                if let newItem = newItem {
                    loadTransferable(from: newItem)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onDisappear {
                // Cancel any ongoing operations when view disappears
                uploadTask?.cancel()
            }
        }
    }
    
    private func loadTransferable(from item: PhotosPickerItem) {
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw URLError(.badServerResponse)
                }
                
                if !Task.isCancelled {
                    await MainActor.run {
                        selectedImageData = data
                    }
                }
            } catch {
                print("Error loading image: \(error)")
                if !Task.isCancelled {
                    await MainActor.run {
                        errorMessage = "Failed to load the selected image: \(error.localizedDescription)"
                        showError = true
                    }
                }
            }
        }
    }
    
    private func completeTask() {
        guard let currentUserId = userState.currentUser?.uid else {
            errorMessage = "User information not found. Please try again."
            showError = true
            return
        }
        
        // Cancel existing task if any
        uploadTask?.cancel()
        
        isUploading = true
        
        uploadTask = Task {
            do {
                var photoURL: String?
                
                // If we have image data, upload it first
                if let imageData = selectedImageData {
                    photoURL = try await uploadImage(imageData)
                }
                
                // Now mark the task as completed with the photo URL
                _ = try await shiftService.markTaskCompleted(
                    in: shiftId,
                    taskId: task.id ?? "",
                    completedBy: currentUserId,
                    photoURL: photoURL
                )
                
                if !Task.isCancelled {
                    await MainActor.run {
                        isUploading = false
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        isUploading = false
                        errorMessage = "Failed to complete task: \(error.localizedDescription)"
                        showError = true
                    }
                }
            }
        }
    }
    
    // Simulate uploading an image to storage
    // In a real app, you would use Firebase Storage or another service
    private func uploadImage(_ data: Data) async throws -> String {
        // Simulate network delay
        try await Task.sleep(for: .seconds(1))
        
        // In a real implementation, this would upload to Firebase Storage
        // For now, we'll just return a mock URL
        return "https://example.com/task-photos/\(UUID().uuidString).jpg"
    }
}
