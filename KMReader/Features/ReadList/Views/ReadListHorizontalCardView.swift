//
// ReadListHorizontalCardView.swift
//
//

import SwiftUI

@MainActor
struct ReadListHorizontalCardView: View {
  let item: ReadListDisplayItem
  var coverWidth: CGFloat = 56
  var onChanged: () -> Void = {}
  let onDeleteRequested: () -> Void

  @State private var showEditSheet = false

  private var readListContextMenu: some View {
    ReadListContextMenu(
      readListId: item.readListId,
      downloadStatus: item.downloadStatus,
      offlinePolicy: item.offlinePolicy,
      offlinePolicyLimit: item.offlinePolicyLimit,
      isPinned: item.isPinned,
      onDeleteRequested: {
        onDeleteRequested()
      },
      onEditRequested: {
        showEditSheet = true
      },
      onPinToggleRequested: {
        togglePinned()
      },
      onMutationCompleted: onChanged
    )
  }

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      NavigationLink(value: NavDestination.readListDetail(readListId: item.readListId)) {
        HStack(alignment: .center, spacing: 12) {
          ThumbnailImage(
            id: item.readListId, type: .readlist, width: coverWidth,
            preserveAspectRatioOverride: false
          )
          .frame(width: coverWidth)
          .allowsHitTesting(false)

          VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            Text(item.name)
              .font(.system(size: LayoutConfig.horizontalCardFontSize, weight: .semibold))
              .lineLimit(2)
              .multilineTextAlignment(.leading)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
              Text("\(item.bookCount) books")
                .font(.system(size: LayoutConfig.horizontalCardSeriesFontSize))

              Text(item.lastModifiedDate.formattedMediumDate)
                .font(.system(size: LayoutConfig.horizontalCardMetaFontSize))
            }
            .foregroundColor(.secondary)

            Spacer(minLength: 0)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
      }
      .adaptiveButtonStyle(.plain)

      EllipsisMenuButton {
        readListContextMenu
      }
      .font(.system(size: LayoutConfig.horizontalCardAccessoryIconSize, weight: .medium))
      .padding(.trailing, 2)
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background {
      RoundedRectangle(cornerRadius: 12)
        .fill(Color.cardBackground)
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
    .contentShape(Rectangle())
    #if os(iOS)
      .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 12))
    #endif
    .contextMenu {
      readListContextMenu
    }
    .sheet(isPresented: $showEditSheet, onDismiss: onChanged) {
      ReadListEditSheet(readList: item.readList)
    }
  }

  private func togglePinned() {
    let nextPinned = !item.isPinned
    Task {
      do {
        let database = try await DatabaseOperator.database()
        await database.setReadListPinned(
          readListId: item.readListId,
          instanceId: item.instanceId,
          isPinned: nextPinned
        )
        onChanged()
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }
  }
}
