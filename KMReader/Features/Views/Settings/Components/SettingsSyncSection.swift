//
//  SettingsSyncSection.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct SettingsSyncSection: View {
  @AppStorage("isOffline") private var isOffline: Bool = false
  @AppStorage("currentAccount") private var current: Current = .init()

  @Query private var instances: [KomgaInstance]

  private var instanceInitializer: InstanceInitializer {
    InstanceInitializer.shared
  }

  private var currentInstance: KomgaInstance? {
    guard let uuid = UUID(uuidString: current.instanceId) else { return nil }
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
}
