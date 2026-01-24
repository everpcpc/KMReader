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
          List {
            ForEach(chapters, id: \.href) { link in
              ChapterRow(
                link: link,
                currentLink: currentLink,
                goToChapter: goToChapter
              )
            }
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

  private struct ChapterRow: View {
    let link: WebPubLink
    let currentLink: WebPubLink?
    let goToChapter: (WebPubLink) -> Void

    @State private var isExpanded: Bool = false

    init(link: WebPubLink, currentLink: WebPubLink?, goToChapter: @escaping (WebPubLink) -> Void) {
      self.link = link
      self.currentLink = currentLink
      self.goToChapter = goToChapter

      // Initialize isExpanded based on whether this group contains the current link
      if let children = link.children, !children.isEmpty, let currentLink = currentLink {
        _isExpanded = State(initialValue: Self.containsLink(currentLink.href, in: children))
      }
    }

    var body: some View {
      if let children = link.children, !children.isEmpty {
        DisclosureGroup(isExpanded: $isExpanded) {
          ForEach(children, id: \.href) { child in
            ChapterRow(
              link: child,
              currentLink: currentLink,
              goToChapter: goToChapter
            )
          }
        } label: {
          Button(action: {
            goToChapter(link)
          }) {
            ChapterLabel(link: link, currentLink: currentLink)
          }
          .adaptiveButtonStyle(.plain)
        }
        .id(link.href)
      } else {
        Button(action: {
          goToChapter(link)
        }) {
          ChapterLabel(link: link, currentLink: currentLink)
        }
        .adaptiveButtonStyle(.plain)
        .contentShape(Rectangle())
        .id(link.href)
      }
    }

    private static func containsLink(_ href: String, in links: [WebPubLink]) -> Bool {
      for link in links {
        if link.href == href {
          return true
        }
        if let children = link.children, containsLink(href, in: children) {
          return true
        }
      }
      return false
    }
  }

  private struct ChapterLabel: View {
    let link: WebPubLink
    let currentLink: WebPubLink?

    var body: some View {
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
  }
#endif
