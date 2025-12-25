//
//  StoreManager.swift
//  KMReader
//
//  Created for subscription management
//

import StoreKit

@MainActor
@Observable
final class StoreManager {
  static let shared = StoreManager()

  // Product IDs from App Store Connect
  static let monthlyProductID = "com.everpcpc.Komga.coffee.monthly"
  static let yearlyProductID = "com.everpcpc.Komga.coffee.yearly"

  private(set) var products: [Product] = []
  private(set) var purchasedProductIDs: Set<String> = []
  private(set) var isLoading = false
  private(set) var errorMessage: String?

  var hasActiveSubscription: Bool {
    !purchasedProductIDs.isEmpty
  }

  var monthlyProduct: Product? {
    products.first { $0.id == Self.monthlyProductID }
  }

  var yearlyProduct: Product? {
    products.first { $0.id == Self.yearlyProductID }
  }

  private var updateListenerTask: Task<Void, Error>?

  private init() {
    updateListenerTask = listenForTransactions()
    Task {
      await loadProducts()
      await updatePurchasedProducts()
    }
  }

  func loadProducts() async {
    isLoading = true
    errorMessage = nil

    do {
      products = try await Product.products(for: [
        Self.monthlyProductID,
        Self.yearlyProductID,
      ])
    } catch {
      errorMessage = error.localizedDescription
    }

    isLoading = false
  }

  func purchase(_ product: Product) async throws -> Transaction? {
    try await withThrowingTaskGroup(of: Transaction?.self) { group in
      group.addTask { @MainActor in
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
          let transaction = try self.checkVerified(verification)
          await self.updatePurchasedProducts()
          await transaction.finish()
          return transaction

        case .userCancelled:
          return nil

        case .pending:
          return nil

        @unknown default:
          return nil
        }
      }

      group.addTask {
        try await Task.sleep(for: .seconds(30))
        throw StoreError.purchaseTimeout
      }

      let result = try await group.next()
      group.cancelAll()
      return result ?? nil
    }
  }

  func restorePurchases() async {
    isLoading = true
    do {
      try await AppStore.sync()
      await updatePurchasedProducts()
    } catch {
      errorMessage = error.localizedDescription
    }
    isLoading = false
  }

  private func updatePurchasedProducts() async {
    var purchasedIDs: Set<String> = []

    for await result in Transaction.currentEntitlements {
      if case .verified(let transaction) = result {
        if transaction.revocationDate == nil {
          purchasedIDs.insert(transaction.productID)
        }
      }
    }

    purchasedProductIDs = purchasedIDs
  }

  private func listenForTransactions() -> Task<Void, Error> {
    Task.detached {
      for await result in Transaction.updates {
        if case .verified(let transaction) = result {
          await self.updatePurchasedProducts()
          await transaction.finish()
        }
      }
    }
  }

  private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
    switch result {
    case .unverified:
      throw StoreError.verificationFailed
    case .verified(let safe):
      return safe
    }
  }
}

enum StoreError: LocalizedError {
  case verificationFailed
  case purchaseTimeout

  var errorDescription: String? {
    switch self {
    case .verificationFailed:
      return String(localized: "Transaction verification failed")
    case .purchaseTimeout:
      return String(localized: "Purchase request timed out. Please try again.")
    }
  }
}
