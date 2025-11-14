//
//  LibraryListView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct LibraryListView: View {
  @Environment(AuthViewModel.self) private var authViewModel
  @AppStorage("themeColorName") private var themeColorOption: ThemeColorOption = .orange

  var body: some View {
    NavigationStack {
      Group {
        if LibraryManager.shared.isLoading && LibraryManager.shared.libraries.isEmpty {
          ProgressView()
        } else if let errorMessage = LibraryManager.shared.errorMessage {
          VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
              .font(.largeTitle)
              .foregroundColor(themeColorOption.color)
            Text(errorMessage)
              .multilineTextAlignment(.center)
            Button("Retry") {
              Task {
                await LibraryManager.shared.loadLibraries()
              }
            }
          }
          .padding()
        } else {
          List {
            Section(header: Text("Libraries")) {
              ForEach(LibraryManager.shared.libraries) { library in
                NavigationLink(
                  destination: SeriesListView(libraryId: library.id, libraryName: library.name)
                ) {
                  VStack(alignment: .leading, spacing: 4) {
                    Text(library.name)
                      .font(.headline)
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
    }
  }
}
