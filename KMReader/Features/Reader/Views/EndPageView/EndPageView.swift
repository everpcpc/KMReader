//
// EndPageView.swift
//
//

import SwiftUI

struct EndPageView: View {
  @Bindable var viewModel: ReaderViewModel
  let nextBook: Book?
  let readListContext: ReaderReadListContext?
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

  var body: some View {
    NextBookInfoView(
      textColor: textColor,
      nextBook: nextBook,
      readListContext: readListContext,
      showImage: showImage
    )
    .environment(\.layoutDirection, .leftToRight)
    .allowsHitTesting(false)
    .environment(\.layoutDirection, readingDirection == .rtl ? .rightToLeft : .leftToRight)
    .padding(40)
  }

}
