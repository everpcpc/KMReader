//
// BookDownloadActionsSection.swift
//
//

import SwiftUI

struct BookDownloadActionsSection: View {
  let book: Book
  let status: DownloadStatus
  let protectionSources: [OfflineProtectionSource]

  @AppStorage("currentAccount") private var current: Current = .init()

  init(
    book: Book,
    status: DownloadStatus,
    protectionSources: [OfflineProtectionSource] = []
  ) {
    self.book = book
    self.status = status
    self.protectionSources = protectionSources
  }

  var body: some View {
    HStack {
      Button {
        Task {
          await OfflineManager.shared.toggleDownload(
            instanceId: current.instanceId, info: book.downloadInfo)
        }
      } label: {
        HStack(spacing: 4) {
          Image(systemName: status.menuIcon)
            .font(.caption2)
          Text(status.menuLabel)
            .font(.caption)
            .fontWeight(.medium)
            .lineLimit(1)
        }
      }
      .adaptiveButtonStyle(.bordered)
      .optimizedControlSize()
      .tint(status.menuColor)

      Spacer()

      if let icon = status.displayIcon {
        OfflineProtectionStatusChip(
          label: status.displayLabel,
          systemImage: icon,
          spinning: status.isPending,
          sources: protectionSources
        )
      }
    }
    .padding(.vertical, 4)
    .animation(.default, value: status)
  }
}
