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
  private(set) var isLoadingProducts = false
  private(set) var isRestoring = false
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
  private static let restoreTimeoutSeconds: Double = 20

  private init() {
    updateListenerTask = listenForTransactions()
    Task {
      await loadProducts()
      await updatePurchasedProducts()
    }
  }

  func loadProducts() async {
    isLoadingProducts = true
    errorMessage = nil

    do {
      products = try await Product.products(for: [
        Self.monthlyProductID,
        Self.yearlyProductID,
      ])
    } catch {
      errorMessage = error.localizedDescription
    }

    isLoadingProducts = false
  }

  func purchase(_ product: Product) async throws -> Transaction? {
    try await withThrowingTaskGroup(of: Product.PurchaseResult.self) { group in
      group.addTask {
        try await product.purchase()
      }

      group.addTask {
        try await Task.sleep(for: .seconds(30))
        throw StoreError.purchaseTimeout
      }

      let result = try await group.next()
      group.cancelAll()

      guard let result else { return nil }

      switch result {
      case .success(let verification):
        let transaction = try checkVerified(verification)
        await updatePurchasedProducts()
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
  }

  func restorePurchases() async {
    isRestoring = true
    errorMessage = nil
    do {
      try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
          try await AppStore.sync()
        }
        group.addTask {
          try await Task.sleep(for: .seconds(Self.restoreTimeoutSeconds))
          throw StoreError.restoreTimeout
        }

        _ = try await group.next()
        group.cancelAll()
      }
      await updatePurchasedProducts()
    } catch {
      errorMessage = error.localizedDescription
    }
    isRestoring = false
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
  case restoreTimeout

  var errorDescription: String? {
    switch self {
    case .verificationFailed:
      return String(localized: "Transaction verification failed")
    case .purchaseTimeout:
      return String(localized: "Purchase request timed out. Please try again.")
    case .restoreTimeout:
      return String(localized: "Restore request timed out. Please try again.")
    }
  }
}
