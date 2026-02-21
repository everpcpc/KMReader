//
// LibraryPickerSheet.swift
//
//

import Dependencies
import SQLiteData
import SwiftUI

struct LibraryPickerSheet: View {
  @AppStorage("currentAccount") private var current: Current = .init()
  @FetchAll(KomgaLibraryRecord.order(by: \.name)) private var allLibraries: [KomgaLibraryRecord]
  @Dependency(\.defaultDatabase) private var database
  @State private var isRefreshing = false

  private let metricsLoader = LibraryMetricsLoader.shared

  private var libraries: [KomgaLibraryRecord] {
    guard !current.instanceId.isEmpty else {
      return []
    }
    return allLibraries.filter {
      $0.instanceId == current.instanceId && $0.libraryId != KomgaLibrary.allLibrariesId
    }
  }

  private var allLibrariesEntry: KomgaLibraryRecord? {
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
      let updates = libraries.compactMap { library -> (UUID, LibraryMetricValues)? in
        guard let metrics = metricsByLibrary[library.libraryId] else { return nil }
        return (library.id, metrics)
      }

      do {
        try await database.write { db in
          for (id, metrics) in updates {
            try KomgaLibraryRecord
              .find(id)
              .update {
                $0.fileSize = #bind(metrics.fileSize)
                $0.booksCount = #bind(metrics.booksCount)
                $0.seriesCount = #bind(metrics.seriesCount)
                $0.sidecarsCount = #bind(metrics.sidecarsCount)
              }
              .execute(db)
          }
        }
      } catch {
        ErrorManager.shared.alert(error: error)
      }
    }

    isRefreshing = false
  }
}
