//
//  SettingsMetricsView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct SettingsMetricsView: View {
  @State private var isLoading = false

  // All libraries metrics
  @State private var allLibrariesMetrics = AllLibrariesMetrics()

  // Library-specific metrics
  @State private var libraryMetrics = LibraryMetrics()

  // Tasks metrics
  @State private var tasks: Metric?
  @State private var tasksCountByType: [String: Double] = [:]
  @State private var tasksTotalTimeByType: [String: Double] = [:]

  // Error messages for each metric section
  @State private var metricErrors: [MetricErrorKey: String] = [:]
  // Individual metric errors for allLibraries section
  @State private var allLibrariesMetricErrors: [String: String] = [:]

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
      } else {
        // All Libraries Section
        Section(header: Text("All Libraries")) {
          if let booksFileSize = allLibrariesMetrics.booksFileSize,
            let value = booksFileSize.measurements.first?.value
          {
            HStack {
              Label("Disk Space", systemImage: "externaldrive")
              Spacer()
              Text(formatFileSize(value))
                .foregroundColor(.secondary)
            }
          }
          if let series = allLibrariesMetrics.series, let value = series.measurements.first?.value {
            HStack {
              Label("Series", systemImage: "book.closed")
              Spacer()
              Text(formatNumber(value))
                .foregroundColor(.secondary)
            }
          }
          if let books = allLibrariesMetrics.books, let value = books.measurements.first?.value {
            HStack {
              Label("Books", systemImage: "book")
              Spacer()
              Text(formatNumber(value))
                .foregroundColor(.secondary)
            }
          }
          if let collections = allLibrariesMetrics.collections,
            let value = collections.measurements.first?.value
          {
            HStack {
              Label("Collections", systemImage: "square.grid.2x2")
              Spacer()
              Text(formatNumber(value))
                .foregroundColor(.secondary)
            }
          }
          if let readlists = allLibrariesMetrics.readlists,
            let value = readlists.measurements.first?.value
          {
            HStack {
              Label("Read Lists", systemImage: "list.bullet")
              Spacer()
              Text(formatNumber(value))
                .foregroundColor(.secondary)
            }
          }
          if let sidecars = allLibrariesMetrics.sidecars,
            let value = sidecars.measurements.first?.value
          {
            HStack {
              Label("Sidecars", systemImage: "doc")
              Spacer()
              Text(formatNumber(value))
                .foregroundColor(.secondary)
            }
          }
          // Show individual metric errors
          ForEach(Array(allLibrariesMetricErrors.keys.sorted()), id: \.self) { metricKey in
            if let error = allLibrariesMetricErrors[metricKey] {
              HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                  .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 2) {
                  Text(getMetricDisplayName(metricKey))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                  Text(error)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
                Spacer()
              }
            }
          }
        }

        // Tasks Section
        if !tasksCountByType.isEmpty || metricErrors[.tasksExecuted] != nil {
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
            if let error = metricErrors[.tasksExecuted] {
              HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                  .foregroundColor(.orange)
                Text(error)
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
            }
          }
        }

        if !tasksTotalTimeByType.isEmpty || metricErrors[.tasksTotalTime] != nil {
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
            if let error = metricErrors[.tasksTotalTime] {
              HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                  .foregroundColor(.orange)
                Text(error)
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
            }
          }
        }

        // Library-specific sections
        if !libraryMetrics.fileSizeByLibrary.isEmpty || metricErrors[.libraryDiskSpace] != nil {
          Section(header: Text("Library Disk Space")) {
            ForEach(Array(libraryMetrics.fileSizeByLibrary.keys.sorted()), id: \.self) {
              libraryId in
              if let size = libraryMetrics.fileSizeByLibrary[libraryId] {
                HStack {
                  Label(getLibraryName(libraryId), systemImage: "externaldrive")
                  Spacer()
                  Text(formatFileSize(size))
                    .foregroundColor(.secondary)
                }
              }
            }
            if let error = metricErrors[.libraryDiskSpace] {
              HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                  .foregroundColor(.orange)
                Text(error)
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
            }
          }
        }

        if !libraryMetrics.booksByLibrary.isEmpty || metricErrors[.libraryBooks] != nil {
          Section(header: Text("Library Books")) {
            ForEach(Array(libraryMetrics.booksByLibrary.keys.sorted()), id: \.self) { libraryId in
              if let count = libraryMetrics.booksByLibrary[libraryId] {
                HStack {
                  Label(getLibraryName(libraryId), systemImage: "book")
                  Spacer()
                  Text(formatNumber(count))
                    .foregroundColor(.secondary)
                }
              }
            }
            if let error = metricErrors[.libraryBooks] {
              HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                  .foregroundColor(.orange)
                Text(error)
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
            }
          }
        }

        if !libraryMetrics.seriesByLibrary.isEmpty || metricErrors[.librarySeries] != nil {
          Section(header: Text("Library Series")) {
            ForEach(Array(libraryMetrics.seriesByLibrary.keys.sorted()), id: \.self) { libraryId in
              if let count = libraryMetrics.seriesByLibrary[libraryId] {
                HStack {
                  Label(getLibraryName(libraryId), systemImage: "book.closed")
                  Spacer()
                  Text(formatNumber(count))
                    .foregroundColor(.secondary)
                }
              }
            }
            if let error = metricErrors[.librarySeries] {
              HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                  .foregroundColor(.orange)
                Text(error)
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
            }
          }
        }

        if !libraryMetrics.sidecarsByLibrary.isEmpty || metricErrors[.librarySidecars] != nil {
          Section(header: Text("Library Sidecars")) {
            ForEach(Array(libraryMetrics.sidecarsByLibrary.keys.sorted()), id: \.self) {
              libraryId in
              if let count = libraryMetrics.sidecarsByLibrary[libraryId] {
                HStack {
                  Label(getLibraryName(libraryId), systemImage: "doc")
                  Spacer()
                  Text(formatNumber(count))
                    .foregroundColor(.secondary)
                }
              }
            }
            if let error = metricErrors[.librarySidecars] {
              HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                  .foregroundColor(.orange)
                Text(error)
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
            }
          }
        }
      }
    }
    .inlineNavigationBarTitle("Metrics")
    .task {
      await loadMetrics()
    }
    .refreshable {
      await loadMetrics()
    }
  }

  private func loadMetrics() async {
    isLoading = true
    metricErrors.removeAll()
    allLibrariesMetricErrors.removeAll()

    // Ensure libraries are loaded
    await LibraryManager.shared.loadLibraries()

    // Load all libraries metrics - handle each metric independently
    await withTaskGroup(of: Void.self) { group in
      group.addTask {
        await self.loadMetric(
          metricName: MetricName.booksFileSize.rawValue,
          key: "booksFileSize",
          setter: { self.allLibrariesMetrics.booksFileSize = $0 },
          errorKey: .allLibraries,
          metricKey: "booksFileSize"
        )
      }
      group.addTask {
        await self.loadMetric(
          metricName: MetricName.series.rawValue,
          key: "series",
          setter: { self.allLibrariesMetrics.series = $0 },
          errorKey: .allLibraries,
          metricKey: "series"
        )
      }
      group.addTask {
        await self.loadMetric(
          metricName: MetricName.books.rawValue,
          key: "books",
          setter: { self.allLibrariesMetrics.books = $0 },
          errorKey: .allLibraries,
          metricKey: "books"
        )
      }
      group.addTask {
        await self.loadMetric(
          metricName: MetricName.collections.rawValue,
          key: "collections",
          setter: { self.allLibrariesMetrics.collections = $0 },
          errorKey: .allLibraries,
          metricKey: "collections"
        )
      }
      group.addTask {
        await self.loadMetric(
          metricName: MetricName.readlists.rawValue,
          key: "readlists",
          setter: { self.allLibrariesMetrics.readlists = $0 },
          errorKey: .allLibraries,
          metricKey: "readlists"
        )
      }
      group.addTask {
        await self.loadMetric(
          metricName: MetricName.sidecars.rawValue,
          key: "sidecars",
          setter: { self.allLibrariesMetrics.sidecars = $0 },
          errorKey: .allLibraries,
          metricKey: "sidecars"
        )
      }
      group.addTask {
        await self.loadMetric(
          metricName: MetricName.tasksExecution.rawValue,
          key: "tasks",
          setter: { self.tasks = $0 },
          errorKey: nil
        )
      }
    }

    // Process library-specific metrics
    if let booksFileSize = allLibrariesMetrics.booksFileSize {
      libraryMetrics.fileSizeByLibrary = await processLibraryMetrics(
        booksFileSize, errorKey: .libraryDiskSpace)
    }
    if let books = allLibrariesMetrics.books {
      libraryMetrics.booksByLibrary = await processLibraryMetrics(books, errorKey: .libraryBooks)
    }
    if let series = allLibrariesMetrics.series {
      libraryMetrics.seriesByLibrary = await processLibraryMetrics(
        series, errorKey: .librarySeries)
    }
    if let sidecars = allLibrariesMetrics.sidecars {
      libraryMetrics.sidecarsByLibrary = await processLibraryMetrics(
        sidecars, errorKey: .librarySidecars)
    }

    // Process tasks metrics
    if let tasks = tasks {
      let (countByType, totalTimeByType, errors) = await processTasksMetrics(tasks)
      tasksCountByType = countByType
      tasksTotalTimeByType = totalTimeByType
      if let tasksExecutedError = errors[.tasksExecuted] {
        metricErrors[.tasksExecuted] = tasksExecutedError
      }
      if let tasksTotalTimeError = errors[.tasksTotalTime] {
        metricErrors[.tasksTotalTime] = tasksTotalTimeError
      }
    }

    isLoading = false
  }

  private func loadMetric(
    metricName: String,
    key: String,
    setter: @escaping (Metric?) -> Void,
    errorKey: MetricErrorKey?,
    metricKey: String? = nil
  ) async {
    do {
      let metric = try await ManagementService.shared.getMetric(metricName)
      setter(metric)
    } catch {
      setter(nil)
      let errorMessage = getErrorMessage(error)

      // Store individual metric error for allLibraries section
      if errorKey == .allLibraries, let metricKey = metricKey {
        allLibrariesMetricErrors[metricKey] = errorMessage
      }

      // Keep the old behavior for other error keys
      if let errorKey = errorKey, errorKey != .allLibraries {
        if metricErrors[errorKey] == nil {
          metricErrors[errorKey] = errorMessage
        } else {
          // Append to existing error message
          metricErrors[errorKey] = "\(metricErrors[errorKey] ?? ""); \(errorMessage)"
        }
      }
    }
  }

  private func getErrorMessage(_ error: Error) -> String {
    if let apiError = error as? APIError {
      return apiError.description
    }
    return error.localizedDescription
  }

  private func processLibraryMetrics(_ metric: Metric, errorKey: MetricErrorKey) async -> [String:
    Double]
  {
    var result: [String: Double] = [:]
    var errorCount = 0

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
        // Track errors for individual libraries
        errorCount += 1
        continue
      }
    }

    if errorCount > 0 {
      metricErrors[errorKey] =
        "Failed to load metrics for \(errorCount) librar\(errorCount == 1 ? "y" : "ies")"
    }

    return result
  }

  private func processTasksMetrics(_ metric: Metric) async -> (
    [String: Double], [String: Double], [MetricErrorKey: String]
  ) {
    var countByType: [String: Double] = [:]
    var totalTimeByType: [String: Double] = [:]
    var errors: [MetricErrorKey: String] = [:]
    var countErrorCount = 0
    var timeErrorCount = 0

    guard let typeTag = metric.availableTags?.first(where: { $0.tag == "type" }) else {
      return (countByType, totalTimeByType, errors)
    }

    for taskType in typeTag.values {
      do {
        let taskMetric = try await ManagementService.shared.getMetric(
          metric.name, tags: [MetricTag(key: "type", value: taskType)])

        if let count = taskMetric.measurements.first(where: { $0.statistic == "COUNT" })?.value {
          countByType[taskType] = count
        } else {
          countErrorCount += 1
        }
        if let totalTime = taskMetric.measurements.first(where: { $0.statistic == "TOTAL_TIME" })?
          .value
        {
          totalTimeByType[taskType] = totalTime
        } else {
          timeErrorCount += 1
        }
      } catch {
        // Track errors for individual task types
        countErrorCount += 1
        timeErrorCount += 1
        continue
      }
    }

    if countErrorCount > 0 {
      errors[.tasksExecuted] =
        "Failed to load count metrics for \(countErrorCount) task type\(countErrorCount == 1 ? "" : "s")"
    }
    if timeErrorCount > 0 {
      errors[.tasksTotalTime] =
        "Failed to load time metrics for \(timeErrorCount) task type\(timeErrorCount == 1 ? "" : "s")"
    }

    return (countByType, totalTimeByType, errors)
  }

  private func getLibraryName(_ id: String) -> String {
    return LibraryManager.shared.getLibrary(id: id)?.name ?? id
  }

  private func getMetricDisplayName(_ key: String) -> String {
    switch key {
    case "booksFileSize":
      return "Disk Space"
    case "series":
      return "Series"
    case "books":
      return "Books"
    case "collections":
      return "Collections"
    case "readlists":
      return "Read Lists"
    case "sidecars":
      return "Sidecars"
    default:
      return key
    }
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

// MARK: - Metrics Data Structures

struct AllLibrariesMetrics {
  var booksFileSize: Metric?
  var series: Metric?
  var books: Metric?
  var collections: Metric?
  var readlists: Metric?
  var sidecars: Metric?
}

struct LibraryMetrics {
  var fileSizeByLibrary: [String: Double] = [:]
  var booksByLibrary: [String: Double] = [:]
  var seriesByLibrary: [String: Double] = [:]
  var sidecarsByLibrary: [String: Double] = [:]
}

enum MetricErrorKey: Hashable {
  case allLibraries
  case tasksExecuted
  case tasksTotalTime
  case libraryDiskSpace
  case libraryBooks
  case librarySeries
  case librarySidecars
}
