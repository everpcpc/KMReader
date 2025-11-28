//
//  LibraryPickerSheet.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct LibraryPickerSheet: View {
  @AppStorage("selectedLibraryId") private var selectedLibraryId: String = ""
  @Environment(\.dismiss) private var dismiss
  @State private var libraryManager = LibraryManager.shared

  var body: some View {
    NavigationStack {
      Form {
        if libraryManager.isLoading && libraryManager.libraries.isEmpty {
          ProgressView()
            .frame(maxWidth: .infinity)
        } else {
          Picker("Library", selection: $selectedLibraryId) {
            Label("All Libraries", systemImage: "square.grid.2x2").tag("")
            ForEach(libraryManager.libraries) { library in
              Label(library.name, systemImage: "books.vertical").tag(library.id)
            }
          }
          .pickerStyle(.inline)
        }
      }
      .navigationTitle("Select Library")
      #if canImport(UIKit)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .automatic) {
          Button {
            Task {
              await libraryManager.refreshLibraries()
            }
          } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
          }
          .disabled(libraryManager.isLoading)
        }
        ToolbarItem(placement: .automatic) {
          Button {
            dismiss()
          } label: {
            Label("Done", systemImage: "checkmark")
          }
        }
      }
      .onChange(of: selectedLibraryId) { oldValue, newValue in
        // Dismiss when user selects a different library
        if oldValue != newValue {
          dismiss()
        }
      }
      .task {
        await libraryManager.loadLibraries()
      }
    }
  }
}
