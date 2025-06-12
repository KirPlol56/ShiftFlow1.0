//
//  PaginatedRepositoryProtocol.swift
//  ShiftFlow
//
//  Created by Kirill P on 08/05/2025.
//

import Foundation
import FirebaseFirestore

/// Protocol for repositories that support pagination with Firestore
protocol PaginatedRepositoryProtocol {
    associatedtype Model
    associatedtype QueryFilter
    
    /// Fetch a page of data based on the filter criteria
    /// - Parameters:
    ///   - filter: The query filter to apply
    ///   - pageSize: Number of items per page
    ///   - lastDocument: Optional last document from previous page (for cursor-based pagination)
    /// - Returns: Tuple containing items and the last document for next page
    func queryPaginated(filter: QueryFilter, pageSize: Int, lastDocument: DocumentSnapshot?) async throws -> (items: [Model], lastDocument: DocumentSnapshot?)
}
