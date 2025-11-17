//
//  BrowseView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct BrowseView: View {
  @AppStorage("selectedLibraryId") private var selectedLibraryId: String = ""
  @AppStorage("browseOptions") private var browseOpts: BrowseOptions = BrowseOptions()
  @State private var showBrowseOptionsSheet = false
  @State private var showLibraryPickerSheet = false

  private var selectedLibrary: LibraryInfo? {
    guard !selectedLibraryId.isEmpty else { return nil }
    return LibraryManager.shared.getLibrary(id: selectedLibraryId)
  }

  var body: some View {
    NavigationStack {
      GeometryReader { geometry in
        ScrollView {
          VStack(spacing: 0) {
            SeriesListView(
              browseOpts: $browseOpts,
              width: geometry.size.width,
              height: geometry.size.height
            )
          }
        }
        .navigationTitle("Browse")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .navigationBarLeading) {
            Button {
              showLibraryPickerSheet = true
            } label: {
              Image(systemName: "books.vertical")
            }
          }
          ToolbarItem(placement: .navigationBarTrailing) {
            Button {
              showBrowseOptionsSheet = true
            } label: {
              Image(systemName: "line.3.horizontal.decrease.circle")
            }
          }
        }
        .sheet(isPresented: $showBrowseOptionsSheet) {
          BrowseOptionsSheet(browseOpts: $browseOpts)
        }
        .sheet(isPresented: $showLibraryPickerSheet) {
          LibraryPickerSheet()
        }
        .onChange(of: selectedLibraryId) {
          browseOpts.libraryId = selectedLibraryId
        }
        .onAppear {
          browseOpts.libraryId = selectedLibraryId
        }
      }
    }
  }
}

struct BrowseOptionsSheet: View {
  @Binding var browseOpts: BrowseOptions
  @Environment(\.dismiss) private var dismiss
  @State private var tempOpts: BrowseOptions

  init(browseOpts: Binding<BrowseOptions>) {
    self._browseOpts = browseOpts
    self._tempOpts = State(initialValue: browseOpts.wrappedValue)
  }

  var body: some View {
    NavigationStack {
      Form {
        // Filter Section
        Section("Filters") {
          // Read Status Filter
          Picker("Read Status", selection: $tempOpts.readStatusFilter) {
            ForEach(ReadStatusFilter.allCases, id: \.self) { filter in
              Text(filter.displayName).tag(filter)
            }
          }
          .pickerStyle(.menu)

          // Series Status Filter
          Picker("Series Status", selection: $tempOpts.seriesStatusFilter) {
            ForEach(SeriesStatusFilter.allCases, id: \.self) { filter in
              Text(filter.displayName).tag(filter)
            }
          }
          .pickerStyle(.menu)
        }

        // Sort Section
        Section("Sort") {
          // Sort Field
          Picker("Sort By", selection: $tempOpts.sortField) {
            ForEach(SeriesSortField.allCases, id: \.self) { field in
              Text(field.displayName).tag(field)
            }
          }
          .pickerStyle(.menu)

          // Sort Direction (only show if field supports direction)
          if tempOpts.sortField.supportsDirection {
            Picker("Direction", selection: $tempOpts.sortDirection) {
              ForEach(SortDirection.allCases, id: \.self) { direction in
                HStack {
                  Image(systemName: direction.icon)
                  Text(direction.displayName)
                }
                .tag(direction)
              }
            }
            .pickerStyle(.menu)
          }
        }
      }
      .navigationTitle("Filter & Sort")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            // Only assign if there are changes
            if tempOpts != browseOpts {
              browseOpts = tempOpts
            }
            dismiss()
          } label: {
            Label("Done", systemImage: "checkmark")
          }
        }
      }
    }
  }
}

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
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
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
