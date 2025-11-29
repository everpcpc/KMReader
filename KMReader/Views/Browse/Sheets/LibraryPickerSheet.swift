//
//  LibraryPickerSheet.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct LibraryPickerSheet: View {
  @AppStorage("selectedLibraryId") private var selectedLibraryId: String = ""
  @AppStorage("currentInstanceId") private var currentInstanceId: String = ""
  @Environment(\.dismiss) private var dismiss
  @Query(sort: [SortDescriptor(\KomgaLibrary.name, order: .forward)]) private var allLibraries:
    [KomgaLibrary]
  private let libraryManager = LibraryManager.shared

  private var libraries: [KomgaLibrary] {
    guard !currentInstanceId.isEmpty else {
      return []
    }
    return allLibraries.filter { $0.instanceId == currentInstanceId }
  }

  var body: some View {
    NavigationStack {
      Form {
        if libraryManager.isLoading && libraries.isEmpty {
          ProgressView()
            .frame(maxWidth: .infinity)
        } else {
          Picker("Library", selection: $selectedLibraryId) {
            Label("All Libraries", systemImage: "square.grid.2x2").tag("")
            ForEach(libraries) { library in
              Label(library.name, systemImage: "books.vertical").tag(library.libraryId)
            }
          }
          .pickerStyle(.inline)
        }
      }
      .padding(PlatformHelper.sheetPadding)
      .inlineNavigationBarTitle("Select Library")
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
    #if canImport(UIKit)
      .presentationDetents([.medium])
    #else
      .frame(minWidth: 400, minHeight: 400)
    #endif
  }
}
