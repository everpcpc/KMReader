//
// StartupFailureView.swift
//
//

import SwiftUI

struct StartupFailureView: View {
  let details: String?
  let onRetry: () -> Void
  let onReset: () -> Void

  @State private var showResetConfirmation = false

  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        ContentUnavailableView {
          Label(
            String(
              localized: "startup.storageFailure.title",
              defaultValue: "Local data couldn't be opened"
            ),
            systemImage: "externaldrive.badge.exclamationmark"
          )
        } description: {
          VStack(spacing: 12) {
            Text(
              String(
                localized: "startup.storageFailure.message",
                defaultValue:
                  "KMReader couldn't open or upgrade its local data. This can happen when upgrading from a much older version, or when the local database is already corrupted. Try again once. If it still fails, reset local data, then sign in again."
              )
            )

            if let details, !details.isEmpty {
              #if os(tvOS)
                Text(verbatim: details)
                  .font(.caption.monospaced())
                  .foregroundStyle(.tertiary)
                  .frame(maxWidth: .infinity, alignment: .leading)
              #else
                DisclosureGroup(String(localized: "Details")) {
                  Text(verbatim: details)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelectionIfAvailable()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                }
              #endif
            }
          }
          .multilineTextAlignment(.center)
        } actions: {
          Button(String(localized: "Retry")) {
            onRetry()
          }
          .adaptiveButtonStyle(.borderedProminent)

          Button(
            String(
              localized: "startup.storageFailure.resetButton",
              defaultValue: "Reset Local Data"
            ),
            role: .destructive
          ) {
            showResetConfirmation = true
          }
          .adaptiveButtonStyle(.bordered)
        }
      }
      .frame(maxWidth: 520)
      .frame(maxWidth: .infinity)
      .padding(24)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .alert(
      String(
        localized: "startup.storageFailure.resetTitle",
        defaultValue: "Reset Local Data?"
      ),
      isPresented: $showResetConfirmation
    ) {
      Button(String(localized: "Cancel"), role: .cancel) {}
      Button(
        String(
          localized: "startup.storageFailure.resetConfirm",
          defaultValue: "Reset"
        ),
        role: .destructive
      ) {
        onReset()
      }
    } message: {
      Text(
        String(
          localized: "startup.storageFailure.resetMessage",
          defaultValue:
            "This removes all local KMReader data on this device, including saved servers, preferences, offline books, custom fonts, logs, and caches. Server data in Komga is not changed. KMReader will start fresh after the reset."
        )
      )
    }
  }
}

#Preview {
  StartupFailureView(
    details: "SwiftDataError.migrationFailed(code: 134110)",
    onRetry: {},
    onReset: {}
  )
}
