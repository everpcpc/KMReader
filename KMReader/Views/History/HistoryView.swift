//
//  HistoryView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct HistoryView: View {
  @State private var bookViewModel = BookViewModel()

  @AppStorage("selectedLibraryId") private var selectedLibraryId: String = ""
  @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange
  @State private var showLibraryPickerSheet = false

  private func refreshRecentlyReadBooks() {
    Task {
      await bookViewModel.loadRecentlyReadBooks(libraryId: selectedLibraryId, refresh: true)
    }
  }

  private func loadMoreRecentlyReadBooks() {
    Task {
      await bookViewModel.loadRecentlyReadBooks(libraryId: selectedLibraryId, refresh: false)
    }
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          if bookViewModel.isLoading && bookViewModel.books.isEmpty {
            ProgressView()
              .frame(maxWidth: .infinity)
              .padding()
              .transition(.opacity)
          } else if !bookViewModel.books.isEmpty {
            // Recently Read Books Section
            ReadHistorySection(
              title: "Recently Read Books",
              bookViewModel: bookViewModel,
              onLoadMore: loadMoreRecentlyReadBooks,
              onBookUpdated: {
                refreshRecentlyReadBooks()
              }
            )
            .transition(.move(edge: .top).combined(with: .opacity))
          } else {
            VStack(spacing: 16) {
              Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
              Text("No reading history")
                .font(.headline)
              Text("Start reading some books to see your history here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .transition(.opacity)
          }
        }
        .padding(.vertical)
      }
      .handleNavigation()
      .navigationTitle("History")
      #if canImport(UIKit)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .automatic) {
          Button {
            showLibraryPickerSheet = true
          } label: {
            Image(systemName: "books.vertical")
          }
        }
        ToolbarItem(placement: .automatic) {
          Button {
            Task {
              await bookViewModel.loadRecentlyReadBooks(
                libraryId: selectedLibraryId, refresh: true)
            }
          } label: {
            Image(systemName: "arrow.clockwise.circle")
          }
          .disabled(bookViewModel.isLoading)
        }
      }
      .sheet(isPresented: $showLibraryPickerSheet) {
        LibraryPickerSheet()
      }
      .onChange(of: selectedLibraryId) {
        refreshRecentlyReadBooks()
      }
    }
    .task {
      refreshRecentlyReadBooks()
    }
  }

  private var selectedLibrary: LibraryInfo? {
    guard !selectedLibraryId.isEmpty else { return nil }
    return LibraryManager.shared.getLibrary(id: selectedLibraryId)
  }
}
