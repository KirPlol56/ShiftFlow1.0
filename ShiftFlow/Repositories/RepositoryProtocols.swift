//
//  RepositoryProtocols.swift
//  ShiftFlow
//
//  Created by Kirill P on 15/04/2025.
//

import Foundation


/// Base Repository protocol that all specific repository protocols should extend
protocol Repository {
    associatedtype Model
    associatedtype ID
    
    /// The entity type this repository manages
    var entityName: String { get }
}

/// Repository protocol for entities that can be read
protocol ReadableRepository: Repository {
    /// Fetch a single entity by ID
    func get(byId id: ID) async throws -> Model
    
    /// Fetch all entities (may be paginated or limited in concrete implementations)
    func getAll() async throws -> [Model]
}

/// Repository protocol for entities that can be created/written
protocol WritableRepository: Repository {
    /// Create a new entity
    func create(_ item: Model) async throws -> Model
    
    /// Update an existing entity
    func update(_ item: Model) async throws -> Model
    
    /// Delete an entity by ID
    func delete(id: ID) async throws
}

/// Combined protocol for entities that support both read and write operations
protocol CRUDRepository: ReadableRepository, WritableRepository {}

/// Protocol for repositories that support listening to real-time updates
protocol ListenableRepository: Repository {
    associatedtype ListenerRegistration
    
    /// Start listening for changes to a specific entity - mark as nonisolated
    nonisolated func listen(forId id: ID, completion: @escaping (Result<Model?, Error>) -> Void) -> ListenerRegistration
    
    /// Start listening for changes to a collection of entities - mark as nonisolated
    nonisolated func listenAll(completion: @escaping (Result<[Model], Error>) -> Void) -> ListenerRegistration
    
    /// Stop listening for changes - mark as nonisolated
    nonisolated func stopListening(_ registration: ListenerRegistration)
}


/// Protocol for repositories that support pagination
protocol PaginatedRepository: Repository {
    associatedtype PaginationToken
    
    /// Get a page of results
    func getPage(pageSize: Int, startAfter token: PaginationToken?) async throws -> (items: [Model], nextToken: PaginationToken?)
}

/// Protocol for repositories that support filtering and querying
protocol QueryableRepository: Repository {
    associatedtype QueryFilter
    
    /// Query entities based on a filter
    func query(filter: QueryFilter) async throws -> [Model]
}
