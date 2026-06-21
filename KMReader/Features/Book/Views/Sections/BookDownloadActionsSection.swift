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
        Label {
          Text(status.menuLabel)
        } icon: {
          Image(systemName: status.menuIcon)
            .frame(width: PlatformHelper.iconSize, height: PlatformHelper.iconSize)
        }
      }
      .font(.caption)
      .adaptiveButtonStyle(status.isDownloaded || status.isPending ? .bordered : .borderedProminent)
      .tint(status.menuColor)

      Spacer()

      HStack(spacing: 6) {
        InfoChip(
          label: status.displayLabel,
          systemImage: status.displayIcon,
          backgroundColor: status.displayColor.opacity(0.2),
          foregroundColor: status.displayColor
        )

        OfflineProtectionSourcesMenu(sources: protectionSources)
      }
    }
    .padding(.vertical, 4)
    .animation(.default, value: status)
  }
}
