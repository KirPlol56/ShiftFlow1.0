//
//  FirebaseAsyncStream.swift
//  ShiftFlow
//
//  Created by Kirill P on 21/04/2025.
//

import Foundation
@preconcurrency import FirebaseFirestore
import Combine

/// A helper class for creating AsyncSequence wrappers around Firebase listeners
class FirebaseAsyncStream {
    
    /// Creates an AsyncSequence for a single document
    /// - Parameters:
    ///   - reference: The DocumentReference to listen to
    /// - Returns: An AsyncThrowingStream that emits documents
    static func listen<T: Decodable>(to reference: DocumentReference) -> AsyncThrowingStream<T?, Error> {
        return AsyncThrowingStream { continuation in
            let listener = reference.addSnapshotListener { snapshot, error in
                if let error = error {
                    continuation.finish(throwing: error)
                    return
                }
                
                guard let snapshot = snapshot else {
                    continuation.yield(nil)
                    return
                }
                
                do {
                    if snapshot.exists {
                        let decodedObject = try snapshot.data(as: T.self)
                        continuation.yield(decodedObject)
                    } else {
                        continuation.yield(nil)
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            
            // Provide a cancellation handler that removes the listener
            continuation.onTermination = { @Sendable _ in
                listener.remove()
            }
        }
    }
    
    /// Creates an AsyncSequence for a collection query
    /// - Parameters:
    ///   - query: The Query to listen to
    /// - Returns: An AsyncThrowingStream that emits arrays of documents
    static func listen<T: Decodable>(to query: Query) -> AsyncThrowingStream<[T], Error> {
        return AsyncThrowingStream { continuation in
            let listener = query.addSnapshotListener { snapshot, error in
                if let error = error {
                    continuation.finish(throwing: error)
                    return
                }
                
                guard let snapshot = snapshot else {
                    continuation.yield([])
                    return
                }
                
                // Fix: Remove unnecessary do-catch block since there's no throwing operation
                let documents = snapshot.documents.compactMap { document -> T? in
                    try? document.data(as: T.self)
                }
                continuation.yield(documents)
            }
            
            // Provide a cancellation handler that removes the listener
            continuation.onTermination = { @Sendable _ in
                listener.remove()
            }
        }
    }
    
    /// Performs an async/await operation with a snapshot listener
    /// - Parameters:
    ///   - reference: The DocumentReference to listen to
    ///   - timeout: Optional timeout in seconds
    /// - Returns: The decoded document
    static func getDocument<T: Decodable>(from reference: DocumentReference, timeout: TimeInterval? = nil) async throws -> T? {
        try await withCheckedThrowingContinuation { continuation in
            let listenerHandle = reference.addSnapshotListener { snapshot, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let snapshot = snapshot else {
                    continuation.resume(returning: nil)
                    return
                }
                
                do {
                    if snapshot.exists {
                        let decodedObject = try snapshot.data(as: T.self)
                        continuation.resume(returning: decodedObject)
                    } else {
                        continuation.resume(returning: nil)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            
            // If a timeout is specified, handle it
            if let timeout = timeout {
                DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                    listenerHandle.remove()
                    continuation.resume(throwing: NSError(domain: "FirebaseAsyncStream", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation timed out"]))
                }
            }
        }
    }
    
    /// Performs an async/await operation with a query snapshot listener
    /// - Parameters:
    ///   - query: The Query to listen to
    ///   - timeout: Optional timeout in seconds
    /// - Returns: An array of decoded documents
    static func getDocuments<T: Decodable>(from query: Query, timeout: TimeInterval? = nil) async throws -> [T] {
        try await withCheckedThrowingContinuation { continuation in
            let listenerHandle = query.addSnapshotListener { snapshot, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let snapshot = snapshot else {
                    continuation.resume(returning: [])
                    return
                }
                
                let documents = snapshot.documents.compactMap { document -> T? in
                    try? document.data(as: T.self)
                }
                
                continuation.resume(returning: documents)
            }
            
            // If a timeout is specified, handle it
            if let timeout = timeout {
                DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                    listenerHandle.remove()
                    continuation.resume(throwing: NSError(domain: "FirebaseAsyncStream", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation timed out"]))
                }
            }
        }
    }
}

// MARK: - Repository Extensions for Async Streams

extension ListenableRepository {
    /// Create an AsyncSequence for a single entity
    /// - Parameter id: The ID of the entity to listen to
    /// - Returns: An AsyncStream that emits the entity
    func listenAsync(forId id: ID) -> AsyncThrowingStream<Model?, Error> where Model: Decodable {
        return AsyncThrowingStream { continuation in
            let listener = self.listen(forId: id) { result in
                switch result {
                case .success(let entity):
                    continuation.yield(entity)
                case .failure(let error):
                    continuation.finish(throwing: error)
                }
            }
            
            // Provide a cancellation handler
            // Fix: Remove unnecessary forced cast
            continuation.onTermination = { @Sendable _ in
                self.stopListening(listener)
            }
        }
    }
    
    /// Create an AsyncSequence for all entities
    /// - Returns: An AsyncStream that emits arrays of entities
    func listenAllAsync() -> AsyncThrowingStream<[Model], Error> where Model: Decodable {
        return AsyncThrowingStream { continuation in
            let listener = self.listenAll { result in
                switch result {
                case .success(let entities):
                    continuation.yield(entities)
                case .failure(let error):
                    continuation.finish(throwing: error)
                }
            }
            
            // Provide a cancellation handler
            // Fix: Remove unnecessary forced cast
            continuation.onTermination = { @Sendable _ in
                self.stopListening(listener)
            }
        }
    }
}
