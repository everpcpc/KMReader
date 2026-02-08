//
//  BookBrowseOptionsSheet.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct BookBrowseOptionsSheet: View {
  @Binding var browseOpts: BookBrowseOptions
  @Environment(\.dismiss) private var dismiss
  @State private var tempOpts: BookBrowseOptions
  @State private var showSaveFilterSheet = false
  let filterType: SavedFilterType
  let seriesId: String?
  let libraryIds: [String]?
  let includeOfflineSorts: Bool

  private var availableSortFields: [BookSortField] {
    includeOfflineSorts ? BookSortField.offlineCases : BookSortField.onlineCases
  }

  private var defaultOptions: BookBrowseOptions {
    var options = BookBrowseOptions()
    if includeOfflineSorts {
      options.sortField = .downloadDate
      options.sortDirection = .descending
    }
    if !availableSortFields.contains(options.sortField), let fallbackField = availableSortFields.first {
      options.sortField = fallbackField
    }
    return options
  }

  init(
    browseOpts: Binding<BookBrowseOptions>,
    filterType: SavedFilterType = .books,
    seriesId: String? = nil,
    libraryIds: [String]? = nil,
    includeOfflineSorts: Bool = false
  ) {
    var initialOpts = browseOpts.wrappedValue
    let availableSortFields = includeOfflineSorts ? BookSortField.offlineCases : BookSortField.onlineCases
    if !availableSortFields.contains(initialOpts.sortField), let fallbackField = availableSortFields.first {
      initialOpts.sortField = fallbackField
    }

    self._browseOpts = browseOpts
    self._tempOpts = State(initialValue: initialOpts)
    self.filterType = filterType
    self.seriesId = seriesId
    self.libraryIds = libraryIds
    self.includeOfflineSorts = includeOfflineSorts
  }

  var body: some View {
    SheetView(
      title: String(localized: "Filter & Sort"), size: .both, onReset: resetOptions,
      applyFormStyle: true
    ) {
      Form {
        SortOptionView(
          sortField: $tempOpts.sortField,
          sortDirection: $tempOpts.sortDirection,
          sortFields: availableSortFields
        )

        Section(String(localized: "Read Status")) {
          ForEach(ReadStatus.allCases, id: \.self) { filter in
            Button {
              withAnimation(.easeInOut) {
                toggleReadStatus(filter)
              }
            } label: {
              HStack {
                Text(filter.displayName)
                Spacer()
                let state = resolveReadStatusState(
                  for: filter,
                  include: tempOpts.includeReadStatuses,
                  exclude: tempOpts.excludeReadStatuses
                )
                Image(systemName: icon(for: state))
                  .foregroundStyle(color(for: state))
              }
            }
          }
        }

        Section(String(localized: "Flags")) {
          Button {
            withAnimation(.easeInOut) {
              tempOpts.oneshotFilter.cycle(to: .yes)
            }
          } label: {
            HStack {
              Text(FilterStrings.oneshot)
              Spacer()
              Image(systemName: icon(for: tempOpts.oneshotFilter.state(for: .yes)))
                .foregroundStyle(color(for: tempOpts.oneshotFilter.state(for: .yes)))
            }
          }

          Button {
            withAnimation(.easeInOut) {
              tempOpts.deletedFilter.cycle(to: .yes)
            }
          } label: {
            HStack {
              Text(FilterStrings.deleted)
              Spacer()
              Image(systemName: icon(for: tempOpts.deletedFilter.state(for: .yes)))
                .foregroundStyle(color(for: tempOpts.deletedFilter.state(for: .yes)))
            }
          }
        }

        MetadataFilterSection(
          metadataFilter: $tempOpts.metadataFilter,
          libraryIds: libraryIds,
          seriesId: seriesId,
          showAuthors: true,
          showTags: true
        )

      }
    } controls: {
      Button {
        showSaveFilterSheet = true
      } label: {
        Label(String(localized: "Save Filter"), systemImage: "bookmark")
      }
      Button(action: applyChanges) {
        Label(String(localized: "Done"), systemImage: "checkmark")
      }
    }
    .sheet(isPresented: $showSaveFilterSheet) {
      SaveFilterSheet(
        filterType: filterType,
        bookOptions: tempOpts
      )
    }
  }

  private func resetOptions() {
    withAnimation {
      tempOpts = defaultOptions
    }
  }

  private func applyChanges() {
    if tempOpts != browseOpts {
      browseOpts = tempOpts
    }
    dismiss()
  }

  private func icon(for state: TriStateSelection) -> String {
    switch state {
    case .off:
      return "circle"
    case .include:
      return "checkmark.circle.fill"
    case .exclude:
      return "xmark.circle.fill"
    }
  }

  private func color(for state: TriStateSelection) -> Color {
    switch state {
    case .off:
      return .secondary
    case .include:
      return .accentColor
    case .exclude:
      return .red
    }
  }

  private func state(for status: ReadStatus) -> TriStateSelection {
    if tempOpts.includeReadStatuses.contains(status) {
      return .include
    }
    if tempOpts.excludeReadStatuses.contains(status) {
      return .exclude
    }
    return .off
  }

  private func toggleReadStatus(_ status: ReadStatus) {
    var include = tempOpts.includeReadStatuses
    var exclude = tempOpts.excludeReadStatuses
    KMReader.applyReadStatusToggle(status, include: &include, exclude: &exclude)
    tempOpts.includeReadStatuses = include
    tempOpts.excludeReadStatuses = exclude
  }
}
