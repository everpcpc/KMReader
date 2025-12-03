//
//  ChapterListSheetView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

#if os(iOS)
  import ReadiumShared
  import SwiftUI

  struct ChapterListSheetView: View {
    let chapters: [ReadiumShared.Link]
    let currentLink: ReadiumShared.Link?
    let goToChapter: (ReadiumShared.Link) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
      NavigationStack {
        ScrollViewReader { proxy in
          List(chapters, id: \.href) { link in
            Button(action: {
              goToChapter(link)
            }) {
              HStack {
                VStack(alignment: .leading, spacing: 4) {
                  Text(link.title ?? link.href)
                    .font(.body)
                }
                Spacer()
                if let currentLink,
                  currentLink.href == link.href
                {
                  Image(systemName: "bookmark.fill")
                }
              }
            }
            .adaptiveButtonStyle(.plain)
            .contentShape(Rectangle())
            .id(link.href)
          }
          .onAppear {
            // Wait for the List to fully render before scrolling
            DispatchQueue.main.async {
              if let target = currentLink {
                proxy.scrollTo(target.href, anchor: .center)
              }
            }
          }
        }
        .padding(PlatformHelper.sheetPadding)
        .inlineNavigationBarTitle("Chapters")
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button {
              dismiss()
            } label: {
              Label("Close", systemImage: "xmark")
            }
          }
        }
      }
      .presentationDragIndicator(.visible)
    }
  }
#endif
