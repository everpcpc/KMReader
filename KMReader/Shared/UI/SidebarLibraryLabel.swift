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
          .lineLimit(1)
        Spacer()
        if let booksCount = library.booksCount {
          Text("\(Int(booksCount))")
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
}
