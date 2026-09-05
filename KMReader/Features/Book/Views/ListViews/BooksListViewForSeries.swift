//
// BooksListViewForSeries.swift
//
//

import SwiftUI

// Books list view for series detail
struct BooksListViewForSeries: View {
  let seriesId: String
  @Bindable var bookViewModel: BookViewModel
  @Binding var showFilterSheet: Bool
  @Binding var showSavedFilters: Bool

  @AppStorage("seriesDetailLayout") private var layoutMode: BrowseLayoutMode = .list
  @AppStorage("seriesBookBrowseOptions") private var browseOpts: BookBrowseOptions =
    BookBrowseOptions()
  @AppStorage("currentAccount") private var current: Current = .init()
  @AppStorage("isOffline") private var isOffline: Bool = false

  @State private var selectedBookIds: Set<String> = []
  @State private var isSelectionMode = false
  @State private var isSubmitting = false
  @State private var allSeriesBookIds: [String] = []

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

        Button {
          Task {
            await refreshBooks(refresh: true)
          }
        } label: {
          Image(systemName: "arrow.clockwise")
        }
        .disabled(bookViewModel.isLoading)
        .adaptiveButtonStyle(.bordered)
        .optimizedControlSize()

        Spacer()

        HStack(spacing: 8) {
          BookFilterView(
            browseOpts: $browseOpts,
            showFilterSheet: $showFilterSheet,
            showSavedFilters: $showSavedFilters,
            filterType: .seriesBooks,
            seriesId: seriesId
          )

          if supportsSelectionMode && !isSelectionMode && !isOffline {
            Button {
              withAnimation {
                isSelectionMode = true
              }
            } label: {
              Image(systemName: "square.and.pencil")
            }
            .adaptiveButtonStyle(.borderedProminent)
            .optimizedControlSize()
            .transition(.opacity.combined(with: .scale))
          }
        }
      }
      .padding(.horizontal)

      if supportsSelectionMode && isSelectionMode {
        ReadStatusSelectionToolbar(
          selectedCount: selectedBookIds.count,
          totalCount: allSeriesBookIds.count,
          isSubmitting: isSubmitting,
          onSelectAll: {
            if selectedBookIds.count == allSeriesBookIds.count {
              selectedBookIds.removeAll()
            } else {
              selectedBookIds = Set(allSeriesBookIds)
            }
          },
          onMarkRead: {
            Task {
              await markSelected(read: true)
            }
          },
          onMarkUnread: {
            Task {
              await markSelected(read: false)
            }
          },
          onCancel: {
            isSelectionMode = false
            selectedBookIds.removeAll()
          }
        )
        .padding(.horizontal)
      }

      SeriesBooksQueryView(
        seriesId: seriesId,
        bookViewModel: bookViewModel,
        browseOpts: browseOpts,
        browseLayout: layoutMode,
        isSelectionMode: supportsSelectionMode && isSelectionMode,
        selectedBookIds: $selectedBookIds,
        refreshBooks: {
          Task {
            await refreshBooks(refresh: true)
          }
        }
      )
    }
    .task(id: seriesId) {
      await refreshBooks(refresh: true)
    }
    .onChange(of: browseOpts) {
      Task {
        await refreshBooks(refresh: true)
      }
    }
    .onChange(of: isSelectionMode) {
      if isSelectionMode {
        Task {
          await loadAllSeriesBookIds()
        }
      }
    }
  }

  private func loadAllSeriesBookIds() async {
    guard let database = try? await DatabaseOperator.database() else { return }
    allSeriesBookIds = await database.fetchAllSeriesBookIds(
      seriesId: seriesId,
      instanceId: current.instanceId
    )
  }

  private func refreshBooks(refresh: Bool) async {
    await bookViewModel.loadSeriesBooks(
      seriesId: seriesId,
      browseOpts: browseOpts,
      refresh: refresh
    )
  }

  private func markSelected(read: Bool) async {
    guard !selectedBookIds.isEmpty, !isSubmitting else { return }

    isSubmitting = true
    defer { isSubmitting = false }

    let bookIds = Array(selectedBookIds)
    let outcome = await withTaskGroup(
      of: Error?.self,
      returning: (firstError: Error?, failureCount: Int).self
    ) { group in
      for bookId in bookIds {
        group.addTask {
          do {
            if read {
              try await BookService.markAsRead(bookId: bookId)
            } else {
              try await BookService.markAsUnread(bookId: bookId)
            }
            return nil
          } catch {
            return error
          }
        }
      }
      var firstError: Error?
      var failureCount = 0
      for await result in group {
        if let result {
          failureCount += 1
          if firstError == nil { firstError = result }
        }
      }
      return (firstError: firstError, failureCount: failureCount)
    }

    // Sync whatever succeeded so the UI never goes stale, then report failures.
    if outcome.failureCount < bookIds.count {
      _ = try? await SyncService.syncSeriesDetail(seriesId: seriesId)
      try? await SyncService.syncAllSeriesBooks(seriesId: seriesId)
      await ContentProjectionNotifier.postSeriesBooksDidChange(
        seriesId: seriesId,
        reason: .readingProgress
      )
      await DashboardSectionRefreshNotifier.postReadStatusChanged(
        source: .manual,
        reason: "Books read status changed"
      )
    }

    if let firstError = outcome.firstError {
      ErrorManager.shared.alert(error: firstError)
    } else if read {
      ErrorManager.shared.notify(message: String(localized: "notification.book.markedRead"))
    } else {
      ErrorManager.shared.notify(message: String(localized: "notification.book.markedUnread"))
    }

    withAnimation {
      selectedBookIds.removeAll()
      isSelectionMode = false
    }

    await refreshBooks(refresh: true)
  }
}
