//
//  SettingsMetricsView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SettingsMetricsView: View {
  @State private var isLoading = false
  @State private var errorMessage: String?

  // All libraries metrics
  @State private var booksFileSize: Metric?
  @State private var series: Metric?
  @State private var books: Metric?
  @State private var collections: Metric?
  @State private var readlists: Metric?
  @State private var sidecars: Metric?

  // Library-specific metrics
  @State private var fileSizeByLibrary: [String: Double] = [:]
  @State private var booksByLibrary: [String: Double] = [:]
  @State private var seriesByLibrary: [String: Double] = [:]
  @State private var sidecarsByLibrary: [String: Double] = [:]

  // Tasks metrics
  @State private var tasks: Metric?
  @State private var tasksCountByType: [String: Double] = [:]
  @State private var tasksTotalTimeByType: [String: Double] = [:]

  var body: some View {
    List {
      if isLoading {
        Section {
          HStack {
            Spacer()
            ProgressView()
            Spacer()
          }
        }
      } else if let errorMessage = errorMessage {
        Section {
          HStack {
            Label("Error", systemImage: "exclamationmark.triangle")
              .foregroundColor(.red)
            Spacer()
            Text(errorMessage)
              .foregroundColor(.secondary)
          }
        }
      } else {
        // All Libraries Section
        Section(header: Text("All Libraries")) {
          if let booksFileSize = booksFileSize,
            let value = booksFileSize.measurements.first?.value
          {
            HStack {
              Label("Disk Space", systemImage: "externaldrive")
              Spacer()
              Text(formatFileSize(value))
                .foregroundColor(.secondary)
            }
          }
          if let series = series, let value = series.measurements.first?.value {
            HStack {
              Label("Series", systemImage: "book.closed")
              Spacer()
              Text(formatNumber(value))
                .foregroundColor(.secondary)
            }
          }
          if let books = books, let value = books.measurements.first?.value {
            HStack {
              Label("Books", systemImage: "book")
              Spacer()
              Text(formatNumber(value))
                .foregroundColor(.secondary)
            }
          }
          if let collections = collections, let value = collections.measurements.first?.value {
            HStack {
              Label("Collections", systemImage: "square.grid.2x2")
              Spacer()
              Text(formatNumber(value))
                .foregroundColor(.secondary)
            }
          }
          if let readlists = readlists, let value = readlists.measurements.first?.value {
            HStack {
              Label("Read Lists", systemImage: "list.bullet")
              Spacer()
              Text(formatNumber(value))
                .foregroundColor(.secondary)
            }
          }
          if let sidecars = sidecars, let value = sidecars.measurements.first?.value {
            HStack {
              Label("Sidecars", systemImage: "doc")
              Spacer()
              Text(formatNumber(value))
                .foregroundColor(.secondary)
            }
          }
        }

        // Tasks Section
        if !tasksCountByType.isEmpty {
          Section(header: Text("Tasks Executed")) {
            ForEach(Array(tasksCountByType.keys.sorted()), id: \.self) { taskType in
              if let count = tasksCountByType[taskType] {
                HStack {
                  Label(taskType, systemImage: "gearshape")
                  Spacer()
                  Text(formatNumber(count))
                    .foregroundColor(.secondary)
                }
              }
            }
          }
        }

        if !tasksTotalTimeByType.isEmpty {
          Section(header: Text("Tasks Total Time")) {
            ForEach(Array(tasksTotalTimeByType.keys.sorted()), id: \.self) { taskType in
              if let time = tasksTotalTimeByType[taskType] {
                HStack {
                  Label(taskType, systemImage: "clock")
                  Spacer()
                  Text(String(format: "%.2f s", time))
                    .foregroundColor(.secondary)
                }
              }
            }
          }
        }

        // Library-specific sections
        if !fileSizeByLibrary.isEmpty {
          Section(header: Text("Library Disk Space")) {
            ForEach(Array(fileSizeByLibrary.keys.sorted()), id: \.self) { libraryId in
              if let size = fileSizeByLibrary[libraryId] {
                HStack {
                  Label(getLibraryName(libraryId), systemImage: "externaldrive")
                  Spacer()
                  Text(formatFileSize(size))
                    .foregroundColor(.secondary)
                }
              }
            }
          }
        }

        if !booksByLibrary.isEmpty {
          Section(header: Text("Library Books")) {
            ForEach(Array(booksByLibrary.keys.sorted()), id: \.self) { libraryId in
              if let count = booksByLibrary[libraryId] {
                HStack {
                  Label(getLibraryName(libraryId), systemImage: "book")
                  Spacer()
                  Text(formatNumber(count))
                    .foregroundColor(.secondary)
                }
              }
            }
          }
        }

        if !seriesByLibrary.isEmpty {
          Section(header: Text("Library Series")) {
            ForEach(Array(seriesByLibrary.keys.sorted()), id: \.self) { libraryId in
              if let count = seriesByLibrary[libraryId] {
                HStack {
                  Label(getLibraryName(libraryId), systemImage: "book.closed")
                  Spacer()
                  Text(formatNumber(count))
                    .foregroundColor(.secondary)
                }
              }
            }
          }
        }

        if !sidecarsByLibrary.isEmpty {
          Section(header: Text("Library Sidecars")) {
            ForEach(Array(sidecarsByLibrary.keys.sorted()), id: \.self) { libraryId in
              if let count = sidecarsByLibrary[libraryId] {
                HStack {
                  Label(getLibraryName(libraryId), systemImage: "doc")
                  Spacer()
                  Text(formatNumber(count))
                    .foregroundColor(.secondary)
                }
              }
            }
          }
        }
      }
    }
    .navigationTitle("Metrics")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      await loadMetrics()
    }
    .refreshable {
      await loadMetrics()
    }
  }

  private func loadMetrics() async {
    isLoading = true
    errorMessage = nil

    // Ensure libraries are loaded
    await LibraryManager.shared.loadLibraries()

    do {
      // Load all libraries metrics
      async let booksFileSizeTask = ManagementService.shared.getMetric("komga.books.filesize")
      async let seriesTask = ManagementService.shared.getMetric("komga.series")
      async let booksTask = ManagementService.shared.getMetric("komga.books")
      async let collectionsTask = ManagementService.shared.getMetric("komga.collections")
      async let readlistsTask = ManagementService.shared.getMetric("komga.readlists")
      async let sidecarsTask = ManagementService.shared.getMetric("komga.sidecars")
      async let tasksTask = ManagementService.shared.getMetric("komga.tasks.execution")

      let (
        booksFileSizeResult, seriesResult, booksResult, collectionsResult, readlistsResult,
        sidecarsResult, tasksResult
      ) = try await (
        booksFileSizeTask, seriesTask, booksTask, collectionsTask, readlistsTask, sidecarsTask,
        tasksTask
      )

      booksFileSize = booksFileSizeResult
      series = seriesResult
      books = booksResult
      collections = collectionsResult
      readlists = readlistsResult
      sidecars = sidecarsResult
      tasks = tasksResult

      // Process library-specific metrics
      fileSizeByLibrary = await processLibraryMetrics(booksFileSizeResult)
      booksByLibrary = await processLibraryMetrics(booksResult)
      seriesByLibrary = await processLibraryMetrics(seriesResult)
      sidecarsByLibrary = await processLibraryMetrics(sidecarsResult)

      // Process tasks metrics
      let (countByType, totalTimeByType) = await processTasksMetrics(tasksResult)
      tasksCountByType = countByType
      tasksTotalTimeByType = totalTimeByType

    } catch {
      errorMessage = error.localizedDescription
    }

    isLoading = false
  }

  private func processLibraryMetrics(_ metric: Metric) async -> [String: Double] {
    var result: [String: Double] = [:]

    guard let libraryTag = metric.availableTags?.first(where: { $0.tag == "library" }) else {
      return result
    }

    for libraryId in libraryTag.values {
      do {
        let libraryMetric = try await ManagementService.shared.getMetric(
          metric.name, tags: [MetricTag(key: "library", value: libraryId)])
        if let value = libraryMetric.measurements.first(where: { $0.statistic == "VALUE" })?.value {
          result[libraryId] = value
        }
      } catch {
        // Skip errors for individual libraries
        continue
      }
    }

    return result
  }

  private func processTasksMetrics(_ metric: Metric) async -> ([String: Double], [String: Double]) {
    var countByType: [String: Double] = [:]
    var totalTimeByType: [String: Double] = [:]

    guard let typeTag = metric.availableTags?.first(where: { $0.tag == "type" }) else {
      return (countByType, totalTimeByType)
    }

    for taskType in typeTag.values {
      do {
        let taskMetric = try await ManagementService.shared.getMetric(
          metric.name, tags: [MetricTag(key: "type", value: taskType)])

        if let count = taskMetric.measurements.first(where: { $0.statistic == "COUNT" })?.value {
          countByType[taskType] = count
        }
        if let totalTime = taskMetric.measurements.first(where: { $0.statistic == "TOTAL_TIME" })?
          .value
        {
          totalTimeByType[taskType] = totalTime
        }
      } catch {
        // Skip errors for individual task types
        continue
      }
    }

    return (countByType, totalTimeByType)
  }

  private func getLibraryName(_ id: String) -> String {
    return LibraryManager.shared.getLibrary(id: id)?.name ?? id
  }

  private func formatNumber(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
  }

  private func formatFileSize(_ bytes: Double) -> String {
    return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .binary)
  }
}
