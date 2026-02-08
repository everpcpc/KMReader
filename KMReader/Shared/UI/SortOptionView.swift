//
//  SortOptionView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SortOptionView<SortField: SortFieldProtocol>: View {
  @Binding var sortField: SortField
  @Binding var sortDirection: SortDirection
  let sortFields: [SortField]

  init(
    sortField: Binding<SortField>,
    sortDirection: Binding<SortDirection>,
    sortFields: [SortField]? = nil
  ) {
    self._sortField = sortField
    self._sortDirection = sortDirection
    self.sortFields = sortFields ?? Array(SortField.allCases)
  }

  var body: some View {
    Section("Sort") {
      Picker("Sort By", selection: $sortField) {
        ForEach(sortFields, id: \.self) { field in
          Text(field.displayName).tag(field)
        }
      }
      .pickerStyle(.menu)

      if sortField.supportsDirection {
        Picker("Direction", selection: $sortDirection) {
          ForEach(Array(SortDirection.allCases), id: \.self) { direction in
            Label(direction.displayName, systemImage: direction.icon).tag(direction)
          }
        }
        .pickerStyle(.segmented)
      }
    }
  }
}
