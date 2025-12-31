//
//  SubscriptionView.swift
//  KMReader
//
//  Buy me a coffee ☕
//

import StoreKit
import SwiftUI

struct SubscriptionView: View {
  @State private var isPurchasing = false
  @State private var showError = false
  @State private var errorMessage = ""
  @State private var coffeeOffset: CGFloat = 0

  var body: some View {
    SheetView(title: "☕️", size: .large) {
      ScrollView {
        VStack(spacing: 24) {
          if StoreManager.shared.hasActiveSubscription {
            subscribedSection
          } else {
            headerSection

            if StoreManager.shared.isLoading {
              VStack(spacing: 12) {
                ProgressView()
                Text(String(localized: "Brewing..."))
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
              .padding(.vertical, 40)
            } else if StoreManager.shared.products.isEmpty {
              emptyProductsSection
            } else {
              productsSection
            }

            restoreButton

            legalLinksSection
          }
        }
        .padding()
      }
      .alert(String(localized: "Oops!"), isPresented: $showError) {
        Button(String(localized: "OK"), role: .cancel) {}
      } message: {
        Text(errorMessage)
      }
    }
  }

  private var headerSection: some View {
    VStack(spacing: 16) {
      Text("☕️")
        .font(.system(size: 80))
        .offset(y: coffeeOffset)
        .onAppear {
          withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            coffeeOffset = -8
          }
        }

      Text(String(localized: "Buy Me a Coffee"))
        .font(.title2)
        .fontWeight(.bold)

      Text(String(localized: "If you enjoy using this app, consider buying me a coffee!"))
        .font(.subheadline)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal)
    }
    .padding(.top, 20)
  }

  private var subscribedSection: some View {
    VStack(spacing: 20) {
      VStack(spacing: 12) {
        Text("🎉")
          .font(.system(size: 64))

        Text(String(localized: "You're awesome!"))
          .font(.title3)
          .fontWeight(.bold)

        Text(String(localized: "Thanks for the coffee! ☕️"))
          .font(.subheadline)
          .foregroundColor(.secondary)
      }
      .padding(.vertical, 32)
      .frame(maxWidth: .infinity)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(Color.secondary.opacity(0.1))
          .overlay(
            RoundedRectangle(cornerRadius: 16)
              .stroke(Color.orange.opacity(0.3), lineWidth: 2)
          )
      )

      #if os(iOS)
        Button {
          Task {
            guard let scene = windowScene else { return }
            try? await AppStore.showManageSubscriptions(in: scene)
          }
        } label: {
          Text(String(localized: "Manage Subscription"))
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
      #endif
    }
  }

  #if os(iOS)
    private var windowScene: UIWindowScene? {
      UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first
    }
  #endif

  private var emptyProductsSection: some View {
    VStack(spacing: 12) {
      Text("😅")
        .font(.system(size: 48))

      Text(String(localized: "Coffee machine is broken..."))
        .font(.headline)

      if let error = StoreManager.shared.errorMessage {
        Text(error)
          .font(.caption)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
      }

      Button {
        Task {
          await StoreManager.shared.loadProducts()
        }
      } label: {
        Label(String(localized: "Try Again"), systemImage: "arrow.clockwise")
      }
      .adaptiveButtonStyle(.bordered)
      .tint(.orange)
      .padding(.top, 8)
    }
    .padding(.vertical, 40)
    .frame(maxWidth: .infinity)
    .background(Color.secondary.opacity(0.1))
    .cornerRadius(16)
  }

  private var productsSection: some View {
    VStack(spacing: 12) {
      if let monthly = StoreManager.shared.monthlyProduct {
        coffeeButton(for: monthly, emoji: "☕️", label: String(localized: "A Cup / Month"))
      }

      if let yearly = StoreManager.shared.yearlyProduct {
        coffeeButton(for: yearly, emoji: "🫖", label: String(localized: "A Pot / Year"))
      }
    }
  }

  private func coffeeButton(for product: Product, emoji: String, label: String) -> some View {
    Button {
      Task {
        await purchase(product)
      }
    } label: {
      HStack(spacing: 16) {
        Text(emoji)
          .font(.system(size: 36))

        Text(label)
          .font(.headline)
          .foregroundColor(.primary)

        Spacer()

        if isPurchasing {
          ProgressView()
        } else {
          Text(product.displayPrice)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.orange)
        }
      }
      .padding()
      .frame(maxWidth: .infinity)
      .background(Color.secondary.opacity(0.1))
      .cornerRadius(16)
    }
    .adaptiveButtonStyle(.plain)
    .disabled(isPurchasing)
  }

  private var restoreButton: some View {
    Button {
      Task {
        await StoreManager.shared.restorePurchases()
      }
    } label: {
      Text(String(localized: "Restore Purchases"))
        .font(.caption)
        .foregroundColor(.secondary)
    }
    .disabled(StoreManager.shared.isLoading)
    .padding(.top, 16)
  }

  private var legalLinksSection: some View {
    VStack(spacing: 8) {
      HStack(spacing: 16) {
        Link(
          destination: URL(
            string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
        ) {
          Text(String(localized: "Terms of Use"))
            .font(.caption)
            .foregroundColor(.secondary)
        }
        Text("·")
          .font(.caption)
          .foregroundColor(.secondary)
        Link(destination: URL(string: "https://kmreader.everpcpc.com/privacy/")!) {
          Text(String(localized: "Privacy Policy"))
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
    }
    .padding(.top, 8)
  }

  private func purchase(_ product: Product) async {
    isPurchasing = true
    defer { isPurchasing = false }

    do {
      _ = try await StoreManager.shared.purchase(product)
    } catch {
      errorMessage = error.localizedDescription
      showError = true
    }
  }
}

#Preview {
  SubscriptionView()
}
