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

    var body: some View {
      SheetView(title: String(localized: "title.chapters"), size: .large, applyFormStyle: true) {
        ScrollViewReader { proxy in
          List(chapters, id: \.href) { link in
            Button(action: {
              goToChapter(link)
            }) {
              HStack {
                VStack(alignment: .leading, spacing: 4) {
                  Text(link.title ?? link.href)
                }
                Spacer()
                if let currentLink,
                  currentLink.href == link.href
                {
                  Image(systemName: "bookmark.fill")
                    .foregroundColor(Color.accentColor)
                }
              }
            }
            .adaptiveButtonStyle(.plain)
            .contentShape(Rectangle())
            .id(link.href)
          }
          .optimizedListStyle()
          .onAppear {
            // Wait for the List to fully render before scrolling
            DispatchQueue.main.async {
              if let target = currentLink {
                proxy.scrollTo(target.href, anchor: .center)
              }
            }
          }
        }
      }
      .presentationDragIndicator(.visible)
    }
  }
#endif
