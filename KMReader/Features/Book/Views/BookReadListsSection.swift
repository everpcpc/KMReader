//
//  BookReadListsSection.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct BookReadListsSection: View {
  @Query private var komgaReadLists: [KomgaReadList]

  init(readListIds: [String]) {
    let instanceId = AppConfig.current.instanceId
    _komgaReadLists = Query(
      filter: #Predicate<KomgaReadList> {
        $0.instanceId == instanceId && readListIds.contains($0.readListId)
      })
  }

  private var readLists: [ReadList] {
    komgaReadLists.map { $0.toReadList() }
  }

  var body: some View {
    if !readLists.isEmpty {
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 4) {
          Image(systemName: ContentIcon.readList)
            .font(.caption)
          Text("Read Lists")
            .font(.headline)
        }
        .foregroundColor(.secondary)

        VStack(alignment: .leading, spacing: 8) {
          ForEach(readLists) { readList in
            NavigationLink(value: NavDestination.readListDetail(readListId: readList.id)) {
              HStack {
                Label(readList.name, systemImage: ContentIcon.readList)
                  .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
              .padding()
              .background(Color.secondary.opacity(0.1))
              .cornerRadius(16)
            }.adaptiveButtonStyle(.plain)
          }
        }
      }
    }
  }
}
