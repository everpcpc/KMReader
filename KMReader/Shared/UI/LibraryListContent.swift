//
//  LibraryListContent.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import SwiftData
import SwiftUI

struct LibraryListContent: View {
  @AppStorage("currentInstanceId") private var currentInstanceId: String = ""
  @AppStorage("dashboard") private var dashboard: DashboardConfiguration = DashboardConfiguration()
  @AppStorage("isAdmin") private var isAdmin: Bool = false
  @AppStorage("isOffline") private var isOffline: Bool = false
  @Query(sort: [SortDescriptor(\KomgaLibrary.name, order: .forward)]) private var allLibraries:
    [KomgaLibrary]
  @State private var performingLibraryIds: Set<String> = []
  @State private var isPerformingGlobalAction = false
  @State private var isLoading = false
  @State private var isLoadingMetrics = false
  @State private var selectedLibraryIds: [String]

  let showDeleteAction: Bool
  let loadMetrics: Bool
  let alwaysRefreshMetrics: Bool
  let forceMetricsOnAppear: Bool
  let enablePullToRefresh: Bool
  let onLibrarySelected: ((String?) -> Void)?
  let onDeleteLibrary: ((KomgaLibrary) -> Void)?

  private let libraryService = LibraryService.shared
  private let metricsLoader = LibraryMetricsLoader.shared

