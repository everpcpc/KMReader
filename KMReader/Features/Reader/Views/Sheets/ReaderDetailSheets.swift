//
//  ReaderDetailSheets.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftUI

extension View {
  func readerDetailSheet(
    isPresented: Binding<Bool>,
    book: Book?,
    series: Series?
  ) -> some View {
    self.sheet(isPresented: isPresented) {
      if let book = book, let series = series {
        ReaderDetailSheetContent(book: book, series: series)
      }
    }
  }
}

private struct ReaderDetailSheetContent: View {
  let book: Book
  let series: Series

  @State private var showingSeries: Bool = false

  private var title: String {
    if showingSeries {
      series.metadata.title
    } else {
      book.metadata.title
    }
  }

  var body: some View {
    SheetView(title: title, size: .large) {
      ScrollView {
        Group {
          if book.oneshot {
            OneShotDetailContentView(
              book: book,
              series: series,
              downloadStatus: nil,
              inSheet: true
            )
          } else {
            if showingSeries {
              SeriesDetailContentView(
                series: series
              )
            } else {
              BookDetailContentView(
                book: book,
                downloadStatus: nil,
                inSheet: true
              )
            }
          }
        }.padding(.horizontal)
      }
    } controls: {
      if !book.oneshot {
        Button {
          withAnimation {
            showingSeries.toggle()
          }
        } label: {
          Image(systemName: showingSeries ? ContentIcon.book : ContentIcon.series)
        }
      }
    }
  }
}
