//
//  SettingsConnectionSection.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

#if !os(macOS)
  struct SettingsConnectionSection: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @AppStorage("isOffline") private var isOffline: Bool = false
    @AppStorage("currentInstanceId") private var currentInstanceId: String = ""

    @Query private var instances: [KomgaInstance]

    @State private var isCheckingConnection = false

    private var instanceInitializer: InstanceInitializer {
      InstanceInitializer.shared
    }

    private var currentInstance: KomgaInstance? {
      guard let uuid = UUID(uuidString: currentInstanceId) else { return nil }
      return instances.first { $0.id == uuid }
    }

    private var lastSyncTimeText: String {
      guard let instance = currentInstance else {
        return String(localized: "settings.sync_data.never")
      }
      let latestSync = max(instance.seriesLastSyncedAt, instance.booksLastSyncedAt)
      if latestSync == Date(timeIntervalSince1970: 0) {
        return String(localized: "settings.sync_data.never")
      }
      let formatter = RelativeDateTimeFormatter()
      formatter.unitsStyle = .short
      return formatter.localizedString(for: latestSync, relativeTo: Date())
    }

    var body: some View {
      Section {
        if isOffline {
          Button {
            Task {
              await tryReconnect()
            }
          } label: {
            HStack {
              Label(String(localized: "settings.offline"), systemImage: "wifi.slash")
                .foregroundColor(.orange)
              Spacer()
              if isCheckingConnection {
                ProgressView()
              } else {
                Text(String(localized: "settings.offline.tap_to_reconnect"))
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
            }
          }
          .disabled(isCheckingConnection)
        }

        Button {
          Task {
            await InstanceInitializer.shared.syncData()
          }
        } label: {
          HStack {
            Label(
              String(localized: "settings.sync_data"),
              systemImage: "arrow.triangle.2.circlepath")
            Spacer()
            if instanceInitializer.isSyncing {
              ProgressView()
            } else {
              Text(lastSyncTimeText)
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
        }
        .disabled(instanceInitializer.isSyncing || isOffline)
      } footer: {
        Text(String(localized: "settings.sync_data.description"))
      }
    }

    private func tryReconnect() async {
      isCheckingConnection = true
      let serverReachable = await authViewModel.loadCurrentUser()
      isOffline = !serverReachable
      isCheckingConnection = false

      if serverReachable {
        SSEService.shared.connect()
        ErrorManager.shared.notify(message: String(localized: "settings.connection_restored"))
      }
    }
  }
#endif
