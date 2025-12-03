//
//  LibraryPickerSheet.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct LibraryPickerSheet: View {
  @AppStorage("currentInstanceId") private var currentInstanceId: String = ""
  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
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
    SheetView(title: "Select Library", size: .large) {
        Form {
          if libraryManager.isLoading && libraries.isEmpty {
            ProgressView()
              .frame(maxWidth: .infinity)
          } else {
            // For single selection in picker, use first libraryId
            let binding = Binding(
              get: { dashboard.libraryIds.first ?? "" },
              set: { newValue in
                if newValue.isEmpty {
                  dashboard.libraryIds = []
                } else {
                  dashboard.libraryIds = [newValue]
                }
              }
            )
            Picker("Library", selection: binding) {
              Label("All Libraries", systemImage: "square.grid.2x2").tag("")
              ForEach(libraries) { library in
                Label(library.name, systemImage: "books.vertical").tag(library.libraryId)
              }
            }
            .pickerStyle(.inline)
          }
        }
    }
    controls: {
      HStack(spacing: 12) {
        Button(action: refreshLibraries) {
          Label("Refresh", systemImage: "arrow.clockwise")
        }
        .disabled(libraryManager.isLoading)

        Button {
          dismiss()
        } label: {
          Label("Done", systemImage: "checkmark")
        }
      }
    }
    .onChange(of: dashboard.libraryIds) { oldValue, newValue in
      let oldFirst = oldValue.first ?? ""
      let newFirst = newValue.first ?? ""
      if oldFirst != newFirst {
        dismiss()
      }
    }
    .task {
      await libraryManager.loadLibraries()
    }
  }

  private func refreshLibraries() {
    Task {
      await libraryManager.refreshLibraries()
    }
  }
}
