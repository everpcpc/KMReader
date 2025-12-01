//
//  DivinaPreferencesSheet.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct DivinaPreferencesSheet: View {
  @Binding var readingDirection: ReadingDirection

  var body: some View {
    NavigationStack {
      List {
        Picker("", selection: $readingDirection) {
          ForEach(ReadingDirection.availableCases, id: \.self) { direction in
            HStack {
              Image(systemName: direction.icon)
              Text(direction.displayName)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .tag(direction)
          }
        }
        .pickerStyle(.inline)
        .buttonStyle(.plain)
      }
      .inlineNavigationBarTitle("Reading Direction")
      .padding(PlatformHelper.sheetPadding)
    }
    .presentationDragIndicator(.visible)
    .platformSheetPresentation(detents: [.large])
  }
}
