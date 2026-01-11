//
//  LibraryPickerSheet.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct LibraryPickerSheet: View {
  @AppStorage("currentAccount") private var current: Current = .init()
  @Query(sort: [SortDescriptor(\KomgaLibrary.name, order: .forward)]) private var allLibraries: [KomgaLibrary]
  @State private var isRefreshing = false

  private let metricsLoader = LibraryMetricsLoader.shared

  private var libraries: [KomgaLibrary] {
    guard !current.instanceId.isEmpty else {
      return []
    }
    return allLibraries.filter {
      $0.instanceId == current.instanceId && $0.libraryId != KomgaLibrary.allLibrariesId
    }
  }

  private var allLibrariesEntry: KomgaLibrary? {
    guard !current.instanceId.isEmpty else {
      return nil
    }
    return allLibraries.first {
      $0.instanceId == current.instanceId && $0.libraryId == KomgaLibrary.allLibrariesId
    }
  }

  var body: some View {
    SheetView(title: String(localized: "Libraries"), size: .large, applyFormStyle: true) {
      LibraryListContent(
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

    if current.isAdmin, !current.instanceId.isEmpty {
      let libraryIds = libraries.map { $0.libraryId }
      let hasAllEntry = allLibrariesEntry != nil

      let metricsByLibrary = await metricsLoader.refreshMetrics(
        instanceId: current.instanceId,
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
