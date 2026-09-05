//
// SettingsServerCardView.swift
//
//

import SwiftUI

/// Current-server summary shown at the top of the iPhone Settings page.
/// The whole card is a link to the server list, following the Apple ID card
/// idiom from iOS Settings: a colored server badge, the server name, and the
/// account/URL as secondary lines. Account roles live on the Account page.
struct SettingsServerCardView: View {
  @AppStorage("currentAccount") private var current: Current = .init()

  var body: some View {
    NavigationLink(value: NavDestination.settingsServers) {
      VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 12) {
          Image(systemName: "server.rack")
            .font(.title3)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(
              Color.accentColor,
              in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )

          VStack(alignment: .leading, spacing: 2) {
            Text(serverDisplayName)
              .font(.headline)
            if !current.username.isEmpty {
              Text(current.username)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
            }
            Text(current.serverURL.isEmpty ? current.serverDisplayName : current.serverURL)
              .font(.caption)
              .foregroundColor(.secondary)
              .lineLimit(1)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }

        ServerUpdateStatusView()
      }
      .contentShape(Rectangle())
    }
    .adaptiveButtonStyle(.plain)
  }

  private var serverDisplayName: String {
    if !current.serverDisplayName.isEmpty {
      return current.serverDisplayName
    }
    return String(localized: "Server")
  }
}
