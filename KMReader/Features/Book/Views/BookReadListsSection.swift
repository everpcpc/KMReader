//
// BookReadListsSection.swift
//
//

import SwiftUI

struct BookReadListsSection: View {
  @AppStorage("currentAccount") private var current: Current = .init()

  let readListIds: [String]

  @State private var readLists: [SidebarReadListItem] = []

  private var readListIdsKey: String {
    readListIds.sorted().joined(separator: ",")
  }

  var body: some View {
    sectionContent
      .task(id: "\(current.instanceId)|\(readListIdsKey)") {
        await loadReadLists()
      }
  }

  // Renders nothing when empty: an always-present zero-height container would
  // swallow the parent VStack spacing and make adjacent Dividers hug the content.
  @ViewBuilder
  private var sectionContent: some View {
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
            NavigationLink(value: NavDestination.readListDetail(readListId: readList.readListId)) {
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
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func loadReadLists() async {
    let instanceId = current.instanceId
    guard !instanceId.isEmpty, !readListIds.isEmpty else {
      if !readLists.isEmpty {
        withAnimation {
          readLists = []
        }
      }
      return
    }

    do {
      let database = try await DatabaseOperator.database()
      let loadedReadLists = try await database.fetchSidebarReadLists(
        instanceId: instanceId,
        readListIds: Set(readListIds)
      )
      if readLists != loadedReadLists {
        withAnimation {
          readLists = loadedReadLists
        }
      }
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }
}
