//
// BookReadListsSection.swift
//
//

import SQLiteData
import SwiftUI

struct BookReadListsSection: View {
  @FetchAll private var komgaReadLists: [KomgaReadListRecord]

  init(readListIds: [String]) {
    let instanceId = AppConfig.current.instanceId
    if readListIds.isEmpty {
      _komgaReadLists = FetchAll(
        KomgaReadListRecord.where { $0.readListId.eq("__none__") }
      )
    } else {
      _komgaReadLists = FetchAll(
        KomgaReadListRecord.where {
          $0.instanceId.eq(instanceId) && $0.readListId.in(readListIds)
        }
      )
    }
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
