//
//  HistoryView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct HistoryView: View {
  @State private var bookViewModel = BookViewModel()
  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
  @AppStorage("currentInstanceId") private var currentInstanceId: String = ""

  private func loadRecentlyReadBooks(refresh: Bool) {
    Task {
      await bookViewModel.loadRecentlyReadBooks(
        libraryIds: dashboard.libraryIds,
        refresh: refresh,
      )
    }
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          #if os(tvOS)
            HStack {
              Spacer()
              Button {
                Task {
                  await bookViewModel.loadRecentlyReadBooks(
                    libraryIds: dashboard.libraryIds, refresh: true)
                }
              } label: {
                Label("Refresh", systemImage: "arrow.clockwise.circle")
              }
              .disabled(bookViewModel.isLoading)
              Spacer()
            }
            .padding(.horizontal)
          #endif

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
              onLoadMore: {
                loadRecentlyReadBooks(refresh: false)
              },
              onBookUpdated: {
                loadRecentlyReadBooks(refresh: true)
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
      .inlineNavigationBarTitle("History")
      #if !os(tvOS)
        .toolbar {
          ToolbarItem(placement: .automatic) {
            Button {
              Task {
                await bookViewModel.loadRecentlyReadBooks(
                  libraryIds: dashboard.libraryIds, refresh: true)
              }
            } label: {
              Image(systemName: "arrow.clockwise.circle")
            }
            .disabled(bookViewModel.isLoading)
          }
        }
      #endif
      .onChange(of: currentInstanceId) {
        loadRecentlyReadBooks(refresh: true)
      }
      .onChange(of: dashboard.libraryIds) {
        loadRecentlyReadBooks(refresh: true)
      }
    }
    .task {
      loadRecentlyReadBooks(refresh: true)
    }
  }
}
