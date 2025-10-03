//
//  RevenueCoreError.swift
//  RevenueCore
//
//  Created by Apple M1 on 03/10/2025.
//


import Foundation
import StoreKit

/// Errors thrown by RevenueCore
public enum RevenueCoreError: Error {
    case unknown
    case storeKitError(Error)
}

/// Simplified purchase result (expand for your needs)
public struct PurchaseResult {
    public let success: Bool
    public let transactionID: String?
}

/// High-level public Purchase manager (skeleton)
public final class PurchaseManager {

    /// Shared singleton for simple usage
    nonisolated(unsafe) public static let shared = PurchaseManager()

    public init() {}

    /// Fetch StoreKit products by identifiers
    /// - Parameter ids: product identifiers
    /// - Returns: array of StoreKit.Product
    public func fetchProducts(ids: [String]) async throws -> [Product] {
        return try await Product.products(for: ids)
    }

    /// Purchase a product (skeleton)
    public func purchase(_ product: Product) async throws -> PurchaseResult {
        // TODO: implement StoreKit 2 purchase flow (await product.purchase(), handle transaction)
        throw RevenueCoreError.unknown
    }

    /// Restore purchases (skeleton)
    public func restorePurchases() async throws {
        // TODO: implement restoration if needed
    }
}
