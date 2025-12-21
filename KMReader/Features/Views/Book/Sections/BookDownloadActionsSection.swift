//
//  BookDownloadActionsSection.swift
//  KMReader
//

import SwiftUI

struct BookDownloadActionsSection: View {
  @Environment(KomgaBook.self) private var komgaBook

  @AppStorage("currentInstanceId") private var currentInstanceId: String = ""

  private var book: Book {
    komgaBook.toBook()
  }

  private var status: DownloadStatus {
    komgaBook.downloadStatus
  }

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
            instanceId: currentInstanceId, info: book.downloadInfo)
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
