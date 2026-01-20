//
//  ChapterListSheetView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

#if os(iOS)
  import SwiftUI

  struct ChapterListSheetView: View {
    let chapters: [WebPubLink]
    let currentLink: WebPubLink?
    let goToChapter: (WebPubLink) -> Void

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
