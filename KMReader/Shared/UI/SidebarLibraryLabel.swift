//
//  SidebarLibraryLabel.swift
//  KMReader
//

import SwiftData
import SwiftUI

struct SidebarLibraryLabel: View {
  let library: KomgaLibrary

  var body: some View {
    Label {
      HStack {
        Text(library.name)
        Spacer()
        if let booksCount = library.booksCount {
          Text(formatNumber(booksCount))
            .font(.caption2)
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.1))
            .clipShape(Capsule())
        }
      }
    } icon: {
      Image(systemName: "books.vertical")
    }
  }

  private func formatNumber(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
  }
}