  init(
    showDeleteAction: Bool = false,
    loadMetrics: Bool = true,
    alwaysRefreshMetrics: Bool = false,
    forceMetricsOnAppear: Bool = true,
    enablePullToRefresh: Bool = true,
    onLibrarySelected: ((String?) -> Void)? = nil,
    onDeleteLibrary: ((KomgaLibrary) -> Void)? = nil
  ) {
    let initialSelection = AppConfig.dashboard.libraryIds
    self.showDeleteAction = showDeleteAction
    self.loadMetrics = loadMetrics
    self.alwaysRefreshMetrics = alwaysRefreshMetrics
    self.forceMetricsOnAppear = forceMetricsOnAppear
    self.enablePullToRefresh = enablePullToRefresh
    self.onLibrarySelected = onLibrarySelected
    self.onDeleteLibrary = onDeleteLibrary
    _selectedLibraryIds = State(initialValue: initialSelection)
  }

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
    if enablePullToRefresh {
      listContent
        .refreshable {
          await refreshLibraries(forceMetrics: true)
        }
    } else {
      listContent
    }
  }

  private var listContent: some View {
    Form {
      if isLoading && libraries.isEmpty {
        Section {
          HStack {
            Spacer()
            ProgressView(String(localized: "Loading Libraries…"))
            Spacer()
          }
        }
      } else if libraries.isEmpty {
        Section {
          VStack(spacing: 12) {
            Image(systemName: "books.vertical")
              .font(.largeTitle)
              .foregroundColor(.secondary)
            Text(String(localized: "No libraries found"))
              .font(.headline)
            Text(String(localized: "Add a library from Komga's web interface to manage it here."))
              .font(.caption)
              .foregroundColor(.secondary)
              .multilineTextAlignment(.center)
            Button(String(localized: "Retry")) {
              Task {
                await refreshLibraries()
              }
            }
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
        }
      } else {
        Section {
          allLibrariesRowView()
          ForEach(libraries, id: \.libraryId) { library in
            LibraryRowView(
              library: library,
              isPerforming: performingLibraryIds.contains(library.libraryId),
              isSelected: selectedLibraryIds.contains(library.libraryId),
              isAdmin: isAdmin,
              showDeleteAction: showDeleteAction,
              onSelect: {
                withAnimation(.easeInOut(duration: 0.2)) {
                  var currentIds = selectedLibraryIds
                  let isSelected = currentIds.contains(library.libraryId)
                  if isSelected {
                    currentIds.removeAll { $0 == library.libraryId }
                  } else {
                    if !currentIds.contains(library.libraryId) {
                      currentIds.append(library.libraryId)
                    }
                  }
                  var seen = Set<String>()
                  selectedLibraryIds = currentIds.filter { seen.insert($0).inserted }
                  onLibrarySelected?(isSelected ? nil : library.libraryId)
                }
              },
              onAction: { action in
                switch action {
                case .scan: scanLibrary(library)
                case .scanDeep: scanLibraryDeep(library)
                case .analyze: analyzeLibrary(library)
                case .refreshMetadata: refreshMetadata(library)
                case .emptyTrash: emptyTrash(library)
                }
              },
              onDelete: {
                onDeleteLibrary?(library)
              }
            )
          }
        }
      }
    }
    .formStyle(.grouped)
    .task {
      await refreshLibraries(forceMetrics: forceMetricsOnAppear)
    }
    .onChange(of: libraries) { _, _ in
      Task {
        await triggerMetricsUpdate(force: false)
      }
    }
    .onDisappear {
      if dashboard.libraryIds != selectedLibraryIds {
        dashboard.libraryIds = selectedLibraryIds
      }
    }
  }

  func refreshLibraries() async {
    await refreshLibraries(forceMetrics: true)
  }

  func refreshLibraries(forceMetrics: Bool) async {
    isLoading = true
    await LibraryManager.shared.refreshLibraries()
    await triggerMetricsUpdate(force: forceMetrics)
    isLoading = false
  }

  private func triggerMetricsUpdate(force: Bool) async {
    guard loadMetrics, isAdmin, !currentInstanceId.isEmpty else { return }

    let shouldLoad = await MainActor.run {
      force || alwaysRefreshMetrics || needsMetricsReload()
    }

    guard shouldLoad else { return }

    let alreadyLoading = await MainActor.run { isLoadingMetrics }
    if alreadyLoading {
      return
    }

    await MainActor.run { isLoadingMetrics = true }

    let libraryIds = await MainActor.run { libraries.map(\.libraryId) }
    let hasAllEntry = await MainActor.run { allLibrariesEntry != nil }

    let metricsByLibrary = await metricsLoader.refreshMetrics(
      instanceId: currentInstanceId,
      libraryIds: libraryIds,
      ensureAllLibrariesEntry: hasAllEntry
    )

    await MainActor.run {
      for library in libraries {
        guard let metrics = metricsByLibrary[library.libraryId] else { continue }
        library.fileSize = metrics.fileSize
        library.booksCount = metrics.booksCount
        library.seriesCount = metrics.seriesCount
        library.sidecarsCount = metrics.sidecarsCount
      }
    }

    await MainActor.run { isLoadingMetrics = false }
  }

  private func needsMetricsReload() -> Bool {
    guard !libraries.isEmpty else { return false }

    if allLibrariesEntry == nil || !hasAllLibrariesMetrics(allLibrariesEntry) {
      return true
    }

    return libraries.contains { !hasMetrics($0) }
  }

  @ViewBuilder
  private func allLibrariesRowView() -> some View {
    let isSelected = selectedLibraryIds.isEmpty
    let entry = allLibrariesEntry
    let metricsView = allLibrariesMetricsView(entry)
    let fileSizeText = entry?.fileSize.map { formatFileSize($0) } ?? ""

    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(String(localized: "All Libraries"))
            .font(.headline)
          if !fileSizeText.isEmpty {
            Text(fileSizeText)
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
        if isAdmin, let metricsView {
          metricsView
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      Spacer()

      Toggle(
        "",
        isOn: Binding(
          get: { isSelected },
          set: { newValue in
            if newValue {
              withAnimation(.easeInOut(duration: 0.2)) {
                selectedLibraryIds = []
                onLibrarySelected?("")
              }
            }
          }
        )
      )
      .labelsHidden()
    }
    .contentShape(Rectangle())
    .contextMenu {
      if isAdmin && !isOffline {
        allLibrariesContextMenu()
      }
    }
  }

  @ViewBuilder
  private func allLibrariesContextMenu() -> some View {
    Button {
      performGlobalAction {
        try await scanAllLibraries(deep: false)
      }
    } label: {
      Label(String(localized: "Scan All Libraries"), systemImage: "arrow.clockwise")
    }
    .disabled(isPerformingGlobalAction)

    Button {
      performGlobalAction {
        try await scanAllLibraries(deep: true)
      }
    } label: {
      Label(
        String(localized: "Scan All Libraries (Deep)"),
        systemImage: "arrow.triangle.2.circlepath"
      )
    }
    .disabled(isPerformingGlobalAction)

    Button {
      performGlobalAction {
        try await emptyTrashAllLibraries()
      }
    } label: {
      Label(String(localized: "Empty Trash for All Libraries"), systemImage: "trash.slash")
    }
    .disabled(isPerformingGlobalAction)
  }

  // MARK: - Helper Functions

  private func hasMetrics(_ library: KomgaLibrary) -> Bool {
    library.seriesCount != nil || library.booksCount != nil || library.fileSize != nil
      || library.sidecarsCount != nil
  }

  private func formatNumber(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
  }

  private func formatMetricCount(key: String, defaultValue: String, value: Double) -> Text {
    let format = Bundle.main.localizedString(forKey: key, value: defaultValue, table: nil)
    return Text(String.localizedStringWithFormat(format, formatNumber(value)))
  }

  private func joinText(_ parts: [Text], separator: String) -> Text? {
    guard let first = parts.first else { return nil }
    return parts.dropFirst().reduce(first) { result, part in
      result + Text(separator) + part
    }
  }

  private func formatFileSize(_ bytes: Double) -> String {
    return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .binary)
  }

  private func hasAllLibrariesMetrics(_ entry: KomgaLibrary?) -> Bool {
    guard let entry else { return false }
    return entry.seriesCount != nil || entry.booksCount != nil || entry.fileSize != nil
      || entry.sidecarsCount != nil || entry.collectionsCount != nil
      || entry.readlistsCount != nil
  }

  private func allLibrariesMetricsView(_ entry: KomgaLibrary?) -> Text? {
    guard let entry else { return nil }
    var lines: [Text] = []

    // First line: series, books, sidecars
    var firstLineParts: [Text] = []
    if let seriesCount = entry.seriesCount {
      firstLineParts.append(
        formatMetricCount(
          key: "library.list.metrics.series",
          defaultValue: "%@ series",
          value: seriesCount
        ))
    }
    if let booksCount = entry.booksCount {
      firstLineParts.append(
        formatMetricCount(
          key: "library.list.metrics.books",
          defaultValue: "%@ books",
          value: booksCount
        ))
    }
    if let sidecarsCount = entry.sidecarsCount {
      firstLineParts.append(
        formatMetricCount(
          key: "library.list.metrics.sidecars",
          defaultValue: "%@ sidecars",
          value: sidecarsCount
        ))
    }
    if let firstLine = joinText(firstLineParts, separator: " · ") {
      lines.append(firstLine)
    }

    // Second line: collections, readlists
    var secondLineParts: [Text] = []
    if let collectionsCount = entry.collectionsCount {
      secondLineParts.append(
        formatMetricCount(
          key: "library.list.metrics.collections",
          defaultValue: "%@ collections",
          value: collectionsCount
        ))
    }
    if let readlistsCount = entry.readlistsCount {
      secondLineParts.append(
        formatMetricCount(
          key: "library.list.metrics.readlists",
          defaultValue: "%@ read lists",
          value: readlistsCount
        ))
    }
    if let secondLine = joinText(secondLineParts, separator: " · ") {
      lines.append(secondLine)
    }

    return joinText(lines, separator: "\n")
  }

  // MARK: - Library Actions

  private func scanLibrary(_ library: KomgaLibrary) {
    guard !performingLibraryIds.contains(library.libraryId) else { return }
    performingLibraryIds.insert(library.libraryId)
    Task {
      do {
        try await libraryService.scanLibrary(id: library.libraryId)
        await MainActor.run {
          ErrorManager.shared.notify(message: String(localized: "library.list.notify.scanStarted"))
        }
      } catch {
        _ = await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
      _ = await MainActor.run {
        performingLibraryIds.remove(library.libraryId)
      }
    }
  }

  private func scanLibraryDeep(_ library: KomgaLibrary) {
    guard !performingLibraryIds.contains(library.libraryId) else { return }
    performingLibraryIds.insert(library.libraryId)
    Task {
      do {
        try await libraryService.scanLibrary(id: library.libraryId, deep: true)
        await MainActor.run {
          ErrorManager.shared.notify(message: String(localized: "library.list.notify.scanStarted"))
        }
      } catch {
        _ = await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
      _ = await MainActor.run {
        performingLibraryIds.remove(library.libraryId)
      }
    }
  }

  private func analyzeLibrary(_ library: KomgaLibrary) {
    guard !performingLibraryIds.contains(library.libraryId) else { return }
    performingLibraryIds.insert(library.libraryId)
    Task {
      do {
        try await libraryService.analyzeLibrary(id: library.libraryId)
        await MainActor.run {
          ErrorManager.shared.notify(
            message: String(localized: "library.list.notify.analysisStarted")
          )
        }
      } catch {
        _ = await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
      _ = await MainActor.run {
        performingLibraryIds.remove(library.libraryId)
      }
    }
  }

  private func refreshMetadata(_ library: KomgaLibrary) {
    guard !performingLibraryIds.contains(library.libraryId) else { return }
    performingLibraryIds.insert(library.libraryId)
    Task {
      do {
        try await libraryService.refreshMetadata(id: library.libraryId)
        await MainActor.run {
          ErrorManager.shared.notify(
            message: String(localized: "library.list.notify.metadataRefreshStarted")
          )
        }
      } catch {
        _ = await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
      _ = await MainActor.run {
        performingLibraryIds.remove(library.libraryId)
      }
    }
  }

  private func emptyTrash(_ library: KomgaLibrary) {
    guard !performingLibraryIds.contains(library.libraryId) else { return }
    performingLibraryIds.insert(library.libraryId)
    Task {
      do {
        try await libraryService.emptyTrash(id: library.libraryId)
        await MainActor.run {
          ErrorManager.shared.notify(message: String(localized: "library.list.notify.trashEmptied"))
        }
      } catch {
        _ = await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
      _ = await MainActor.run {
        performingLibraryIds.remove(library.libraryId)
      }
    }
  }

  private func scanAllLibraries(deep: Bool) async throws {
    for library in libraries {
      try await libraryService.scanLibrary(id: library.libraryId, deep: deep)
    }
  }

  private func emptyTrashAllLibraries() async throws {
    for library in libraries {
      try await libraryService.emptyTrash(id: library.libraryId)
    }
  }

  private func performGlobalAction(_ action: @escaping () async throws -> Void) {
    guard !isPerformingGlobalAction else { return }
    isPerformingGlobalAction = true
    Task {
      do {
        try await action()
      } catch {
        _ = await MainActor.run {
          ErrorManager.shared.alert(error: error)
        }
      }
      _ = await MainActor.run {
        isPerformingGlobalAction = false
      }
    }
  }
}
