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

  var body: some View {
    NavigationStack {
      Form {
        Picker("Library", selection: $selectedLibraryId) {
          Label("All Libraries", systemImage: "square.grid.2x2").tag("")
          ForEach(LibraryManager.shared.libraries) { library in
            Label(library.name, systemImage: "books.vertical").tag(library.id)
          }
        }
        .pickerStyle(.inline)
      }
      .navigationTitle("Select Library")
      #if canImport(UIKit)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
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
    }
  }
}
