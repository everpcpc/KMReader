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

  init(browseOpts: Binding<BookBrowseOptions>) {
    self._browseOpts = browseOpts
    self._tempOpts = State(initialValue: browseOpts.wrappedValue)
  }

  var body: some View {
    SheetView(
      title: String(localized: "Filter & Sort"), size: .both, onReset: resetOptions,
      applyFormStyle: true
    ) {
      Form {
        SortOptionView(
          sortField: $tempOpts.sortField,
          sortDirection: $tempOpts.sortDirection
        )

        Section("Read Status") {
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

        Section("Flags") {
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

      }
    } controls: {
      Button(action: applyChanges) {
        Label("Done", systemImage: "checkmark")
      }
    }
  }

  private func resetOptions() {
    withAnimation {
      tempOpts = BookBrowseOptions()
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
