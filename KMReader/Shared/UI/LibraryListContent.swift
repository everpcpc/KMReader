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
    let initialSelection = AppConfig.dashboardConfiguration.libraryIds
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
      formContent
        .refreshable {
          await refreshLibraries(forceMetrics: true)
        }
    } else {
      formContent
    }
  }

  private var formContent: some View {
    Form {
      if isLoading && libraries.isEmpty {
        Section {
          HStack {
            Spacer()
            ProgressView(String(localized: "Loading Libraries…"))
            Spacer()
          }
        }
        .listRowBackground(Color.clear)
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
        .listRowBackground(Color.clear)
      } else {
        Section {
          allLibrariesRowView()
          ForEach(libraries, id: \.libraryId) { library in
            libraryRowView(library)
          }
        }
        .listRowBackground(Color.clear)
      }
    }
    .formStyle(.grouped)
    #if os(iOS) || os(macOS)
      .scrollContentBackground(.hidden)
    #endif
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

    Button {
      withAnimation(.easeInOut(duration: 0.2)) {
        selectedLibraryIds = []
        onLibrarySelected?("")
      }
    } label: {
      allLibrariesRowContent(isSelected: isSelected)
    }
    .adaptiveButtonStyle(.plain)
    #if os(iOS) || os(macOS)
      .listRowSeparator(.hidden)
    #endif
    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
    .contextMenu {
      if isAdmin {
        allLibrariesContextMenu()
      }
    }
  }

  @ViewBuilder
  private func allLibrariesRowContent(isSelected: Bool) -> some View {
    let entry = allLibrariesEntry
    let metricsView = allLibrariesMetricsView(entry)
    let fileSizeText = entry?.fileSize.map { formatFileSize($0) } ?? ""

    HStack(spacing: 8) {
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(String(localized: "All Libraries"))
            .font(.headline)
          if !fileSizeText.isEmpty {
            Text(fileSizeText)
              .font(.caption)
              .foregroundColor(.secondary)
              .opacity(fileSizeText.isEmpty ? 0 : 1)
              .animation(.easeInOut(duration: 0.2), value: fileSizeText.isEmpty)
          }
        }
        if isAdmin, let metricsView {
          metricsView
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      Spacer()

      if isSelected {
        Image(systemName: "checkmark.circle.fill")
          .font(.title3)
          .foregroundColor(.accentColor)
          .transition(.scale.combined(with: .opacity))
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.06))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .strokeBorder(
          isSelected ? Color.accentColor.opacity(0.3) : Color.clear,
          lineWidth: 1.5
        )
    )
    .animation(.easeInOut(duration: 0.2), value: isSelected)
    .contentShape(Rectangle())
  }

  @ViewBuilder
  private func libraryRowView(_ library: KomgaLibrary) -> some View {
    let isPerforming = performingLibraryIds.contains(library.libraryId)
    let isSelected = selectedLibraryIds.contains(library.libraryId)

    Button {
      withAnimation(.easeInOut(duration: 0.2)) {
        var currentIds = selectedLibraryIds
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
    } label: {
      librarySummary(library, isPerforming: isPerforming, isSelected: isSelected)
        .contentShape(Rectangle())
    }
    .adaptiveButtonStyle(.plain)
    #if os(iOS) || os(macOS)
      .listRowSeparator(.hidden)
    #endif
    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
    .contextMenu {
      libraryContextMenu(library, isPerforming: isPerforming)
    }
  }

  @ViewBuilder
  private func librarySummary(_ library: KomgaLibrary, isPerforming: Bool, isSelected: Bool)
    -> some View
  {
    let metricsText = metricsView(for: library)
    let fileSizeText = library.fileSize.map { formatFileSize($0) } ?? ""

    HStack(spacing: 8) {
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(library.name)
            .font(.headline)
          if !fileSizeText.isEmpty {
            Text(fileSizeText)
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
        if let metricsText {
          metricsText
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      Spacer()

      if isPerforming {
        ProgressView()
          .progressViewStyle(.circular)
      } else if isSelected {
        Image(systemName: "checkmark.circle.fill")
          .font(.title3)
          .foregroundColor(.accentColor)
          .transition(.scale.combined(with: .opacity))
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.06))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .strokeBorder(
          isSelected ? Color.accentColor.opacity(0.3) : Color.clear,
          lineWidth: 1.5
        )
    )
    .animation(.easeInOut(duration: 0.2), value: isSelected)
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

  @ViewBuilder
  private func libraryContextMenu(_ library: KomgaLibrary, isPerforming: Bool) -> some View {
    if isAdmin {
      Button {
        scanLibrary(library)
      } label: {
        Label(String(localized: "Scan Library Files"), systemImage: "arrow.clockwise")
      }
      .disabled(isPerforming)

      Button {
        scanLibraryDeep(library)
      } label: {
        Label(
          String(localized: "Scan Library Files (Deep)"),
          systemImage: "arrow.triangle.2.circlepath"
        )
      }
      .disabled(isPerforming)

      Button {
        analyzeLibrary(library)
      } label: {
        Label(String(localized: "Analyze"), systemImage: "waveform.path.ecg")
      }
      .disabled(isPerforming)

      Button {
        refreshMetadata(library)
      } label: {
        Label(String(localized: "Refresh Metadata"), systemImage: "arrow.triangle.branch")
      }
      .disabled(isPerforming)

      Button {
        emptyTrash(library)
      } label: {
        Label(String(localized: "Empty Trash"), systemImage: "trash.slash")
      }
      .disabled(isPerforming)

      if showDeleteAction {
        Divider()

        Button(role: .destructive) {
          onDeleteLibrary?(library)
        } label: {
          Label(String(localized: "Delete Library"), systemImage: "trash")
        }
        .disabled(isPerforming)
      }
    }
  }

  // MARK: - Helper Functions

  private func hasMetrics(_ library: KomgaLibrary) -> Bool {
    library.seriesCount != nil || library.booksCount != nil || library.fileSize != nil
      || library.sidecarsCount != nil
  }

  private func metricsView(for library: KomgaLibrary) -> Text? {
    var parts: [Text] = []

    if let seriesCount = library.seriesCount {
      parts.append(
        formatMetricCount(
          key: "library.list.metrics.series",
          defaultValue: "%@ series",
          value: seriesCount
        ))
    }
    if let booksCount = library.booksCount {
      parts.append(
        formatMetricCount(
          key: "library.list.metrics.books",
          defaultValue: "%@ books",
          value: booksCount
        ))
    }
    if let sidecarsCount = library.sidecarsCount {
      parts.append(
        formatMetricCount(
          key: "library.list.metrics.sidecars",
          defaultValue: "%@ sidecars",
          value: sidecarsCount
        ))
    }

    return joinText(parts, separator: " · ")
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
