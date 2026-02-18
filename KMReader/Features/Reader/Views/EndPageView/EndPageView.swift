//
//  EndPageView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct EndPageView: View {
  @Bindable var viewModel: ReaderViewModel
  let nextBook: Book?
  let readList: ReadList?
  let onDismiss: () -> Void
  let onNextBook: (String) -> Void
  let readingDirection: ReadingDirection
  var showImage: Bool = true

  @Environment(\.readerBackgroundPreference) private var readerBackground

  private var textColor: Color {
    switch readerBackground {
    case .black:
      return .white
    case .white:
      return .black
    case .gray:
      return .white
    case .system:
      return .primary
    }
  }

  #if os(tvOS)
    private var tvBackwardSymbolName: String {
      switch readingDirection {
      case .ltr:
        return "arrow.left.circle.fill"
      case .rtl:
        return "arrow.right.circle.fill"
      case .vertical, .webtoon:
        return "arrow.up.circle.fill"
      }
    }

    private var tvForwardSymbolName: String {
      switch readingDirection {
      case .ltr:
        return "arrow.right.circle.fill"
      case .rtl:
        return "arrow.left.circle.fill"
      case .vertical, .webtoon:
        return "arrow.down.circle.fill"
      }
    }
  #endif

  var body: some View {
    VStack {
      NextBookInfoView(
        textColor: textColor,
        nextBook: nextBook,
        readList: readList,
        showImage: showImage
      )
      .environment(\.layoutDirection, .leftToRight)
      .allowsHitTesting(false)

      #if os(tvOS)
        VStack(spacing: 12) {
          HStack(spacing: 14) {
            Image(systemName: tvBackwardSymbolName)
            Image(systemName: "arrow.uturn.backward.circle.fill")
          }
          .font(.title2.weight(.semibold))
          .padding(.horizontal, 18)
          .padding(.vertical, 10)
          .background(.thinMaterial, in: Capsule())

          if nextBook != nil {
            HStack(spacing: 14) {
              Image(systemName: tvForwardSymbolName)
              Image(systemName: "book.closed.fill")
              Image(systemName: "plus.circle.fill")
            }
            .font(.title2.weight(.semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(.thinMaterial, in: Capsule())
          }
        }
        .foregroundStyle(textColor.opacity(0.9))
      #else
        HStack(spacing: 16) {
          // Dismiss button
          Button {
            onDismiss()
          } label: {
            HStack(spacing: 8) {
              Image(systemName: "xmark")
              Text("Close")
            }
            .padding(.horizontal, 4)
            .contentShape(.capsule)
          }
          .adaptiveButtonStyle(.bordered)
          .buttonBorderShape(.capsule)
          .tint(.primary)

          // Next book button
          if let nextBook = nextBook {
            Button {
              onNextBook(nextBook.id)
            } label: {
              HStack(spacing: 8) {
                Text(String(localized: "reader.nextBook"))
                Image(systemName: readingDirection == .rtl ? "arrow.left" : "arrow.right")
              }
              .padding(.horizontal, 4)
              .contentShape(.capsule)
            }
            .adaptiveButtonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .tint(.primary)
          }
        }
      #endif
    }
    .environment(\.layoutDirection, readingDirection == .rtl ? .rightToLeft : .leftToRight)
    .padding(40)
  }

}
