//
//  LibraryPickerSheet.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct LibraryPickerSheet: View {
  @AppStorage("currentInstanceId") private var currentInstanceId: String = ""
  @AppStorage("isAdmin") private var isAdmin: Bool = false
  @Query(sort: [SortDescriptor(\KomgaLibrary.name, order: .forward)]) private var allLibraries:
    [KomgaLibrary]
  @State private var isRefreshing = false

  private let metricsLoader = LibraryMetricsLoader.shared

  private var libraries: [KomgaLibrary] {
    guard !currentInstanceId.isEmpty else {
      return []
    }
    return allLibraries.filter {
      $0.instanceId == currentInstanceId && $0.libraryId != KomgaLibrary.allLibrariesId
    }
  }

  private var allLibrariesEntry: KomgaLibrary? {
    guard !currentInstanceId.isEmpty else {
      return nil
    }
    return allLibraries.first {
      $0.instanceId == currentInstanceId && $0.libraryId == KomgaLibrary.allLibrariesId
    }
  }

  var body: some View {
    SheetView(title: String(localized: "Libraries"), size: .large) {
      LibraryListContent(
        showDeleteAction: false,
        forceMetricsOnAppear: false,
        enablePullToRefresh: false
      )
    } controls: {
      HStack(spacing: 12) {
        Button {
          Task { @MainActor in await refreshLibrariesAndMetrics() }
        } label: {
          Label("Refresh", systemImage: "arrow.clockwise")
        }
        .disabled(isRefreshing)
      }
    }
  }

  @MainActor
  private func refreshLibrariesAndMetrics() async {
    guard !isRefreshing else { return }
    isRefreshing = true

    await LibraryManager.shared.refreshLibraries()

    if isAdmin, !currentInstanceId.isEmpty {
      let libraryIds = libraries.map { $0.libraryId }
      let hasAllEntry = allLibrariesEntry != nil

      let metricsByLibrary = await metricsLoader.refreshMetrics(
        instanceId: currentInstanceId,
        libraryIds: libraryIds,
        ensureAllLibrariesEntry: hasAllEntry
      )

      for library in libraries {
        guard let metrics = metricsByLibrary[library.libraryId] else { continue }
        library.fileSize = metrics.fileSize
        library.booksCount = metrics.booksCount
        library.seriesCount = metrics.seriesCount
        library.sidecarsCount = metrics.sidecarsCount
      }
    }

    isRefreshing = false
  }
}
