//
//  BooksListView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

extension SortDirection {
  var bookSortString: String {
    "metadata.numberSort,\(rawValue)"
  }
}

struct BooksListView: View {
  let seriesId: String
  @State private var bookViewModel = BookViewModel()
  @Binding var selectedBookId: String?
  @AppStorage("bookListSortDirection") private var sortDirection: SortDirection = .ascending

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Books")
          .font(.headline)

        Spacer()

        Button {
          sortDirection = sortDirection.toggle()
        } label: {
          HStack(spacing: 4) {
            Image(systemName: sortDirection.icon)
            Text(sortDirection.displayName)
          }
          .font(.caption)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(Color.secondary.opacity(0.1))
          .foregroundColor(.primary)
          .cornerRadius(4)
        }
      }

      if bookViewModel.isLoading && bookViewModel.books.isEmpty {
        ProgressView()
          .frame(maxWidth: .infinity)
          .padding()
      } else {
        LazyVStack(spacing: 8) {
          ForEach(bookViewModel.books) { book in
            Button {
              selectedBookId = book.id
            } label: {
              BookRowView(book: book, viewModel: bookViewModel)
            }
            .buttonStyle(PlainButtonStyle())
            .onAppear {
              if book.id == bookViewModel.books.last?.id {
                Task {
                  await bookViewModel.loadMoreBooks(seriesId: seriesId)
                }
              }
            }
          }

          if bookViewModel.isLoading && !bookViewModel.books.isEmpty {
            ProgressView()
              .frame(maxWidth: .infinity)
              .padding()
          }
        }
      }
    }
    .task(id: seriesId) {
      await bookViewModel.loadBooks(seriesId: seriesId, sort: sortDirection.bookSortString)
    }
    .animation(.default, value: bookViewModel.books)
    .onChange(of: sortDirection) {
      Task {
        await bookViewModel.loadBooks(seriesId: seriesId, sort: sortDirection.bookSortString)
      }
    }
  }
}
