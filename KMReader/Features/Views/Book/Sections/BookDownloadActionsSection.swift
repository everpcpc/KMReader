//
//  BookDownloadActionsSection.swift
//  KMReader
//

import SwiftUI

struct BookDownloadActionsSection: View {
  let book: Book
  let status: DownloadStatus

  @AppStorage("currentAccount") private var current: Current = .init()

  var body: some View {
    HStack {
      InfoChip(
        label: status.displayLabel,
        systemImage: status.displayIcon,
        backgroundColor: status.displayColor.opacity(0.2),
        foregroundColor: status.displayColor
      )

      Spacer()

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
    }
    .animation(.default, value: status)
    .padding(.vertical, 4)
  }
}
