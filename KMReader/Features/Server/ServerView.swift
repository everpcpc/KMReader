//
//  ServerView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Flow
import SwiftUI

struct ServerView: View {
  @Environment(AuthViewModel.self) private var authViewModel
  @AppStorage("currentAccount") private var current: Current = .init()
  @AppStorage("taskQueueStatus") private var taskQueueStatus: TaskQueueSSEDto = TaskQueueSSEDto()
  @State private var showingUpdatePassword = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        serverSummaryCard
        managementSection
        accountSection
      }
      .padding(.horizontal)
      .padding(.vertical, 12)
    }
    .inlineNavigationBarTitle(String(localized: "tab.server"))
  }

  private var serverSummaryCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 8) {
            Text(serverDisplayName)
              .font(.title2)
              .fontWeight(.semibold)

            if let roleLabel {
              Text(roleLabel)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.15), in: Capsule())
                .foregroundColor(Color.accentColor)
            }
          }
        }

        Spacer()

        NavigationLink(value: NavDestination.settingsServers) {
          Label(String(localized: "server.switch"), systemImage: "arrow.left.arrow.right")
        }
        .font(.caption)
        .controlSize(.small)
        .adaptiveButtonStyle(.borderedProminent)
      }

      if let userEmail = accountDisplayValue {
        InfoRow(
          label: ServerSection.account.title,
          value: userEmail,
          icon: "person"
        )
      }

      InfoRow(
        label: String(localized: "Server"),
        value: current.serverURL.isEmpty ? current.serverDisplayName : current.serverURL,
        icon: "globe"
      )

      ServerUpdateStatusView()
        .foregroundColor(.secondary)
        .font(.footnote)

    }
    .padding(12)
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16))
  }

  private var managementSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(String(localized: "Management"))
        .font(.headline)

      LazyVGrid(columns: actionColumns, spacing: 12) {
        NavigationLink(value: NavDestination.settingsLibraries) {
          ServerActionTile(
            title: ServerSection.libraries.title,
            systemImage: ServerSection.libraries.icon
          )
        }
        .adaptiveButtonStyle(.plain)

        if current.isAdmin {
          NavigationLink(value: NavDestination.settingsServerInfo) {
            ServerActionTile(
              title: ServerSection.serverInfo.title,
              systemImage: ServerSection.serverInfo.icon
            )
          }
          .adaptiveButtonStyle(.plain)

          NavigationLink(value: NavDestination.settingsTasks) {
            ServerActionTile(
              title: ServerSection.tasks.title,
              systemImage: ServerSection.tasks.icon,
              badge: taskQueueStatus.count > 0 ? "\(taskQueueStatus.count)" : nil,
              badgeColor: Color.accentColor
            )
          }
          .adaptiveButtonStyle(.plain)

          NavigationLink(value: NavDestination.settingsHistory) {
            ServerActionTile(
              title: ServerSection.history.title,
              systemImage: ServerSection.history.icon
            )
          }
          .adaptiveButtonStyle(.plain)
        }
      }
    }
  }

  private var accountSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(ServerSection.account.title)
        .font(.headline)

      accountDetailsCard

      LazyVGrid(columns: actionColumns, spacing: 12) {
        NavigationLink(value: NavDestination.settingsApiKey) {
          ServerActionTile(
            title: ServerSection.apiKeys.title,
            systemImage: ServerSection.apiKeys.icon
          )
        }
        .adaptiveButtonStyle(.plain)

        NavigationLink(value: NavDestination.settingsAuthenticationActivity) {
          ServerActionTile(
            title: ServerSection.authenticationActivity.title,
            systemImage: ServerSection.authenticationActivity.icon
          )
        }
        .adaptiveButtonStyle(.plain)
      }
    }
  }

  private var accountDetailsCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text(String(localized: "User"))
            .font(.caption)
            .foregroundColor(.secondary)

          if let user = authViewModel.user {
            Text(user.email)
              .font(.headline)
              .lineLimit(2)
          } else if let accountDisplayValue {
            Text(accountDisplayValue)
              .font(.headline)
              .lineLimit(2)
          }
        }

        Spacer()

        if authViewModel.user != nil {
          Button {
            showingUpdatePassword = true
          } label: {
            Label(
              String(localized: "account.details.changePassword"),
              systemImage: "key"
            )
          }
          .font(.caption)
          .controlSize(.mini)
          .adaptiveButtonStyle(.borderedProminent)
        }
      }

      if let user = authViewModel.user {
        VStack(alignment: .leading, spacing: 8) {
          Text(String(localized: "Roles"))
            .font(.caption)
            .foregroundColor(.secondary)

          if user.userRoles.isEmpty {
            Text(String(localized: "user.role.none"))
              .foregroundColor(.secondary)
              .italic()
          } else {
            HFlow(spacing: 8) {
              ForEach(user.userRoles, id: \.self) { role in
                RoleBadge(role: role)
              }
            }
          }
        }
      }

    }
    .padding(12)
    .background(.thinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .sheet(isPresented: $showingUpdatePassword) {
      UpdatePasswordSheet()
        .presentationDetents([.medium])
    }
  }

  private var actionColumns: [GridItem] {
    [GridItem(.adaptive(minimum: 160), spacing: 12)]
  }

  private var serverDisplayName: String {
    if !current.serverDisplayName.isEmpty {
      return current.serverDisplayName
    }
    return String(localized: "Server")
  }

  private var roleLabel: String? {
    guard accountDisplayValue != nil else { return nil }
    return String(localized: current.isAdmin ? "user.role.admin" : "user.role.user")
  }

  private var accountDisplayValue: String? {
    if let user = authViewModel.user, !user.email.isEmpty {
      return user.email
    }
    if !current.username.isEmpty {
      return current.username
    }
    return nil
  }
}
