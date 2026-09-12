//
// BookReadListsSection.swift
//
//

import SwiftUI

struct BookReadListsSection: View {
  let readLists: [SidebarReadListItem]

  // Pure display component: loading is hoisted to the parent detail view's
  // always-realized task. A self-loading .task here never fires while the body
  // renders empty inside the parent's LazyVStack (#967), and an always-present
  // zero-height anchor would collapse the surrounding stack spacing (#986).
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
}
