//
//  SettingsOfflineTasksRow.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct SettingsOfflineTasksRow: View {
  @AppStorage("offlinePaused") private var offlinePaused: Bool = false
  @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange

  @Query private var books: [KomgaBook]

  init() {
    let instanceId = AppConfig.currentInstanceId
    _books = Query(
      filter: #Predicate<KomgaBook> { book in
        book.instanceId == instanceId
          && (book.downloadStatusRaw == "pending" || book.downloadStatusRaw == "downloading"
            || book.downloadStatusRaw == "failed")
      },
      sort: [SortDescriptor(\KomgaBook.downloadAt, order: .forward)]
    )
  }

  private var downloadingCount: Int {
    books.filter { $0.downloadStatusRaw == "downloading" }.count
  }

  private var pendingCount: Int {
    books.filter { $0.downloadStatusRaw == "pending" }.count
  }

  private var failedCount: Int {
    books.filter { $0.downloadStatusRaw == "failed" }.count
  }

  var body: some View {
    HStack {
      Label(
        SettingsSection.offlineTasks.title,
        systemImage: SettingsSection.offlineTasks.icon
      )

      Spacer()

      HStack(spacing: 12) {
        if offlinePaused {
          HStack(spacing: 4) {
            Image(systemName: "pause.fill")
            Text(String(localized: "Paused"))
          }
          .font(.caption)
          .fontWeight(.semibold)
          .foregroundColor(.orange)
        } else {
          if downloadingCount > 0 {
            HStack(spacing: 4) {
              Image(systemName: "arrow.down.circle.fill")
              Text("\(downloadingCount)")
            }
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(themeColor.color)
          }

          if pendingCount > 0 {
            HStack(spacing: 4) {
              Image(systemName: "clock.fill")
              Text("\(pendingCount)")
            }
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
          }

          if failedCount > 0 {
            HStack(spacing: 4) {
              Image(systemName: "exclamationmark.circle.fill")
              Text("\(failedCount)")
            }
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.red)
          }
        }
      }
    }.tag(SettingsSection.offlineTasks)
  }
}
