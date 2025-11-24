//
//  ReadingDirectionPickerSheetView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct ReadingDirectionPickerSheetView: View {
  @Binding var readingDirection: ReadingDirection

  @AppStorage("themeColorHex") private var themeColor: ThemeColor = .orange

  var body: some View {
    NavigationStack {
      Form {
        Picker("Reading Direction", selection: $readingDirection) {
          ForEach(ReadingDirection.availableCases, id: \.self) { direction in
            HStack(spacing: 12) {
              Image(systemName: direction.icon)
                .foregroundStyle(themeColor.color)
              Text(direction.displayName)
            }
            .tag(direction)
          }
        }.pickerStyle(.inline)
      }
      .navigationTitle("Reading Mode")
      #if canImport(UIKit)
        .navigationBarTitleDisplayMode(.inline)
      #endif
    }
  }
}
