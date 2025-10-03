# RevenueCore

RevenueCore — A Swift Package that simplifies in-app purchases and subscriptions using StoreKit 2.

## ✨ Features
- Async/await friendly StoreKit 2 wrappers
- Easy product fetching, purchasing, and restoring
- Clean and Swifty API design

## 📦 Installation

Add RevenueCore to your project using Swift Package Manager.

**Xcode:**
1. Go to `File > Add Packages...`
2. Enter the URL:
https://github.com/hamza061/RevenueCore.git
3. Select version `Up to Next Major` from `1.0.0`.

**Package.swift:**
```swift
dependencies: [
 .package(url: "https://github.com/hamza061/RevenueCore.git", from: "1.0.0")
]



import RevenueCore

let manager = PurchaseManager.shared

Task {
    do {
        let products = try await manager.fetchProducts(ids: ["pro_plan"])
        if let product = products.first {
            let result = try await manager.purchase(product)
            print("Purchase result: \(result)")
        }
    } catch {
        print("Purchase failed: \(error)")
    }
}
