//
// ReadListDetailView.swift
//
//

import SwiftUI

struct ReadListDetailView: View {
  let readListId: String
  let readerPresentation: ReaderPresentationManager

  @AppStorage("currentAccount") private var current: Current = .init()
  @AppStorage("readListDetailLayout") private var readListDetailLayout: BrowseLayoutMode = .list

  @Environment(\.dismiss) private var dismiss

  @State private var item: ReadListDisplayItem?
  @State private var showDeleteConfirmation = false
  @State private var showEditSheet = false
  @State private var showFilterSheet = false
  @State private var showSavedFilters = false

  init(
    readListId: String,
    readerPresentation: ReaderPresentationManager
  ) {
    self.readListId = readListId
    self.readerPresentation = readerPresentation
  }

  private var readList: ReadList? {
    item?.readList
  }

  private var navigationTitle: String {
    readList?.name ?? String(localized: "title.readList")
  }

  private var isPinned: Bool {
    item?.isPinned ?? false
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading) {
        if let readList = readList {
          VStack(alignment: .leading) {
            ReadListDetailContentView(
              readList: readList
            )

            #if os(tvOS)
              readListToolbarContent
                .padding(.vertical, 8)
            #endif

            Divider()
            if let item {
              ReadListDownloadActionsSection(
                readListId: item.readListId,
                status: item.downloadStatus,
                onMutationCompleted: {
                  Task {
                    await loadReadListDetails()
                  }
                }
              )
            }
            Divider()
          }
          .padding(.horizontal)

          // Books list
          if item != nil {
            BooksListViewForReadList(
              readListId: readListId,
              readerPresentation: readerPresentation,
              showFilterSheet: $showFilterSheet,
              showSavedFilters: $showSavedFilters
            )
          }
        } else {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
    }
    .inlineNavigationBarTitle(navigationTitle)
    .komgaHandoff(
      title: navigationTitle,
      url: KomgaWebLinkBuilder.readList(serverURL: current.serverURL, readListId: readListId),
      scope: .browse
    )
    .alert("Delete Read List?", isPresented: $showDeleteConfirmation) {
      Button("Delete", role: .destructive) {
        Task {
          await deleteReadList()
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This will permanently delete \(readList?.name ?? "this read list") from Komga.")
    }
    #if os(iOS) || os(macOS)
      .toolbar {
        ToolbarItem(placement: .automatic) {
          readListToolbarContent
        }
      }
    #endif
    .sheet(isPresented: $showEditSheet) {
      if let readList = readList {
        ReadListEditSheet(readList: readList)
          .onDisappear {
            Task {
              await loadReadListDetails()
            }
          }
      }
    }
    .sheet(isPresented: $showSavedFilters) {
      SavedFiltersView(filterType: .readListBooks)
    }
    .task {
      await loadReadListDetails()
    }
  }
}

// Helper functions for ReadListDetailView
extension ReadListDetailView {
  private func loadReadListDetails() async {
    await loadLocalReadList()
    do {
      _ = try await SyncService.syncReadList(id: readListId)
    } catch {
      if case APIError.notFound = error {
        dismiss()
      } else if item == nil {
        ErrorManager.shared.alert(error: error)
      }
    }
    await loadLocalReadList()
  }

  private func loadLocalReadList() async {
    guard let database = try? await DatabaseOperator.database() else {
      item = nil
      return
    }
    item = try? await database.fetchReadListDisplayItem(
      readListId: readListId,
      instanceId: current.instanceId
    )
  }

  @MainActor
  private func deleteReadList() async {
    do {
      try await ReadListService.deleteReadList(readListId: readListId)
      ErrorManager.shared.notify(message: String(localized: "notification.readList.deleted"))
      dismiss()
    } catch {
      ErrorManager.shared.alert(error: error)
    }
  }

  private func togglePinned() {
    guard let item else { return }
    let nextPinned = !item.isPinned
    Task {
      try? await DatabaseOperator.database().setReadListPinned(
        readListId: item.readListId,
        instanceId: item.instanceId,
        isPinned: nextPinned
      )
      await loadLocalReadList()
    }
  }

  @ViewBuilder
  private var readListToolbarContent: some View {
    HStack {
      Button {
        showSavedFilters = true
      } label: {
        Image(systemName: "bookmark")
      }

      Button {
        showFilterSheet = true
      } label: {
        Image(systemName: "line.3.horizontal.decrease.circle")
      }

      Menu {
        LayoutModePicker(selection: $readListDetailLayout)

        Divider()

        Button {
          togglePinned()
        } label: {
          Label(
            isPinned ? String(localized: "action.unpinFromTop") : String(localized: "action.pinToTop"),
            systemImage: isPinned ? "pin.slash" : "pin"
          )
        }

        if current.isAdmin {
          Divider()

          Button {
            showEditSheet = true
          } label: {
            Label("Edit", systemImage: "pencil")
          }

          Divider()

          Button(role: .destructive) {
            showDeleteConfirmation = true
          } label: {
            Label("Delete Read List", systemImage: "trash")
          }
        }
      } label: {
        Image(systemName: "ellipsis")
      }
    }.toolbarButtonStyle()
  }
}
