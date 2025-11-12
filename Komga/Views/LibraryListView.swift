//
//  LibraryListView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct LibraryListView: View {
  @State private var viewModel = LibraryViewModel()
  @Environment(AuthViewModel.self) private var authViewModel

  var body: some View {
    NavigationView {
      Group {
        if viewModel.isLoading && viewModel.libraries.isEmpty {
          ProgressView()
        } else if let errorMessage = viewModel.errorMessage {
          VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
              .font(.largeTitle)
              .foregroundColor(.orange)
            Text(errorMessage)
              .multilineTextAlignment(.center)
            Button("Retry") {
              Task {
                await viewModel.loadLibraries()
              }
            }
          }
          .padding()
        } else {
          List {
            Section(header: Text("Libraries")) {
              ForEach(viewModel.libraries) { library in
                NavigationLink(
                  destination: SeriesListView(libraryId: library.id, libraryName: library.name)
                ) {
                  VStack(alignment: .leading, spacing: 4) {
                    Text(library.name)
                      .font(.headline)
                    Text(library.root)
                      .font(.caption)
                      .foregroundColor(.secondary)
                  }
                  .padding(.vertical, 4)
                }
              }
            }
          }
        }
      }
      .navigationTitle("Browse")
      .navigationBarTitleDisplayMode(.inline)
      .refreshable {
        await viewModel.loadLibraries()
      }
    }
    .task {
      if viewModel.libraries.isEmpty {
        await viewModel.loadLibraries()
      }
    }
  }
}

#Preview {
  LibraryListView()
    .environment(AuthViewModel())
}
