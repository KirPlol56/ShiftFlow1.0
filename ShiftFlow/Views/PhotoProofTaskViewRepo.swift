//
//  PhotoProofTaskViewRepo.swift
//  ShiftFlow
//
//  Created by Kirill P on 27/03/2025.
//

import SwiftUI
import AVFoundation
import FirebaseStorage
import FirebaseCore

@MainActor
struct PhotoProofTaskViewRepo: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var shiftService: ShiftServiceWithRepo
    @EnvironmentObject var userState: UserState
    
    let task: ShiftTask
    let shiftId: String
    
    @State private var image: UIImage?
    @State private var isUploading = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var uploadProgress: Double = 0.0
    @State private var showingCameraSelection = false
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    
    // Task management with TaskManager
    @StateObject private var taskManager = TaskManager()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Task Information
                    TaskInfoSection(task: task)
                    
                    // Photo Section
                    VStack(spacing: 15) {
                        if let image = image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(12)
                                .padding(.horizontal)
                        } else {
                            VStack(spacing: 10) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                
                                Text("Take a photo to complete this task")
                                    .font(.headline)
                                    .multilineTextAlignment(.center)
                                
                                Text("This task requires photo proof of completion")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        
                        Button(action: { showingCameraSelection = true }) {
                            HStack {
                                Image(systemName: "camera")
                                Text(image == nil ? "Take Photo" : "Change Photo")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        .actionSheet(isPresented: $showingCameraSelection) {
                            ActionSheet(
                                title: Text("Select Photo Source"),
                                message: Text("Choose where to get your photo from"),
                                buttons: [
                                    .default(Text("Camera")) {
                                        // Use TaskManager for camera permission check
                                        taskManager.startTask(id: "cameraPermission") {
                                            await checkCameraPermission()
                                        }
                                    },
                                    .default(Text("Photo Library")) {
                                        showingPhotoLibrary = true
                                    },
                                    .cancel()
                                ]
                            )
                        }
                    }
                    
                    // Complete Button
                    if image != nil {
                        ManagedAsyncButton(
                            "Complete Task",
                            taskManager: taskManager,
                            taskId: "uploadPhoto",
                            action: {
                                try await uploadPhotoAndComplete()
                            },
                            onError: { error in
                                errorMessage = error.localizedDescription
                                showError = true
                            }
                        )
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .overlay(
                            Group {
                                if isUploading {
                                    VStack {
                                        ProgressView(value: uploadProgress, total: 1.0)
                                            .progressViewStyle(LinearProgressViewStyle())
                                            .padding(.horizontal)
                                        
                                        Text("Uploading... \(Int(uploadProgress * 100))%")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        )
                        .disabled(isUploading)
                    }
                }
                .padding()
            }
            .navigationTitle("Photo Proof Task")
            .navigationBarItems(trailing: Button("Close") {
                // Cancel any ongoing tasks through TaskManager
                taskManager.cancelAllTasks()
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $showingCamera) {
                // Uses camera explicitly
                CameraImagePicker(image: $image, sourceType: .camera)
            }
            .sheet(isPresented: $showingPhotoLibrary) {
                // Uses photo library
                CameraImagePicker(image: $image, sourceType: .photoLibrary)
            }
            .alert(isPresented: $showError) {
                Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
            }
        }
        .onDisappear {
            // Clean up through TaskManager
            taskManager.cancelAllTasks()
        }
    }
    
    // MARK: - Async Methods
    
    private func checkCameraPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            // Already authorized, show camera
            showingCamera = true
            
        case .notDetermined:
            // Request permission asynchronously
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            
            // Check if task was cancelled
            if Task.isCancelled { return }
            
            // Only update UI if task wasn't cancelled
            if granted {
                showingCamera = true
            } else {
                errorMessage = "Please enable camera access in Settings to take photos"
                showError = true
            }
            
        case .denied, .restricted:
            // Only update UI if task wasn't cancelled
            if !Task.isCancelled {
                errorMessage = "Please enable camera access in Settings to take photos"
                showError = true
            }
            
        @unknown default:
            // Only update UI if task wasn't cancelled
            if !Task.isCancelled {
                errorMessage = "Unknown camera permission status"
                showError = true
            }
        }
    }
    
    private func uploadPhotoAndComplete() async throws {
        guard let image = image, let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "PhotoUpload", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not prepare photo for upload"])
        }
        
        guard let userId = userState.currentUser?.uid else {
            throw NSError(domain: "PhotoUpload", code: 0, userInfo: [NSLocalizedDescriptionKey: "User information not found"])
        }
        
        isUploading = true
        uploadProgress = 0.1
        
        // Create a unique filename
        let filename = "task_proof_\(String(describing: task.id))_\(UUID().uuidString).jpg"
        let storageRef = Storage.storage().reference().child("task_proofs/\(filename)")
        
        // Upload the image with progress monitoring
        let downloadURL = try await uploadImage(imageData: imageData, storageRef: storageRef)
        
        // Mark the task as complete using the download URL
        try await shiftService.markTaskCompleted(
            in: shiftId,
            taskId: task.id ?? "",
            completedBy: userId,
            photoURL: downloadURL.absoluteString
        )
        
        isUploading = false
        presentationMode.wrappedValue.dismiss()
    }
    
    // Helper function to upload image with progress monitoring
    private func uploadImage(imageData: Data, storageRef: StorageReference) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            // Upload the image
            let uploadTask = storageRef.putData(imageData, metadata: nil) { metadata, error in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                // Get download URL
                storageRef.downloadURL { url, error in
                    if Task.isCancelled {
                        continuation.resume(throwing: CancellationError())
                        return
                    }
                    
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let downloadURL = url else {
                        continuation.resume(throwing: NSError(
                            domain: "PhotoUpload",
                            code: 0,
                            userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"]
                        ))
                        return
                    }
                    
                    continuation.resume(returning: downloadURL)
                }
            }
            
            // Monitor progress
            uploadTask.observe(.progress) { snapshot in
                if let progress = snapshot.progress {
                    let progressValue = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                    Task { @MainActor in
                        self.uploadProgress = progressValue
                    }
                }
            }
        }
    }
}

// Helper components
struct TaskInfoSection: View {
    let task: ShiftTask
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(task.title)
                .font(.title2)
                .fontWeight(.bold)
            
            if !task.description.isEmpty {
                Text(task.description)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Priority:")
                Text(task.priority.displayValue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(task.priority.color.opacity(0.2))
                    .foregroundColor(task.priority.color)
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// Improved ImagePicker with explicit source type
struct CameraImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    var sourceType: UIImagePickerController.SourceType
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        
        // Use the specified source type if available
        if UIImagePickerController.isSourceTypeAvailable(sourceType) {
            picker.sourceType = sourceType
        } else if sourceType == .camera && !UIImagePickerController.isSourceTypeAvailable(.camera) {
            // Fallback to photo library if camera requested but not available
            picker.sourceType = .photoLibrary
        }
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraImagePicker
        
        init(_ parent: CameraImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
