//
//  SettingsHistoryView.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct SettingsHistoryView: View {
  @AppStorage("isAdmin") private var isAdmin: Bool = false
  @Environment(\.modelContext) private var modelContext

  @State private var pagination = PaginationState<HistoricalEvent>(pageSize: 20)
  @State private var isLoading = false
  @State private var isLoadingMore = false
  @State private var lastTriggeredItemId: String?

  @State private var isClearingLocal = false

  @State private var bookNameById: [String: String] = [:]
  @State private var seriesNameById: [String: String] = [:]
  @State private var selectedEvent: HistoricalEvent?

  var body: some View {
    List {
      if !isAdmin {
        AdminRequiredView()
      } else if isLoading && pagination.isEmpty {
        Section {
          HStack {
            Spacer()
            ProgressView()
            Spacer()
          }
        }
      } else if pagination.isEmpty {
        Section {
          HStack {
            Spacer()
            VStack(spacing: 8) {
              Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
              Text(String(localized: "No history found"))
                .foregroundColor(.secondary)
            }
            Spacer()
          }
          .padding(.vertical)
          .tvFocusableHighlight()
        }
      } else {
        #if os(tvOS) || os(macOS)
          if isAdmin {
            Section {
              Button(role: .destructive) {
                Task {
                  await clearLocalReferencedEntities()
                }
              } label: {
                HStack {
                  Spacer()
                  if isClearingLocal {
                    ProgressView()
                  } else {
                    Label(String(localized: "Clear Local Entries"), systemImage: "trash")
                  }
                  Spacer()
                }
              }
              .adaptiveButtonStyle(.borderedProminent)
              .disabled(isClearingLocal)
            }
            .listRowBackground(Color.clear)
          }
        #endif

        Section {
          ForEach(pagination.items, id: \.id) { event in
            historyRow(event: event)
          }

          if isLoadingMore {
            HStack {
              Spacer()
              ProgressView()
              Spacer()
            }
            .padding(.vertical)
          }
        }
      }
    }
    .optimizedListStyle()
    .inlineNavigationBarTitle(SettingsSection.history.title)
    #if os(iOS)
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button(role: .destructive) {
            Task {
              await clearLocalReferencedEntities()
            }
          } label: {
            Label(String(localized: "Clear Local Entries"), systemImage: "trash")
          }
          .disabled(isClearingLocal || !isAdmin)
        }
      }
    #endif
    .sheet(item: $selectedEvent) { event in
      SheetView(title: String(localized: "History Details"), size: .large, applyFormStyle: true) {
        HistoryEventDetailView(event: event)
      }
    }
    .task {
      if isAdmin {
        await loadHistory(refresh: true)
      }
    }
    .refreshable {
      if isAdmin {
        await loadHistory(refresh: true)
      }
    }
  }

  @ViewBuilder
  private func historyRow(event: HistoricalEvent) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: iconName(for: event.type))
        .foregroundColor(.secondary)
        .frame(width: 24)

      VStack(alignment: .leading, spacing: 6) {
        Text(event.type)
          .lineLimit(1)

        if let seriesId = event.seriesId, !seriesId.isEmpty {
          HStack(spacing: 6) {
            Image(systemName: "rectangle.stack")
              .font(.caption)
            Text(seriesNameById[seriesId] ?? seriesId)
              .foregroundColor(.secondary)
              .lineLimit(1)
          }
        }

        if let bookId = event.bookId, !bookId.isEmpty {
          HStack(spacing: 6) {
            Image(systemName: "book")
              .font(.caption)
            Text(bookNameById[bookId] ?? bookId)
              .foregroundColor(.secondary)
              .lineLimit(1)
          }
        }
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 8) {
        Text(event.timestamp.formattedMediumDateTime)
          .font(.caption)
          .foregroundColor(.secondary)

        Button {
          selectedEvent = event
        } label: {
          Image(systemName: "info.circle")
        }
        .buttonStyle(.borderless)
        .disabled(event.properties.isEmpty)
      }
    }
    .tvFocusableHighlight()
    .padding(.vertical, 4)
    .onAppear {
      guard pagination.hasMorePages,
        !isLoadingMore,
        pagination.shouldLoadMore(after: event, threshold: 3),
        lastTriggeredItemId != event.id
      else {
        return
      }
      lastTriggeredItemId = event.id
      Task {
        await loadMoreHistory()
      }
    }
  }

  private func loadHistory(refresh: Bool) async {
    if refresh {
      pagination.reset()
      lastTriggeredItemId = nil
      bookNameById.removeAll()
      seriesNameById.removeAll()
    }

    isLoading = true

    do {
      let page = try await HistoryService.shared.getHistory(
        page: pagination.currentPage,
        size: pagination.pageSize
      )
      await MainActor.run {
        let items = page.content ?? []
        _ = pagination.applyPage(items)
        pagination.advance(moreAvailable: !(page.last ?? true))
        lastTriggeredItemId = nil
      }
      await updateLocalReferences(for: pagination.items)
    } catch {
      await MainActor.run {
        lastTriggeredItemId = nil
      }
      ErrorManager.shared.alert(error: error)
    }

    isLoading = false
  }

  private func loadMoreHistory() async {
    guard pagination.hasMorePages && !isLoadingMore else { return }

    isLoadingMore = true

    do {
      let page = try await HistoryService.shared.getHistory(
        page: pagination.currentPage,
        size: pagination.pageSize
      )
      await MainActor.run {
        let items = page.content ?? []
        _ = pagination.applyPage(items)
        pagination.advance(moreAvailable: !(page.last ?? true))
        lastTriggeredItemId = nil
      }
      await updateLocalReferences(for: pagination.items)
    } catch {
      await MainActor.run {
        lastTriggeredItemId = nil
      }
      ErrorManager.shared.alert(error: error)
    }

    isLoadingMore = false
  }

  @MainActor
  private func updateLocalReferences(for events: [HistoricalEvent]) async {
    let instanceId = AppConfig.currentInstanceId
    let bookIds = Set(
      events
        .filter { $0.type == "BookFileDeleted" }
        .compactMap { $0.bookId }
        .filter { !$0.isEmpty }
    )
    let seriesIds = Set(
      events
        .filter { $0.type == "SeriesFolderDeleted" }
        .compactMap { $0.seriesId }
        .filter { !$0.isEmpty }
    )

    var hasLocalMatches = false

    if !bookIds.isEmpty {
      let idsToFetch = Array(bookIds.subtracting(bookNameById.keys))
      if !idsToFetch.isEmpty {
        let descriptor = FetchDescriptor<KomgaBook>(
          predicate: #Predicate { book in
            book.instanceId == instanceId && idsToFetch.contains(book.bookId)
          }
        )
        if let results = try? modelContext.fetch(descriptor), !results.isEmpty {
          hasLocalMatches = true
          for book in results {
            bookNameById[book.bookId] = book.metaTitle
          }
        }
      } else if !bookNameById.isEmpty {
        hasLocalMatches = true
      }
    }

    if !seriesIds.isEmpty {
      let idsToFetch = Array(seriesIds.subtracting(seriesNameById.keys))
      if !idsToFetch.isEmpty {
        let descriptor = FetchDescriptor<KomgaSeries>(
          predicate: #Predicate { series in
            series.instanceId == instanceId && idsToFetch.contains(series.seriesId)
          }
        )
        if let results = try? modelContext.fetch(descriptor), !results.isEmpty {
          hasLocalMatches = true
          for series in results {
            seriesNameById[series.seriesId] = series.metaTitle
          }
        }
      } else if !seriesNameById.isEmpty {
        hasLocalMatches = true
      }
    }

    if hasLocalMatches == false && (!bookIds.isEmpty || !seriesIds.isEmpty) {
      hasLocalMatches =
        containsLocalMatches(bookIds: Array(bookIds), seriesIds: Array(seriesIds))
    }

  }

  @MainActor
  private func containsLocalMatches(bookIds: [String], seriesIds: [String]) -> Bool {
    let instanceId = AppConfig.currentInstanceId

    if !bookIds.isEmpty {
      let descriptor = FetchDescriptor<KomgaBook>(
        predicate: #Predicate { book in
          book.instanceId == instanceId && bookIds.contains(book.bookId)
        }
      )
      if let results = try? modelContext.fetch(descriptor), !results.isEmpty {
        return true
      }
    }

    if !seriesIds.isEmpty {
      let descriptor = FetchDescriptor<KomgaSeries>(
        predicate: #Predicate { series in
          series.instanceId == instanceId && seriesIds.contains(series.seriesId)
        }
      )
      if let results = try? modelContext.fetch(descriptor), !results.isEmpty {
        return true
      }
    }

    return false
  }

  private func clearLocalReferencedEntities() async {
    guard !isClearingLocal else { return }
    isClearingLocal = true

    let instanceId = AppConfig.currentInstanceId
    let bookIds = Set(
      pagination.items
        .filter { $0.type == "BookFileDeleted" }
        .compactMap { $0.bookId }
        .filter { !$0.isEmpty }
    )
    let seriesIds = Set(
      pagination.items
        .filter { $0.type == "SeriesFolderDeleted" }
        .compactMap { $0.seriesId }
        .filter { !$0.isEmpty }
    )

    do {
      for bookId in bookIds {
        await DatabaseOperator.shared.deleteBook(id: bookId, instanceId: instanceId)
      }
      for seriesId in seriesIds {
        await DatabaseOperator.shared.deleteSeries(id: seriesId, instanceId: instanceId)
      }
      try await DatabaseOperator.shared.commitImmediately()

      await MainActor.run {
        for bookId in bookIds {
          bookNameById.removeValue(forKey: bookId)
        }
        for seriesId in seriesIds {
          seriesNameById.removeValue(forKey: seriesId)
        }
      }

      await updateLocalReferences(for: pagination.items)
    } catch {
      ErrorManager.shared.alert(error: error)
    }

    let removedBooks = bookIds.count
    let removedSeries = seriesIds.count
    let removedTotal = removedBooks + removedSeries
    await MainActor.run {
      let message: String
      if removedTotal > 0 {
        message = String(localized: "notification.history.clearedLocalEntries")
      } else {
        message = String(localized: "notification.history.noLocalEntries")
      }
      ErrorManager.shared.notify(message: message)
    }

    isClearingLocal = false
  }

  private func iconName(for type: String) -> String {
    switch type {
    case "BookFileDeleted":
      return "xmark.circle"
    case "SeriesFolderDeleted":
      return "folder.badge.minus"
    case "DuplicatePageDeleted":
      return "book.closed"
    case "BookConverted":
      return "archivebox"
    case "BookImported":
      return "tray.and.arrow.down"
    default:
      return "clock"
    }
  }
}

private struct HistoryEventDetailView: View {
  let event: HistoricalEvent

  var body: some View {
    Form {
      Section {
        LabeledContent("Type", value: event.type)
        LabeledContent("Timestamp", value: event.timestamp.formattedMediumDateTime)
        if let seriesId = event.seriesId, !seriesId.isEmpty {
          LabeledContent("Series ID", value: seriesId)
        }
        if let bookId = event.bookId, !bookId.isEmpty {
          LabeledContent("Book ID", value: bookId)
        }
      }

      Section("Details") {
        if event.properties.isEmpty {
          Text("No details available")
            .foregroundColor(.secondary)
        } else {
          ForEach(event.properties.keys.sorted(), id: \.self) { key in
            LabeledContent(key, value: event.properties[key] ?? "")
          }
        }
      }
    }
  }
}
