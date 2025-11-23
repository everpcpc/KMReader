//
//  BooksListViewForReadList.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

// Books list view for read list
struct BooksListViewForReadList: View {
  let readListId: String
  @Bindable var bookViewModel: BookViewModel
  var onReadBook: (String, Bool) -> Void
  let layoutMode: BrowseLayoutMode
  let layoutHelper: BrowseLayoutHelper

  @AppStorage("readListBookBrowseOptions") private var browseOpts: BookBrowseOptions =
    BookBrowseOptions()

  @State private var selectedBookIds: Set<String> = []
  @State private var isSelectionMode = false
  @State private var isDeleting = false

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Books")
          .font(.headline)

        Spacer()

        HStack(spacing: 8) {
          BookFilterView(browseOpts: $browseOpts)

          if !isSelectionMode && AppConfig.isAdmin {
            Button {
              withAnimation {
                isSelectionMode = true
              }
            } label: {
              Image(systemName: "square.and.pencil.circle")
                .imageScale(.large)
            }
            .transition(.opacity.combined(with: .scale))
          }
        }
      }

      if isSelectionMode {
        SelectionToolbar(
          selectedCount: selectedBookIds.count,
          totalCount: bookViewModel.books.count,
          isDeleting: isDeleting,
          onSelectAll: {
            if selectedBookIds.count == bookViewModel.books.count {
              selectedBookIds.removeAll()
            } else {
              selectedBookIds = Set(bookViewModel.books.map { $0.id })
            }
          },
          onDelete: {
            Task {
              await deleteSelectedBooks()
            }
          },
          onCancel: {
            isSelectionMode = false
            selectedBookIds.removeAll()
          }
        )
      }

      if bookViewModel.isLoading && bookViewModel.books.isEmpty {
        ProgressView()
          .frame(maxWidth: .infinity)
          .padding()
      } else {
        Group {
          switch layoutMode {
          case .grid:
            LazyVGrid(columns: layoutHelper.columns, spacing: 12) {
              ForEach(bookViewModel.books) { book in
                Group {
                  if isSelectionMode {
                    BookCardView(
                      book: book,
                      viewModel: bookViewModel,
                      cardWidth: layoutHelper.cardWidth,
                      onBookUpdated: {
                        refreshBooks()
                      }
                    )
                    .allowsHitTesting(false)
                    .overlay(alignment: .topTrailing) {
                      Image(
                        systemName: selectedBookIds.contains(book.id)
                          ? "checkmark.circle.fill" : "circle"
                      )
                      .foregroundColor(
                        selectedBookIds.contains(book.id) ? .accentColor : .secondary
                      )
                      .font(.title2)
                      .padding(8)
                      .background(
                        Circle()
                          .fill(.ultraThinMaterial)
                      )
                      .transition(.scale.combined(with: .opacity))
                      .animation(
                        .spring(response: 0.3, dampingFraction: 0.7),
                        value: selectedBookIds.contains(book.id))
                    }
                    .contentShape(Rectangle())
                    .highPriorityGesture(
                      TapGesture()
                        .onEnded {
                          withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if selectedBookIds.contains(book.id) {
                              selectedBookIds.remove(book.id)
                            } else {
                              selectedBookIds.insert(book.id)
                            }
                          }
                        }
                    )
                  } else {
                    BookCardView(
                      book: book,
                      viewModel: bookViewModel,
                      cardWidth: layoutHelper.cardWidth,
                      onBookUpdated: {
                        refreshBooks()
                      }
                    )
                  }
                }
                .onAppear {
                  if book.id == bookViewModel.books.last?.id {
                    Task {
                      await bookViewModel.loadReadListBooks(
                        readListId: readListId, browseOpts: browseOpts, refresh: false)
                    }
                  }
                }
              }
            }
            .padding(12)
          case .list:
            LazyVStack(spacing: 8) {
              ForEach(bookViewModel.books) { book in
                Group {
                  if isSelectionMode {
                    HStack(spacing: 12) {
                      Image(
                        systemName: selectedBookIds.contains(book.id)
                          ? "checkmark.circle.fill" : "circle"
                      )
                      .foregroundColor(
                        selectedBookIds.contains(book.id) ? .accentColor : .secondary
                      )
                      .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                          if selectedBookIds.contains(book.id) {
                            selectedBookIds.remove(book.id)
                          } else {
                            selectedBookIds.insert(book.id)
                          }
                        }
                      }
                      .transition(.scale.combined(with: .opacity))
                      .animation(
                        .spring(response: 0.3, dampingFraction: 0.7),
                        value: selectedBookIds.contains(book.id))

                      BookRowView(
                        book: book,
                        viewModel: bookViewModel,
                        onReadBook: { _ in },
                        onBookUpdated: {
                          refreshBooks()
                        },
                        showSeriesTitle: true
                      )
                      .allowsHitTesting(false)
                    }
                    .contentShape(Rectangle())
                    .highPriorityGesture(
                      TapGesture()
                        .onEnded {
                          withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if selectedBookIds.contains(book.id) {
                              selectedBookIds.remove(book.id)
                            } else {
                              selectedBookIds.insert(book.id)
                            }
                          }
                        }
                    )
                  } else {
                    HStack(spacing: 12) {
                      BookRowView(
                        book: book,
                        viewModel: bookViewModel,
                        onReadBook: { incognito in
                          onReadBook(book.id, incognito)
                        },
                        onBookUpdated: {
                          refreshBooks()
                        },
                        showSeriesTitle: true
                      )
                    }
                  }
                }
                .onAppear {
                  if book.id == bookViewModel.books.last?.id {
                    Task {
                      await bookViewModel.loadReadListBooks(
                        readListId: readListId, browseOpts: browseOpts, refresh: false)
                    }
                  }
                }
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
    .task(id: readListId) {
      await bookViewModel.loadReadListBooks(
        readListId: readListId, browseOpts: browseOpts, refresh: true)
    }
    .onChange(of: browseOpts) {
      Task {
        await bookViewModel.loadReadListBooks(
          readListId: readListId, browseOpts: browseOpts, refresh: true)
      }
    }
  }
}

extension BooksListViewForReadList {
  fileprivate func refreshBooks() {
    Task {
      await bookViewModel.loadReadListBooks(
        readListId: readListId, browseOpts: browseOpts, refresh: true)
    }
  }

  @MainActor
  private func deleteSelectedBooks() async {
    guard !selectedBookIds.isEmpty else { return }
    guard !isDeleting else { return }

    isDeleting = true
    defer { isDeleting = false }

    do {
      try await ReadListService.shared.removeBooksFromReadList(
        readListId: readListId,
        bookIds: Array(selectedBookIds)
      )

      await MainActor.run {
        ErrorManager.shared.notify(message: "Books removed from read list")
      }

      // Clear selection and exit selection mode with animation
      withAnimation {
        selectedBookIds.removeAll()
        isSelectionMode = false
      }

      // Refresh the books list
      await bookViewModel.loadReadListBooks(
        readListId: readListId, browseOpts: browseOpts, refresh: true)
    } catch {
      // Handle error if needed
    }
  }
}
