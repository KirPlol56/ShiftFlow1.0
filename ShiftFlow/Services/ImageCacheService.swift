//
//  ImageCacheService.swift
//  ShiftFlow
//
//  Created by Kirill P on 23/05/2025.
//

import Foundation
import UIKit
import SwiftUI

/// Protocol for image caching service
protocol ImageCacheServiceProtocol {
    /// Get an image from cache
    /// - Parameter url: The image URL
    /// - Returns: Cached UIImage if available
    func cachedImage(for url: URL) -> UIImage?
    
    /// Store an image in cache
    /// - Parameters:
    ///   - image: Image to cache
    ///   - url: The image URL as the cache key
    func cacheImage(_ image: UIImage, for url: URL)
    
    /// Asynchronously load an image with caching
    /// - Parameter url: Image URL
    /// - Returns: UIImage if successful
    func loadImage(from url: URL) async throws -> UIImage
    
    /// Clear all cached images
    func clearCache()
}

/// Singleton service for caching images
final class ImageCacheService: ImageCacheServiceProtocol {
    // Singleton instance
    static let shared = ImageCacheService()
    
    // NSCache for in-memory caching
    private let imageCache = NSCache<NSString, UIImage>()
    
    // Configure cache limits
    private init() {
        imageCache.countLimit = 100 // Max number of images
        imageCache.totalCostLimit = 50 * 1024 * 1024 // 50MB limit
    }
    
    /// Get cached image if available
    func cachedImage(for url: URL) -> UIImage? {
        return imageCache.object(forKey: url.absoluteString as NSString)
    }
    
    /// Cache an image
    func cacheImage(_ image: UIImage, for url: URL) {
        // Calculate approximate size in bytes (4 bytes per pixel for RGBA)
        let cost = Int(image.size.width * image.size.height * 4)
        imageCache.setObject(image, forKey: url.absoluteString as NSString, cost: cost)
    }
    
    /// Load an image from URL with caching
    func loadImage(from url: URL) async throws -> UIImage {
        // Check cache first
        if let cachedImage = cachedImage(for: url) {
            return cachedImage
        }
        
        // If not in cache, load from network
        let (data, _) = try await URLSession.shared.data(from: url)
        
        guard let image = UIImage(data: data) else {
            throw URLError(.cannotDecodeContentData)
        }
        
        // Cache the loaded image
        cacheImage(image, for: url)
        
        return image
    }
    
    /// Clear the entire cache
    func clearCache() {
        imageCache.removeAllObjects()
    }
}
