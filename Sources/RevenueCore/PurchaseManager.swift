//
//  RevenueCoreError.swift
//  RevenueCore
//
//  Created by Apple M1 on 03/10/2025.
//

import Foundation
import StoreKit

// MARK: - Public Types

public enum ProductSortOption {
    case id
    case priceAscending
    case priceDescending
}

public enum PurchaseResult {
    case success(Transaction)
    case userCancelled
    case pending
    case failure(Error)
}

public enum PurchaseStatus {
    case notPurchased
    case purchased(Transaction)
    case expired(Transaction)
    case revoked(Transaction)
}

// MARK: - Delegate

public protocol PurchaseManagerDelegate: AnyObject {
    func purchaseManager(_ manager: PurchaseManager, didComplete transaction: Transaction)
    func purchaseManager(_ manager: PurchaseManager, didFailWith error: Error)
    func purchaseManagerDidCancel(_ manager: PurchaseManager)
    func purchaseManagerDidEnterPendingState(_ manager: PurchaseManager)
    func purchaseManager(_ manager: PurchaseManager, didRestore transactions: [Transaction])
    func purchaseManager(_ manager: PurchaseManager, didUpdateStatus status: PurchaseStatus, for productId: String)
}

public extension PurchaseManagerDelegate {
    func purchaseManager(_ manager: PurchaseManager, didComplete transaction: Transaction) {}
    func purchaseManager(_ manager: PurchaseManager, didFailWith error: Error) {}
    func purchaseManagerDidCancel(_ manager: PurchaseManager) {}
    func purchaseManagerDidEnterPendingState(_ manager: PurchaseManager) {}
    func purchaseManager(_ manager: PurchaseManager, didRestore transactions: [Transaction]) {}
    func purchaseManager(_ manager: PurchaseManager, didUpdateStatus status: PurchaseStatus, for productId: String) {}
}

// MARK: - PurchaseManager

/// # PurchaseManager
///
/// A lightweight StoreKit 2 manager (MainActor-isolated) for:
/// - Fetching products
/// - Sorting products
/// - Checking offers/trials
/// - Purchasing products
/// - Restoring purchases
/// - Checking purchase status
/// - Receiving events via delegate
@MainActor
public final class PurchaseManager {
    
    public static let shared = PurchaseManager()
    public weak var delegate: PurchaseManagerDelegate?
    
    private var transactionListenerTask: Task<Void, Never>?
    
    public init() {
        startListeningForTransactions()
    }
    
    deinit {
        transactionListenerTask?.cancel()
        transactionListenerTask = nil
//        stopListeningForTransactions()
    }
    
    // MARK: - Products
    
    public func fetchProducts(ids: [String]) async throws -> [Product] {
        return try await Product.products(for: ids)
    }
    
    public func fetchProductsSorted(ids: [String], by option: ProductSortOption) async throws -> [Product] {
        let products = try await fetchProducts(ids: ids)
        return sortProducts(products, by: option)
    }
    
    public func sortProducts(_ products: [Product], by option: ProductSortOption) -> [Product] {
        switch option {
        case .id:
            return products.sorted { $0.id.localizedCompare($1.id) == .orderedAscending }
        case .priceAscending:
            return products.sorted { $0.price < $1.price }
        case .priceDescending:
            return products.sorted { $0.price > $1.price }
        }
    }
    
    // MARK: - Offers / Trials
    
    public func hasIntroOfferOrTrial(for product: Product) -> Bool {
        if case .autoRenewable = product.type, let subscription = product.subscription {
            return subscription.introductoryOffer != nil
        }
        return false
    }
    
    public func localizedPrice(for product: Product) -> String {
        return product.displayPrice
    }
    
    // MARK: - Purchase
    
    public func purchase(product: Product) async -> PurchaseResult {
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    delegate?.purchaseManager(self, didComplete: transaction)
                    await finish(transaction: transaction)
                    return .success(transaction)
                    
                case .unverified(_, let error):
                    delegate?.purchaseManager(self, didFailWith: error)
                    return .failure(error)
                }
                
            case .pending:
                delegate?.purchaseManagerDidEnterPendingState(self)
                return .pending
                
            case .userCancelled:
                delegate?.purchaseManagerDidCancel(self)
                return .userCancelled
                
            @unknown default:
                let err = NSError(domain: "PurchaseManager", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: "Unknown purchase result"])
                delegate?.purchaseManager(self, didFailWith: err)
                return .failure(err)
            }
            
        } catch {
            delegate?.purchaseManager(self, didFailWith: error)
            return .failure(error)
        }
    }
    
    // MARK: - Restore
    
    public func restorePurchases() async -> [Transaction] {
        var restored: [Transaction] = []
        
        for await verification in Transaction.currentEntitlements {
            switch verification {
            case .verified(let transaction):
                restored.append(transaction)
            case .unverified(_, let error):
                delegate?.purchaseManager(self, didFailWith: error)
            }
        }
        
        if !restored.isEmpty {
            delegate?.purchaseManager(self, didRestore: restored)
        }
        
        return restored
    }
    
    // MARK: - Status Checking
    
    public func checkStatus(for productId: String) async -> PurchaseStatus {
        for await verification in Transaction.currentEntitlements {
            switch verification {
            case .verified(let transaction):
                guard transaction.productID == productId else { continue }
                
                if let expiration = transaction.expirationDate {
                    if expiration > Date() {
                        let status = PurchaseStatus.purchased(transaction)
                        delegate?.purchaseManager(self, didUpdateStatus: status, for: productId)
                        return status
                    } else {
                        let status = PurchaseStatus.expired(transaction)
                        delegate?.purchaseManager(self, didUpdateStatus: status, for: productId)
                        return status
                    }
                } else {
                    let status = PurchaseStatus.purchased(transaction)
                    delegate?.purchaseManager(self, didUpdateStatus: status, for: productId)
                    return status
                }
                
            case .unverified(_, let error):
                delegate?.purchaseManager(self, didFailWith: error)
            }
        }
        
        let status = PurchaseStatus.notPurchased
        delegate?.purchaseManager(self, didUpdateStatus: status, for: productId)
        return status
    }
    
    // MARK: - Transaction Listening
    
    private func startListeningForTransactions() {
        if transactionListenerTask != nil { return }
        
        // Bound to MainActor (no concurrency warning)
        transactionListenerTask = Task {
            for await verification in Transaction.updates {
                switch verification {
                case .verified(let transaction):
                    delegate?.purchaseManager(self, didComplete: transaction)
                    await finish(transaction: transaction)
                    
                case .unverified(_, let error):
                    delegate?.purchaseManager(self, didFailWith: error)
                }
            }
        }
    }
    
    private func stopListeningForTransactions() {
        transactionListenerTask?.cancel()
        transactionListenerTask = nil
    }
    
    private func finish(transaction: Transaction) async {
        do {
            try await transaction.finish()
        } catch {
            delegate?.purchaseManager(self, didFailWith: error)
        }
    }
}
