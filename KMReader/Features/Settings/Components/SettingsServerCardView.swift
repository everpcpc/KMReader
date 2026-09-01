//
// SettingsServerCardView.swift
//
//

import Flow
import SwiftUI

/// Current-server summary shown at the top of the iPhone Settings page.
/// The whole card is a link to the server list, following the Apple ID card
/// idiom from iOS Settings: server name on the first line, the account's
/// Komga roles as badges, then account, URL, and status as secondary lines.
struct SettingsServerCardView: View {
  @AppStorage("currentAccount") private var current: Current = .init()

  var body: some View {
    NavigationLink(value: NavDestination.settingsServers) {
      VStack(alignment: .leading, spacing: 8) {
        Text(serverDisplayName)
          .font(.title3)
          .fontWeight(.semibold)

        if !current.userRoles.isEmpty {
          HFlow(spacing: 6) {
            ForEach(current.userRoles, id: \.self) { role in
              RoleBadge(role: role)
            }
          }
        } else if !current.userId.isEmpty {
          Text(String(localized: "user.role.none"))
            .font(.footnote)
            .foregroundColor(.secondary)
            .italic()
        }

        if let accountDisplayValue {
          iconRow(icon: "person", text: accountDisplayValue, font: .subheadline)
        }

        iconRow(
          icon: "globe",
          text: current.serverURL.isEmpty ? current.serverDisplayName : current.serverURL,
          font: .footnote
        )

        ServerUpdateStatusView()
          .foregroundColor(.secondary)
          .font(.footnote)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
    }
  }

  private var serverDisplayName: String {
    if !current.serverDisplayName.isEmpty {
      return current.serverDisplayName
    }
    return String(localized: "Server")
  }

  /// Small fixed-width icon column so the text aligns with the other
  /// secondary lines instead of Label's wide list icon gutter.
  private func iconRow(icon: String, text: String, font: Font) -> some View {
    HStack(spacing: 8) {
      Image(systemName: icon)
        .font(.footnote)
        .frame(width: 16, alignment: .center)
      Text(text)
        .font(font)
        .lineLimit(1)
    }
    .foregroundColor(.secondary)
  }

  private var accountDisplayValue: String? {
    if !current.username.isEmpty {
      return current.username
    }
    return nil
  }
}
