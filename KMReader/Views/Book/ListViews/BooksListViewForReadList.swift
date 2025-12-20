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
  var onReadBook: (Book, Bool) -> Void
  let layoutHelper: BrowseLayoutHelper
  @Binding var showFilterSheet: Bool

  @AppStorage("readListDetailLayout") private var layoutMode: BrowseLayoutMode = .list
  @AppStorage("readListBookBrowseOptions") private var browseOpts: ReadListBookBrowseOptions =
    ReadListBookBrowseOptions()
  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
  @AppStorage("isAdmin") private var isAdmin: Bool = false

  @State private var selectedBookIds: Set<String> = []
  @State private var isSelectionMode = false
  @State private var isDeleting = false

  private var supportsSelectionMode: Bool {
    #if os(tvOS)
      return false
    #else
      return true
    #endif
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Books")
          .font(.headline)

        Spacer()

        HStack(spacing: 8) {
          ReadListBookFilterView(
            browseOpts: $browseOpts,
            showFilterSheet: $showFilterSheet,
            layoutMode: $layoutMode
          )

          if supportsSelectionMode && !isSelectionMode && isAdmin {
            Button {
              withAnimation {
                isSelectionMode = true
              }
            } label: {
              Image(systemName: "square.and.pencil.circle")
            }
            .adaptiveButtonStyle(.bordered)
            .controlSize(.small)
            .transition(.opacity.combined(with: .scale))
          }
        }
      }

      if supportsSelectionMode && isSelectionMode {
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
            LazyVGrid(columns: layoutHelper.columns, spacing: layoutHelper.spacing) {
              ForEach(bookViewModel.books) { book in
                Group {
                  if supportsSelectionMode && isSelectionMode {
                    BookCardView(
                      book: book,
                      viewModel: bookViewModel,
                      cardWidth: layoutHelper.cardWidth,
                      onReadBook: { _ in },
                      onBookUpdated: {
                        refreshBooks()
                      },
                      showSeriesTitle: true
                    )
                    .focusPadding()
                    .allowsHitTesting(false)
                    .overlay(alignment: .topTrailing) {
                      Image(
                        systemName: selectedBookIds.contains(book.id)
                          ? "checkmark.circle.fill" : "circle"
                      )
                      .foregroundColor(
                        selectedBookIds.contains(book.id) ? .accentColor : .secondary
                      )
                      .font(.title3)
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
                      onReadBook: { incognito in
                        onReadBook(book, incognito)
                      },
                      onBookUpdated: {
                        refreshBooks()
                      },
                      showSeriesTitle: true
                    )
                    .focusPadding()
                  }
                }
                .onAppear {
                  if book.id == bookViewModel.books.last?.id {
                    Task {
                      await bookViewModel.loadReadListBooks(
                        readListId: readListId, browseOpts: browseOpts,
                        libraryIds: dashboard.libraryIds, refresh: false)
                    }
                  }
                }
              }
            }
            .padding(layoutHelper.spacing)
          case .list:
            LazyVStack(spacing: layoutHelper.spacing) {
              ForEach(bookViewModel.books) { book in
                Group {
                  if supportsSelectionMode && isSelectionMode {
                    HStack(spacing: 12) {
                      Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                          if selectedBookIds.contains(book.id) {
                            selectedBookIds.remove(book.id)
                          } else {
                            selectedBookIds.insert(book.id)
                          }
                        }
                      } label: {
                        Image(
                          systemName: selectedBookIds.contains(book.id)
                            ? "checkmark.circle.fill" : "circle"
                        )
                        .foregroundColor(
                          selectedBookIds.contains(book.id) ? .accentColor : .secondary
                        )
                      }
                      .adaptiveButtonStyle(.plain)
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
                          onReadBook(book, incognito)
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
                        readListId: readListId, browseOpts: browseOpts,
                        libraryIds: dashboard.libraryIds, refresh: false)
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
        readListId: readListId, browseOpts: browseOpts, libraryIds: dashboard.libraryIds,
        refresh: true)
    }
    .onChange(of: browseOpts) {
      Task {
        await bookViewModel.loadReadListBooks(
          readListId: readListId, browseOpts: browseOpts, libraryIds: dashboard.libraryIds,
          refresh: true)
      }
    }
  }
}

extension BooksListViewForReadList {
  fileprivate func refreshBooks() {
    Task {
      await bookViewModel.loadReadListBooks(
        readListId: readListId, browseOpts: browseOpts, libraryIds: dashboard.libraryIds,
        refresh: true)
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
      // Sync the readlist to update its bookIds in local SwiftData
      _ = try? await SyncService.shared.syncReadList(id: readListId)

      await MainActor.run {
        ErrorManager.shared.notify(message: String(localized: "notification.readList.booksRemoved"))
      }

      // Clear selection and exit selection mode with animation
      withAnimation {
        selectedBookIds.removeAll()
        isSelectionMode = false
      }

      // Refresh the books list
      await bookViewModel.loadReadListBooks(
        readListId: readListId, browseOpts: browseOpts, libraryIds: dashboard.libraryIds,
        refresh: true)
    } catch {
      await MainActor.run {
        ErrorManager.shared.alert(error: error)
      }
    }
  }
}
